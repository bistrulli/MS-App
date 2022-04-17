from system_int import system_interface
import time
import numpy as np
import subprocess
from cgroupspy import trees
from pymemcache.client.base import Client
import os
import psutil
import requests as req
import traceback
import matplotlib.pyplot as plt
import socket
import scipy.stats as st
from scipy.io import savemat


try:
    javaCmd = os.environ['JAVA_HOME'] + "/bin/java"
except:
    raise ValueError("Need to setup JAVA_HOME env variable")


class jvm_sys(system_interface):
    
    sysRootPath = None
    sys = None
    client = None
    cgroups = None
    period = 100000
    keys = ["think", "e1_bl", "e1_ex", "t1_hw"]
    isCpu = None
    tier_socket = None
    
    def __init__(self, sysRootPath, isCpu=False):
        self.sysRootPath = sysRootPath
        self.isCpu = isCpu
        self.tier_socket = {}
    
    def startClient(self, pop):
        r = Client("localhost:11211")
        r.set("stop", "0")
        r.set("started", "0")
        r.close()
        
        subprocess.Popen([javaCmd, "-Xmx15G", "-Xms15G",
                         "-Djava.compiler=NONE", "-jar",
                         '%sMS-Client/target/MS-Client-0.0.1-jar-with-dependencies.jar' % (self.sysRootPath),
                         '--initPop', '%d' % (pop), '--jedisHost', 'localhost', '--tier1Host', 'localhost',
                         '--queues', '[\"think\", \"e1_bl\", \"e1_ex\", \"t1_hw\"]'])
        
        self.waitClient()
        
        self.client = self.findProcessIdByName("MS-Client-0.0.1")[0]
    
    def resetSys(self):
        self.tier_socket = {}
        self.sys = None
        self.client = None
        self.cgroups = None
    
    def stopClient(self):
        if(self.client != None):
            # r = Client("localhost:11211")
            # r.set("stop", "1")
            # r.set("started", "0")
            # r.close()
            
            try:
                self.client.wait(timeout=10)
            except psutil.TimeoutExpired as e:
                print("terminate client forcibly")
                self.client.terminate()
                self.client.kill()
            finally:
                self.client = None
    
    def startSys(self):
        
        # if(self.isCpu):
        #     self.initCgroups()
        
        cpuEmu = 0 if(self.isCpu) else 1
        
        self.sys = []
        subprocess.Popen(["memcached", "-c", "2048", "-t", "20"])
        self.waitMemCached()
        self.sys.append(self.findProcessIdByName("memcached")[0])
        
        if(not self.isCpu):
            subprocess.Popen([javaCmd,
                            "-Xmx15G", "-Xms15G",
                             # "-XX:ParallelGCThreads=1",
                             # "-XX:+UnlockExperimentalVMOptions","-XX:+UseEpsilonGC",
                             "-Djava.compiler=NONE", "-jar",
                             '%sMS-Tier1/target/MS-Tier1-0.0.1-jar-with-dependencies.jar' % (self.sysRootPath),
                             '--cpuEmu', "%d" % (cpuEmu), '--jedisHost', 'localhost',
                             "--tier2Host", "localhost"])
            
            self.waitTier1()
            self.sys.append(self.findProcessIdByName("MS-Tier1-0.0.1")[0])
        else:
            # subprocess.Popen(["cgexec", "-g", "cpu:t1", "--sticky", 
            #                   javaCmd,
            #                  "-Xmx15G", "-Xms15G",
            #                  "-Djava.compiler=NONE", "-jar", "-Xint",
            #                  '%sMS-Tier1/target/MS-Tier1-0.0.1-jar-with-dependencies.jar' % (self.sysRootPath),
            #                  '--cpuEmu', "%d" % (cpuEmu), '--jedisHost', 'localhost',
            #                  "--tier2Host", "localhost"])
            
            subprocess.Popen([javaCmd,
                             "-Xmx15G", "-Xms15G",
                             "-Djava.compiler=NONE", "-jar", "-Xint",
                             '%sMS-Tier1/target/MS-Tier1-0.0.1-jar-with-dependencies.jar' % (self.sysRootPath),
                             '--cpuEmu', "%d" % (cpuEmu), '--jedisHost', 'localhost',
                             "--tier2Host", "localhost"])
            self.waitTier1()
            self.sys.append(self.findProcessIdByName("MS-Tier1-0.0.1")[0])
    
    def findProcessIdByName(self, processName):
        
        '''
        Get a list of all the PIDs of a all the running process whose name contains
        the given string processName
        '''
        listOfProcessObjects = []
        # Iterate over the all the running process
        for proc in psutil.process_iter():
           if(proc.status() == "zombie"):
               continue
           try:
               pinfo = proc.as_dict(attrs=['pid', 'name', 'create_time'])
               # Check if process name contains the given name string.
               if processName.lower() in pinfo['name'].lower() or processName.lower() in " ".join(proc.cmdline()).lower():
                   listOfProcessObjects.append(proc)
           except (psutil.NoSuchProcess, psutil.AccessDenied , psutil.ZombieProcess):
               pass
        if(len(listOfProcessObjects) != 1):
            print(len(listOfProcessObjects))
            raise ValueError("process %s not found!" % processName)
        return listOfProcessObjects;
    
    def stopSystem(self):
        if(self.sys is not None):
            for i in range(len(self.sys), 0, -1):
                proc = self.sys[i - 1]
                print("killing %s" % (proc.name() + " " + "".join(proc.cmdline())))
                proc.terminate()
                try:
                    proc.wait(timeout=2)
                except psutil.TimeoutExpired as e:
                    proc.kill()
                
        self.resetSys()
    
    def waitTier1(self):
        connected = False
        limit = 1000
        atpt = 0
        base_client = Client(("localhost", 11211))
        base_client.set("test_ex", "1")
        while(atpt < limit and not connected):
            try:
                r = req.get('http://localhost:3000?entry=e1&snd=test')
                connected = True
                break
            except:
                time.sleep(0.2)
            finally:
                atpt += 1
        
        base_client.close()
        if(connected):
            print("connected to tier1")
        else:
            raise ValueError("error while connceting to tier1")
    
    def waitClient(self):
        connected = False
        limit = 10000
        atpt = 0
        base_client = Client(("localhost", 11211))
        while(atpt < limit and (base_client.get("started") == None or base_client.get("started").decode('UTF-8') == "0")):
           time.sleep(0.2)
           atpt += 1
        
    def waitMemCached(self):
        connected = False
        base_client = Client(("localhost", 11211))
        for i in range(1000):
            try:
                base_client.get('some_key')
                connected = True
                base_client.close()
                break
            except ConnectionRefusedError:
                time.sleep(0.2)
        base_client.close()
        
        if(connected):
            print("connected to memcached")
        else:
            raise ValueError("Impossible to connected to memcached")
        
        time.sleep(0.5)
    
    def initCgroups(self): 
        self.cgroups = {"tier1":{"name":"t1", "cg":None}, "tier2":{"name":"t2", "cg":None}}
        
        p = subprocess.Popen(["cgget", "-g", "cpu:t1"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        out, err = p.communicate()
        if(str(err).find("Cgroup does not exist") != -1):
            subprocess.check_output(["sudo", "cgcreate", "-g", "cpu:t1", "-a", "emilio:emilio", "-t", "emilio:emilio"])
        
        p = subprocess.Popen(["cgget", "-g", "cpu:t2"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        out, err = p.communicate()
        if(str(err).find("Cgroup does not exist") != -1):
            subprocess.check_output(["sudo", "cgcreate", "-g", "cpu:t2", "-a", "emilio:emilio", "-t", "emilio:emilio"])
    
    def setU(self, RL, cnt_name):
        
        if(self.cgroups[cnt_name]["cg"] == None):
            print("set cgrop for %s" % (self.cgroups[cnt_name]["name"]))
            self.cgroups[cnt_name]["cg"] = trees.Tree().get_node_by_path('/cpu/%s' % (self.cgroups[cnt_name]["name"]))
        
        quota = int(np.round(RL * self.period))
    
        self.cgroups[cnt_name]["cg"].controller.cfs_period_us = self.period
        self.cgroups[cnt_name]["cg"].controller.cfs_quota_us = quota
    
    # def getstate(self, monitor):
    #     N = 2
    #     str_state = [monitor.get(self.keys[i]) for i in range(len(self.keys))]
    #     try:
    #         estate = [float(str_state[i]) for i in range(len(str_state))]
    #         astate = [float(str_state[0].decode('UTF-8'))]
    #
    #         gidx = 1;
    #         for i in range(0, N):
    #             astate.append(float(str_state[gidx].decode('UTF-8')) + float(str_state[gidx + 1].decode('UTF-8')))
    #             if(float(str_state[gidx]) < 0 or float(str_state[gidx + 1]) < 0):
    #                 raise ValueError("Error! state < 0")
    #             gidx += 3
    #     except:
    #         for i in range(len(self.keys)):
    #             print(str_state[i], self.keys[i])
    #
    #     return [astate, estate]
    
    def getstate(self, monitor=None):
        state = self.getStateTcp()
        return [[state["think"], state["e1_bl"] + state["e1_ex"]],
                [state["think"], state["e1_bl"], state["e1_ex"]]]
        
    def getStateNetStat(self):
        cmd = "netstat -anp | grep :80 | grep ESTABLISHED | wc -l"
        ps = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        start = time.time()
        output = ps.communicate()[0]
        print(output, time.time() - start)
    
    def getStateTcp(self):
        tiers = [3333, 13000]
        sys_state = {}
        
        for tier in tiers: 
            msgFromServer = self.getTierTcpState(tier)
                
            states = msgFromServer.split("$")
            for state in states:
                if(state != None and state != ''):
                    key, val = state.split(":")
                    sys_state[key] = int(val)
        
        return sys_state
    
    def getTierTcpState(self, tier):
        if("%d" % (tier) not in self.tier_socket):
            # Create a TCP socket at client side
            self.tier_socket["%d" % (tier)] = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.tier_socket["%d" % (tier)].setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
            self.tier_socket["%d" % (tier)].connect(('localhost', tier))
            msg = self.tier_socket["%d" % (tier)].recv(1024)
            if(msg.decode("UTF-8").rstrip("\n") != "connected"):
                raise ValueError("Error while connecting to tier msg=%s" % (msg.decode("UTF-8").rstrip("\n")))
        
        self.tier_socket["%d" % (tier)].sendall("getState\n".encode("UTF-8"))
        return self.tier_socket["%d" % (tier)].recv(1024).decode("UTF-8").rstrip("\n")
    
    def testTcpState(self, tier):
        msg = self.getTierTcpState(tier)
        print(msg)
        
    def batchMeansRT(self,rtLogName,N=10,K=10):
        RT=np.loadtxt(rtLogName,ndmin=2)
        B=None
        print(RT.shape[0])
        if(RT.shape[0]<N*K):
            return False
        else:
            nB=int(np.floor(RT.shape[0]//K))
            B=np.array([[ RT[int(k+b*K),0] for k in range(K)] for b in range(nB)])
            
            Bm=np.mean(B,axis=1)
            
            CI=st.t.interval(alpha=0.95, df=Bm.shape[0]-1,
              loc=np.mean(Bm),
              scale=st.sem(Bm))
            
            print("####%s####"%(rtLogName))
            print(CI[0]/10**9,CI[1]/10**9)
            print(np.mean(Bm)/10**9,(CI[1]-np.mean(Bm))*100/np.mean(Bm),(CI[1]-np.mean(Bm))/10**9)
            
            return [np.mean(Bm),CI]
            
            
                    
    
    def testSystem(self):
        self.startSys()
        r = Client("localhost:11211")
        try:
            for k in self.keys:
                if(k == "think" or k == "t1_hw" or k == "t2_hw"):
                    continue
                if(r.get(k) is None):
                    raise ValueError("test not passed, key %s should be 0 instead is None" % (k))
                if(r.get(k).decode('UTF-8') != "0"):
                    raise ValueError("test not passed, key %s should be 0 instead is %s" % (k, r.get(k).decode('UTF-8')))
            
            http_req = req.get('http://localhost:3001?entry=e2&snd=test&id=%d' % (np.random.randint(low=0, high=10000000)))
            
            for k in self.keys:
                if(k == "think" or k == "t1_hw" or k == "t2_hw"):
                    continue
                if(r.get(k) is None):
                    raise ValueError("test not passed, key %s should be 0 instead is None" % (k))
                if(r.get(k).decode('UTF-8') != "0"):
                    raise ValueError("test not passed, key %s should be 0 instead is %s" % (k, r.get(k).decode('UTF-8')))
                
            http_req = req.get('http://localhost:3000?entry=e1&snd=test&id=%d' % (np.random.randint(low=0, high=10000000)))
            
            for k in self.keys:
                if(k == "think" or k == "t1_hw" or k == "t2_hw"):
                    continue
                if(r.get(k) is None):
                    raise ValueError("test not passed, key %s should be 0 instead is None" % (k))
                if(r.get(k).decode('UTF-8') != "0"):
                    raise ValueError("test not passed, key %s should be 0 instead is %s" % (k, r.get(k).decode('UTF-8')))
        except Exception as ex:
            traceback.print_exception(type(ex), ex, ex.__traceback__)
            for k in self.keys:
                if(k == "think" or k == "t1_hw" or k == "t2_hw"):
                    continue
                print(k, r.get(k))
        finally:
            self.stopSystem()
            r.close()
       
            
if __name__ == "__main__":
    try:
        isCpu = True
        g = None
        jvm_sys = jvm_sys("../", isCpu)
        
        W=[4,10,20,30,40,50]
        rtExp=np.zeros([len(W),2])
        rtCI=np.zeros([len(W),2])
        
        for w in range(len(W)) :
        
            isConverged=False
            
            jvm_sys.startSys()
            jvm_sys.startClient(W[w])
            
            g = Client("localhost:11211")
            
            #g.set("t1_hw", "%f" %(5))
            
            X = []
            Client_rt=None
            T1_rt=None
            while(not isConverged):
                
                isConverged=True
                
                Client_rt=jvm_sys.batchMeansRT("Client_rtlog.txt",N=30,K=30);
                if(Client_rt):
                    e=(Client_rt[1][1]-Client_rt[0])/Client_rt[0]
                    if(e>0.01):
                        isConverged=isConverged and False
                else:
                    isConverged=isConverged and False
                        
                T1_rt=jvm_sys.batchMeansRT("t1_rtlog.txt",N=30,K=30);
                if(T1_rt):
                    e=(T1_rt[1][1]-T1_rt[0])/T1_rt[0]
                    if(e>0.01):
                        isConverged=isConverged and False
                else:
                    isConverged=isConverged and False
                
                time.sleep(0.5)
                
            
            #solvo i dati di questa iterazione
            rtExp[w,:]=[Client_rt[0]/10**9,T1_rt[0]/10**9]
            rtCI[w,:]=[(Client_rt[1][1]-Client_rt[0])/10**9,(T1_rt[1][1]-T1_rt[0])/10**9]
            
            jvm_sys.stopClient()
            jvm_sys.stopSystem()
            
            savemat("simple_exp.mat", {"RT":rtExp,"CI":rtCI,"Cli":W})
        
        
            
    except Exception as ex:
        traceback.print_exception(type(ex), ex, ex.__traceback__)
    finally:
        jvm_sys.stopClient()
        jvm_sys.stopSystem()
        if(g is not None):
            g.close()
        
