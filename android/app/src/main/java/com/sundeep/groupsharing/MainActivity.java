package com.sundeep.groupsharing;

import android.content.Intent;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "background_location";

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    if (call.method.equals("start")) {
                        String userId = call.argument("userId");
                        Intent i = new Intent(this, BackgroundLocationService.class);
                        i.putExtra(BackgroundLocationService.EXTRA_USER_ID, userId);
                        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                            startForegroundService(i);
                        } else {
                            startService(i);
                        }
                        result.success(null);
                    } else if (call.method.equals("stop")) {
                        Intent i = new Intent(this, BackgroundLocationService.class);
                        stopService(i);
                        result.success(null);
                    } else {
                        result.notImplemented();
                    }
                });
    }
}
