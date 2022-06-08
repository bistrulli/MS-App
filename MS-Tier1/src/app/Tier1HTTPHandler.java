package app;

import java.io.IOException;
import java.io.OutputStream;
import java.net.URI;
import java.util.Map;

import com.google.common.collect.Maps;
import com.hubspot.jinjava.Jinjava;

import com.sun.net.httpserver.HttpExchange;

import Server.AcquireHttpHandler;
import Server.SimpleTask;
import Server.TierHttpHandler;
import jni.GetThreadID;
import kong.unirest.HttpResponse;
import kong.unirest.Unirest;
import kong.unirest.UnirestException;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutionException;  

@SuppressWarnings("restriction")
public class Tier1HTTPHandler extends TierHttpHandler {

	private static String tier2Host = null;

	public Tier1HTTPHandler(SimpleTask lqntask, HttpExchange req, long stime) {
		super(lqntask, req, stime);
	}

	public void handleResponse(HttpExchange req, String requestParamValue) throws InterruptedException, IOException {
		int[] aff;
		// this.addToCGV2Group(this.getName());
		
		//questa levo aggiungere alla classe principale
		Map<String, String> reqParams = this.getLqntask().queryToMap(req.getRequestURI().getQuery());
		
		if ((aff = this.getLqntask().getAffinity()) != null)
			GetThreadID.setAffinity(GetThreadID.get_tid(), aff[0], aff[1]);

		this.measureIngress();

		Jinjava jinjava = new Jinjava();
		Map<String, Object> context = Maps.newHashMap();
		context.put("task", "Tier1");
		context.put("entry", "e1");
		
		
		HttpResponse<String> resp = null;
		CompletableFuture<HttpResponse<String>> future=null;
		try {
			this.measureEgress();
			//resp = Unirest.get(URI.create("http://" + Tier1HTTPHandler.getTier2Host() + ":3001/?id="+reqParams.get("id")+ "&entry=e2" + "&snd=" + this.getName()).toString()).header("Connection", "close").asString();
			
			future = Unirest.get(URI.create("http://" + Tier1HTTPHandler.getTier2Host() + ":3001/?id="+reqParams.get("id")+ "&entry=e2" + "&snd=" + this.getName()).toString())
					  .header("Connection", "close")
					  .asStringAsync(response -> {
					        int code = response.getStatus();
					        String body = response.getBody();
					    });
			this.measureReturn();
		} catch (UnirestException e) {
			e.printStackTrace();
		}

		String renderedTemplate = jinjava.render(this.getWebPageTpl(), context);

		if (!this.getLqntask().isEmulated()) {
			this.doWorkCPU();
		} else {
			Float executing = 0f;
			String[] entries = this.getLqntask().getEntries().keySet().toArray(new String[0]);
			for (String e : entries) {
				executing += this.getLqntask().getState().get(e + "_ex").get();
			}
			this.doWorkSleep(executing);
		}
		
		
		//per garantire lo steady state aspetto il termine delle richieste annidate
		try {
			future.get();
		} catch (InterruptedException e) {
			e.printStackTrace();
		} catch (ExecutionException e) {
			e.printStackTrace();
		}
		this.measureEgress();

		req.getResponseHeaders().set("Content-Type", "text/html; charset=UTF-8");
		req.getResponseHeaders().set("Cache-Control", "no-store, no-cache, max-age=0, must-revalidate");
		OutputStream outputStream = req.getResponseBody();
		req.sendResponseHeaders(200, renderedTemplate.length());
		outputStream.write(renderedTemplate.getBytes());
		outputStream.flush();
		outputStream.close();
		outputStream = null;
	}

	@Override
	public String getWebPageName() {
		return "tier1.html";
	}

	@Override
	public String getName() {
		return "e1";
	}

	public static String getTier2Host() {
		return tier2Host;
	}

	public static void setTier2Host(String tier2Host) {
		Tier1HTTPHandler.tier2Host = tier2Host;
	}
}
