package app;

import java.io.File;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.util.HashMap;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.TimeUnit;

import com.google.common.net.InetAddresses;
import com.google.common.net.InternetDomainName;
import com.google.gson.Gson;

import Server.SimpleTask;
import gnu.getopt.Getopt;
import gnu.getopt.LongOpt;
import kong.unirest.Unirest;
import net.spy.memcached.MemcachedClient;

public class Main {
	private static Integer initPop = -1;
	private static String jedisHost = null;
	private static String[] systemQueues = null;
	private static File expFile = null;
	private static String tier1Host = null;
	private static boolean sim;

	public static void main(String[] args) {

		System.setProperty("net.spy.log.LoggerImpl", "net.spy.memcached.compat.log.SLF4JLogger");
		Unirest.config().concurrency(2000, 2000);
		Unirest.config().socketTimeout(0);
		Unirest.config().connectTimeout(0);

		Main.getCliOptions(args);
		final SimpleTask[] Sys = Main.genSystem();
		Main.resetState(Sys[0]);
		Sys[0].start();

		MemcachedClient memcachedClient = null;
		while (true) {
			if (Client.isStarted.get()) {
				break;
			} else {
				System.out.println("waiting for client");
			}
			try {
				TimeUnit.MILLISECONDS.sleep(200);
			} catch (InterruptedException e) {
				e.printStackTrace();
			}
		}
		try {
			memcachedClient = new MemcachedClient(new InetSocketAddress(Main.jedisHost, 11211));
			memcachedClient.set("started", 36000, "1").get();
		} catch (IOException | InterruptedException | ExecutionException e) {
			e.printStackTrace();
		}
	}

	public static void resetState(SimpleTask task) {
		MemcachedClient memcachedClient = null;
		try {
			memcachedClient = new MemcachedClient(new InetSocketAddress(Main.jedisHost, 11211));
		} catch (IOException e) {
			e.printStackTrace();
		}
		try {
			memcachedClient.set("think", 3600, String.valueOf(Main.initPop)).get();
		} catch (InterruptedException | ExecutionException e1) {
			e1.printStackTrace();
		}
		memcachedClient.shutdown();
	}

	public static SimpleTask[] genSystem() {
		HashMap<String, Class> clientEntries = new HashMap<String, Class>();
		HashMap<String, Long> clientEntries_stimes = new HashMap<String, Long>();
		clientEntries.put("think", Client.class);
		clientEntries_stimes.put("think", 1000l);
		final SimpleTask client = new SimpleTask(clientEntries, clientEntries_stimes, Main.initPop, "Client",
				Main.jedisHost, 10l, 100l);
		Client.setTier1Host(Main.tier1Host);
		return new SimpleTask[] { client };
	}

	public static boolean validate(final String hostname) {
		return InetAddresses.isUriInetAddress(hostname) || InternetDomainName.isValid(hostname);
	}

	public static void getCliOptions(String[] args) {
		int c;
		LongOpt[] longopts = new LongOpt[5];
		longopts[0] = new LongOpt("initPop", LongOpt.REQUIRED_ARGUMENT, null, 0);
		longopts[1] = new LongOpt("jedisHost", LongOpt.REQUIRED_ARGUMENT, null, 1);
		longopts[2] = new LongOpt("queues", LongOpt.REQUIRED_ARGUMENT, null, 2);
		longopts[3] = new LongOpt("tier1Host", LongOpt.REQUIRED_ARGUMENT, null, 3);
		longopts[4] = new LongOpt("sim", LongOpt.REQUIRED_ARGUMENT, null, 4);

		Getopt g = new Getopt("ddctrl", args, "", longopts);
		g.setOpterr(true);
		while ((c = g.getopt()) != -1) {
			switch (c) {
			case 0:
				try {
					Main.initPop = Integer.valueOf(g.getOptarg());
				} catch (NumberFormatException e) {
					System.err.println(String.format("%s is not valid, it must be 0 or 1.", g.getOptarg()));
				}
				break;
			case 1:
				try {
					if (!Main.validate(g.getOptarg())) {
						throw new Exception(String.format("%s is not a valid jedis URL", g.getOptarg()));
					}
					Main.jedisHost = String.valueOf(g.getOptarg());
				} catch (Exception e) {
					e.printStackTrace();
				}
				break;
			case 2:
				try {
					Gson gson = new Gson();
					Main.systemQueues = gson.fromJson(String.valueOf(g.getOptarg()), String[].class);
				} catch (Exception e) {
					e.printStackTrace();
				}
				break;
			case 3:
				try {
					Main.tier1Host = String.valueOf(g.getOptarg());
				} catch (Exception e) {
					e.printStackTrace();
				}
				break;
			case 4:
				try {
					Main.sim = Integer.valueOf(g.getOptarg()) > 0 ? true : false;
				} catch (Exception e) {
					e.printStackTrace();
				}
				break;
			default:
				break;
			}
		}
	}
}
