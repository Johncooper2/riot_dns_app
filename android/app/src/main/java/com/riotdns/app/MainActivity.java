package com.riotdns.app;

import android.app.Activity;
import android.app.ActivityManager;
import android.content.Context;
import android.content.Intent;
import android.net.VpnService;
import android.os.Bundle;
import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * MainActivity
 * Flutter ↔ Android VPN bridge از طریق MethodChannel
 */
public class MainActivity extends FlutterActivity {

    private static final String VPN_CHANNEL   = "com.riotdns/vpn";
    private static final int    VPN_REQ_CODE  = 100;

    // pending args هنگام درخواست permission
    private String pendingDns1, pendingDns2, pendingProto, pendingDotHost;
    private MethodChannel.Result pendingResult;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(
            flutterEngine.getDartExecutor().getBinaryMessenger(), VPN_CHANNEL
        ).setMethodCallHandler((call, result) -> {

            switch (call.method) {

                case "startVpn":
                    pendingDns1    = call.argument("dns1");
                    pendingDns2    = call.argument("dns2");
                    pendingProto   = call.argument("protocol");
                    pendingDotHost = call.argument("dot_hostname");
                    pendingResult  = result;
                    requestVpnPermission();
                    break;

                case "stopVpn":
                    Intent stop = new Intent(this, RiotVpnService.class);
                    stop.setAction(RiotVpnService.ACTION_STOP);
                    startService(stop);
                    result.success(true);
                    break;

                case "isVpnRunning":
                    result.success(RiotVpnService.PRIMARY_DNS != null &&
                                   !RiotVpnService.PRIMARY_DNS.isEmpty() &&
                                   isServiceRunning());
                    break;

                case "getActiveDns":
                    result.success(RiotVpnService.PRIMARY_DNS);
                    break;

                default:
                    result.notImplemented();
            }
        });
    }

    private void requestVpnPermission() {
        Intent intent = VpnService.prepare(this);
        if (intent != null) {
            // نیاز به permission کاربر داریم
            startActivityForResult(intent, VPN_REQ_CODE);
        } else {
            // قبلاً permission داده شده
            launchVpnService();
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == VPN_REQ_CODE) {
            if (resultCode == Activity.RESULT_OK) {
                launchVpnService();
                if (pendingResult != null) pendingResult.success(true);
            } else {
                if (pendingResult != null) pendingResult.success(false);
            }
            pendingResult = null;
        }
    }

    private void launchVpnService() {
        Intent intent = new Intent(this, RiotVpnService.class);
        intent.setAction(RiotVpnService.ACTION_START);
        intent.putExtra(RiotVpnService.EXTRA_DNS1,    pendingDns1);
        intent.putExtra(RiotVpnService.EXTRA_DNS2,    pendingDns2);
        intent.putExtra(RiotVpnService.EXTRA_PROTO,   pendingProto);
        intent.putExtra(RiotVpnService.EXTRA_DOTHOST, pendingDotHost);
        startService(intent);
    }

    private boolean isServiceRunning() {
        ActivityManager am = (ActivityManager) getSystemService(Context.ACTIVITY_SERVICE);
        if (am == null) return false;
        for (ActivityManager.RunningServiceInfo info : am.getRunningServices(Integer.MAX_VALUE)) {
            if (RiotVpnService.class.getName().equals(info.service.getClassName())) {
                return true;
            }
        }
        return false;
    }
}
