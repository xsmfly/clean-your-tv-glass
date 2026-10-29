package com.gathin.tvhome;

import android.os.Handler;
import android.os.Looper;

import org.json.JSONObject;

import java.net.HttpURLConnection;
import java.net.URL;
import java.util.Scanner;

/**
 * Header weather: temperature, a short condition, and PM2.5, fetched over HTTPS from Open-Meteo.
 * Location is either an override "lat,lon" (config weather_location) or auto-detected by IP (ipinfo.io).
 * Uses only the built-in HttpURLConnection and org.json, so no extra dependencies. Each fetch starts its
 * own background thread and posts the result (or the failure reason) back to the main thread via the callback.
 */
final class WeatherFetcher {
    interface Callback {
        /** e.g. "16° 多云 · PM2.5 23" */
        void onResult(String text);
        /** Failure reason, for on-screen diagnosis. */
        void onError(String message);
    }

    private final String override;   // "lat,lon" or null for auto
    private final Handler main = new Handler(Looper.getMainLooper());

    WeatherFetcher(String override) {
        this.override = (override == null || override.trim().isEmpty()) ? null : override.trim();
    }

    void fetch(Callback cb) {
        new Thread(() -> {
            try {
                double[] c = coords();
                JSONObject fc = get("https://api.open-meteo.com/v1/forecast?latitude=" + c[0]
                        + "&longitude=" + c[1] + "&current=temperature_2m,weather_code&timezone=auto");
                JSONObject aq = get("https://air-quality-api.open-meteo.com/v1/air-quality?latitude=" + c[0]
                        + "&longitude=" + c[1] + "&current=pm2_5&timezone=auto");
                double temp = fc.getJSONObject("current").getDouble("temperature_2m");
                int code = fc.getJSONObject("current").getInt("weather_code");
                double pm = aq.getJSONObject("current").optDouble("pm2_5", Double.NaN);
                StringBuilder b = new StringBuilder();
                b.append(Math.round(temp)).append("° ").append(weatherText(code));
                if (!Double.isNaN(pm)) b.append(" · PM2.5 ").append(Math.round(pm));
                String out = b.toString();
                main.post(() -> cb.onResult(out));
            } catch (Exception e) {
                String m = e.getClass().getSimpleName() + ": " + (e.getMessage() == null ? "" : e.getMessage());
                main.post(() -> cb.onError(m));
            }
        }).start();
    }

    private double[] coords() throws Exception {
        if (override != null && override.contains(",")) {
            String[] p = override.split(",");
            return new double[]{ Double.parseDouble(p[0].trim()), Double.parseDouble(p[1].trim()) };
        }
        JSONObject geo = get("https://ipinfo.io/json");
        String loc = geo.optString("loc", "");   // "lat,lon"
        String[] p = loc.split(",");
        return new double[]{ Double.parseDouble(p[0]), Double.parseDouble(p[1]) };
    }

    private JSONObject get(String url) throws Exception {
        HttpURLConnection c = (HttpURLConnection) new URL(url).openConnection();
        c.setConnectTimeout(8000);
        c.setReadTimeout(8000);
        c.setRequestProperty("User-Agent", "cleanyourtv");
        c.connect();
        try (Scanner s = new Scanner(c.getInputStream()).useDelimiter("\\A")) {
            String body = s.hasNext() ? s.next() : "";
            return new JSONObject(body);
        } finally {
            c.disconnect();
        }
    }

    private static String weatherText(int code) {
        if (code == 0) return "晴";
        if (code == 1) return "晴间多云";
        if (code == 2) return "多云";
        if (code == 3) return "阴";
        if (code == 45 || code == 48) return "雾";
        if (code >= 51 && code <= 57) return "毛毛雨";
        if (code >= 61 && code <= 67) return "雨";
        if (code >= 71 && code <= 77) return "雪";
        if (code >= 80 && code <= 82) return "阵雨";
        if (code >= 85 && code <= 86) return "阵雪";
        if (code >= 95) return "雷阵雨";
        return "—";
    }
}
