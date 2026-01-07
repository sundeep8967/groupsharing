package com.transistorsoft.locationmanager.a;

import android.content.Context;

/**
 * Patched license validator - always returns valid.
 * This replaces the original obfuscated license check class.
 * Method signatures match the decompiled original.
 */
public class A {
    private static boolean a = true; // Always licensed
    private static boolean b = true; // Always valid

    // Constructor
    public A() {
    }

    // Boolean methods - always return true
    public static boolean a(Context context) {
        return true;
    }

    public static boolean b(Context context) {
        return true;
    }

    // Void method invoked by Settings.load
    public static void c(Context context) {
        // No-op - bypass license initialization
    }

    public static boolean d(Context context) {
        return true;
    }

    public static boolean e(Context context) {
        return true;
    }

    private static boolean f(Context context) {
        return true;
    }

    // Get license status - always returns licensed state
    public static int g() {
        return 1; // Licensed
    }

    public static boolean h() {
        return true;
    }

    public static boolean i() {
        return true;
    }

    // Void methods for initialization
    public static void j(Context context) {
        // No-op
    }

    public static void k(Context context) {
        // No-op
    }

    // Additional void methods that might exist
    public static void l(Context context) {
        // No-op
    }

    public static void m(Context context) {
        // No-op
    }

    // String returning methods
    public static String n() {
        return "";
    }

    public static String o() {
        return "";
    }
}
