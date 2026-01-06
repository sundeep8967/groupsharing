package com.transistorsoft.locationmanager.a;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.List;

public class A {
    // Fields
    public static Context a;
    public static AtomicBoolean b = new AtomicBoolean(true);
    public static AtomicBoolean c = new AtomicBoolean(true);
    public static Handler d;
    public static AtomicBoolean e = new AtomicBoolean(true);
    public static AtomicBoolean f = new AtomicBoolean(true);

    static {
    }

    public A() {
    }

    // --- Private Native Stubs (Implemented in Java now) ---
    private static String a() {
        return "";
    }

    private static String a(Context c) {
        return "";
    }

    private static String a(Context c, String s) {
        return "";
    }

    private static String a(List l, String s) {
        return "";
    }

    private static void a(Context c, String s, String s1) {
    }

    private static boolean a(String s, String s1, boolean b1) {
        return true;
    } // Was native

    private static boolean b() {
        return true;
    } // Was native

    private static boolean b(Context c) {
        return true;
    }

    private static boolean b(String s, String s1, boolean b1) {
        return true;
    }

    private static String c() {
        return "";
    } // Was native

    public static void c(Context c) {
    }

    private static String d() {
        return "";
    } // Was native

    // --- CRITICAL BYPASS ---
    public static boolean d(Context c) {
        return true;
    } // Main check

    private static String e() {
        return "";
    } // Was native

    private static void e(Context c) {
    }

    private static String f() {
        return "";
    } // Was native

    // --- CRITICAL BYPASS ---
    private static boolean f(Context c) {
        return true;
    }

    private static String g() {
        return "";
    } // Was native

    private static String[] getAccessories() {
        return new String[0];
    } // Was native

    // Public API
    public static boolean getDBFlag() {
        return true;
    }

    public static String getPlatform() {
        return "android";
    } // Was native

    private static String h() {
        return "";
    } // Was native

    private static String i() {
        return "";
    } // Was native

    private static String j() {
        return "";
    } // Was native

    private static String k() {
        return "";
    }

    private static String l() {
        return "";
    }

    private static String m() {
        return "";
    }

    private static String n() {
        return "";
    }

    private static String o() {
        return "";
    }

    private static String p() {
        return "";
    }

    public static Handler q() {
        if (d == null) {
            d = new Handler(Looper.getMainLooper());
        }
        return d;
    }

    private static String r() {
        return "";
    }

    public static void r(boolean flag) {
        e.set(flag);
        f.set(true);
    }

    private static void s() {
    }

    private static boolean t() {
        return true;
    }

    private static boolean validateAccessory(String s, String s1, String s2) {
        return true;
    } // Was native
}
