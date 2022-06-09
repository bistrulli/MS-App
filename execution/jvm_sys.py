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

class batchMinSim():
    #batch meaans param
    N=None
    K=None
    samples=None
    logfile=None
    
    def __init__(self,N=10,K=10,logFile=None):
        self.samples=None
        self.N=N
        self.K=K
        self.logfile=logFile
        
    
    def batchMeans(self):
        rtConverged=False
        tConverged=False
        Res={"RT":None,"T":None}
        
        rtFile=open(self.logfile)
        if os.fstat(rtFile.fileno()).st_size:
            if(self.samples is None):
                self.samples=np.loadtxt(self.logfile,ndmin=2,delimiter="\t")
            else:
                newSamples=np.loadtxt(self.logfile,ndmin=2,delimiter="\t",skiprows=self.samples.shape[0])
                if(newSamples.shape[0]>0):
                    self.samples=np.vstack((self.samples,newSamples))
            
            RT=self.batchMeansRT(self.samples[:,[0]])
            T=self.batchMeansT(self.samples[:,[1]])
            
            if(RT):
                print("####%s RT####"%(self.logfile))
                absE=abs((RT[1][1]-RT[0]))
                relE=absE/RT[0]
                print(RT[1][0]/10**9,RT[1][1]/10**9)
                print(RT[0]/10**9,relE*100,absE/10**9)
                if(relE<0.01):
                    rtConverged=True
                    
                Res["RT"]={"Avg":RT[0]/10**9,"CI":absE/10**9}

            
            if(T):
                print("####%s T####"%(self.logfile))
                absE=abs((T[1][1]-T[0]))
                relE=absE/T[0]
                print(T[1][0],T[1][1])
                print(T[0],relE*100,absE)
                if(relE<0.01):
                    tConverged=True
                
                Res["T"]={"Avg":T[0],"CI":absE}
            
        return [rtConverged and tConverged,Res]
        
    
    def batchMeansT(self,T):
        T=np.sort(T)
        T=T-T[0,0]
        
        Tend=int(np.floor(T[-1,0]/10**9))
        print("Time event Limit",Tend)
        Tsmp=np.matrix([T[np.where((T[:,0] > (i-1)*10**9) & (T[:,0] <= i*10**9)),0].shape[1] for i in range(1,Tend+1)]).T
        
        if(Tsmp.shape[0]<(self.N+1)*self.K):
            return False
        else:
            nB=int(np.floor(Tsmp.shape[0]//self.K))
            B=np.array([[Tsmp[int(k+b*self.K),0] for k in range(self.K)] for b in range(nB)])
        
            Bm=np.mean(B[1:-1,:],axis=1)
            
            print(np.mean(Bm))
            
            CI=st.t.interval(alpha=0.95, df=Bm.shape[0]-1,
              loc=np.mean(Bm),
              scale=st.sem(Bm))
            
            return [np.mean(Bm),CI]
        
    def batchMeansRT(self,RT):
        B=None
        print("RT batchmeans",RT.shape[0])
        if(RT.shape[0]<self.N*self.K):
            return False
        else:
            nB=int(np.floor(RT.shape[0]//self.K))
            B=np.array([[ RT[int(k+b*self.K),0] for k in range(self.K)] for b in range(nB)])
            
            Bm=np.mean(B,axis=1)
            
            CI=st.t.interval(alpha=0.95, df=Bm.shape[0]-1,
              loc=np.mean(Bm),
              scale=st.sem(Bm))
            
            return [np.mean(Bm),CI]
    

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
        r = Client("127.0.0.1:11211")
        r.set("stop", "0")
        r.set("started", "0")
        r.close()
        
        f = open("clietOut.log", "w+")
        f1 = open("clietErr.log", "w+")
        
        subprocess.Popen([javaCmd, "-Xmx30G", "-Xms30G",
                         #"-Djava.compiler=NONE", 
                         "-jar",'%sMS-Client/target/MS-Client-0.0.1-jar-with-dependencies.jar' % (self.sysRootPath),
                         '--initPop', '%d' % (pop), '--jedisHost', 'localhost', '--tier1Host', '127.0.0.1',
                         '--queues', '[\"think\", \"e1_bl\", \"e1_ex\", \"t1_hw\",\"e2_bl\", \"e2_ex\", \"t2_hw\"]'],stdout=f, stderr=f1)
        f.close()
        f1.close()
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
    
    def startSys(self,affinity=None):
        
        # if(self.isCpu):
        #     self.initCgroups()
        
        cpuEmu = 0 if(self.isCpu) else 1
        
        self.sys = []
        subprocess.Popen(["memcached", "-c", "2048", "-t", "20"])
        self.waitMemCached()
        self.sys.append(self.findProcessIdByName("memcached")[0])
        
        t1Outf = open("t1Out.log", "w+")
        t1Errf = open("t1Err.log", "w+")
        t2Outf = open("t2Out.log", "w+")
        t2Errf = open("t2Err.log", "w+")
        
        if(not self.isCpu):
            
            subprocess.Popen([javaCmd,
                            "-Xmx15G", "-Xms30G",
                             # "-XX:ParallelGCThreads=1",
                             # "-XX:+UnlockExperimentalVMOptions","-XX:+UseEpsilonGC",
                             #"-Djava.compiler=NONE", 
                             "-jar",'%sMS-Tier2/target/MS-Tier2-0.0.1-jar-with-dependencies.jar' % (self.sysRootPath),
                             '--cpuEmu', "%d" % (cpuEmu), '--jedisHost', 'localhost'],stdout=t2Outf, stderr=t2Errf)
            
            self.waitTier2()
            self.sys.append(self.findProcessIdByName("MS-Tier2-0.0.1")[0])
            
            subprocess.Popen([javaCmd,
                            "-Xmx30G", "-Xms30G",
                             # "-XX:ParallelGCThreads=1",
                             # "-XX:+UnlockExperimentalVMOptions","-XX:+UseEpsilonGC",
                             #"-Djava.compiler=NONE", 
                             "-jar",'%sMS-Tier1/target/MS-Tier1-0.0.1-jar-with-dependencies.jar' % (self.sysRootPath),
                             '--cpuEmu', "%d" % (cpuEmu), '--jedisHost', 'localhost',
                             "--tier2Host", "127.0.0.1"],stdout=t1Outf, stderr=t1Errf)
            
            self.waitTier1()
            self.sys.append(self.findProcessIdByName("MS-Tier1-0.0.1")[0])
        else:
            
            aff=np.array([[0,0],[0,0]]);
            
            if(affinity is not None):
                aff=affinity
            else:
                aff[0,:]=[2,6]
                aff[1,:]=[7,10]
            
            subprocess.Popen([javaCmd,
                             "-Xmx30G", "-Xms30G",
                             #"-Djava.compiler=NONE", "-Xint"
                             "-jar",'%sMS-Tier2/target/MS-Tier2-0.0.1-jar-with-dependencies.jar' % (self.sysRootPath),
                             '--cpuEmu', "%d" % (cpuEmu), '--jedisHost', 'localhost',
                             "--aff","%d-%d"%(aff[1,0],aff[1,1])],stdout=t2Outf, stderr=t2Errf)
            self.waitTier2()
            self.sys.append(self.findProcessIdByName("MS-Tier2-0.0.1")[0])
            
            subprocess.Popen([javaCmd,
                             "-Xmx30G", "-Xms30G",
                             #"-Djava.compiler=NONE", "-Xint" 
                             "-jar",'%sMS-Tier1/target/MS-Tier1-0.0.1-jar-with-dependencies.jar' % (self.sysRootPath),
                             '--cpuEmu', "%d" % (cpuEmu), '--jedisHost', 'localhost',
                             "--tier2Host", "127.0.0.1",
                             "--aff","%d-%d"%(aff[0,0],aff[0,1])],stdout=t1Outf, stderr=t1Errf)
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
        base_client = Client(("127.0.0.1", 11211))
        base_client.set("test_ex", "1")
        while(atpt < limit and not connected):
            try:
                r = req.get('http://127.0.0.1:3000?entry=e1&snd=test')
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
    
    def waitTier2(self):
        connected = False
        limit = 1000
        atpt = 0
        base_client = Client(("127.0.0.1", 11211))
        base_client.set("test_ex", "1")
        while(atpt < limit and not connected):
            try:
                r = req.get('http://127.0.0.1:3001?entry=e2&snd=test')
                connected = True
                break
            except:
                time.sleep(0.2)
            finally:
                atpt += 1
        
        base_client.close()
        if(connected):
            print("connected to tier2")
        else:
            raise ValueError("error while connceting to tier2")
    
    def waitClient(self):
        connected = False
        limit = 10000
        atpt = 0
        base_client = Client(("127.0.0.1", 11211))
        while(atpt < limit and (base_client.get("started") == None or base_client.get("started").decode('UTF-8') == "0")):
           time.sleep(0.2)
           atpt += 1
        
    def waitMemCached(self):
        connected = False
        base_client = Client(("127.0.0.1", 11211))
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
    
    
    
    def testSystem(self):
        self.startSys()
        r = Client("127.0.0.1:11211")
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
        sys = None
        N=40
        K=40
        
        #W=[35,40,50,60,70,80,100,120,140,180,200,220,240,250,260]
        W=[40,45,50,55,60,65,70]
        #W=np.random.randint(low=4,high=200,size=[20]) 
        rtExp=np.zeros([len(W),3])
        tExp=np.zeros([len(W),3])
        rtCI=np.zeros([len(W),3])
        tCI=np.zeros([len(W),3])
        NC=[]
        
        for w in range(len(W)) :
            
            #NC.append([np.inf,np.random.randint(low=1,high=13),np.random.randint(low=1,high=13)])
            
            NC.append([np.inf,15,10])#adesso li devo specificare manualmente  
            
            sys = jvm_sys("../", isCpu)
            
            ClientBM=batchMinSim(N=N, K=K, logFile="Client_rtlog.log")
            T1BM=batchMinSim(N=N, K=K, logFile="t1_rtlog.log")
            T2BM=batchMinSim(N=N, K=K, logFile="t2_rtlog.log")
        
            isConverged=False
            
            sys.startSys(affinity=np.array([[2,16],[18,27]]))
            sys.startClient(W[w])
            
            #g = Client("localhost:11211")
            #g.set("t1_hw", "%f" %(5))
            
            X = []
            resC=None
            resT1=None
            resT2=None
            while(not isConverged):
                
                
                resC=ClientBM.batchMeans()
                resT1=T1BM.batchMeans()
                resT2=T2BM.batchMeans()
                
                isConverged=resC[0] and resT1[0] and resT2[0]
                
                time.sleep(0.5)
            
            #solvo i dati di questa iterazione
            rtExp[w,:]=[resC[1]["RT"]["Avg"],resT1[1]["RT"]["Avg"],resT2[1]["RT"]["Avg"]]
            rtCI[w,:]=[resC[1]["RT"]["CI"],resT1[1]["RT"]["CI"],resT2[1]["RT"]["CI"]]
            
            tExp[w,:]=[resC[1]["T"]["Avg"],resT1[1]["T"]["Avg"],resT2[1]["T"]["Avg"]]
            tCI[w,:]=[resC[1]["T"]["CI"],resT1[1]["T"]["CI"],resT2[1]["T"]["CI"]]
            
            sys.stopClient()
            sys.stopSystem()
            
            savemat("./data/3tier_learnAsynch3.mat", {"RTm":rtExp,"rtCI":rtCI,"Tm":tExp,"tCI":tCI,"Cli":W,"NC":NC})
        
        
            
    except Exception as ex:
        traceback.print_exception(type(ex), ex, ex.__traceback__)
    finally:
        sys.stopClient()
        sys.stopSystem()
        if(g is not None):
            g.close()
        
