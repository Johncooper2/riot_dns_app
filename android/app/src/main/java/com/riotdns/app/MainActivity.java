package com.riotdns.app;

import android.app.Activity;
import android.content.Intent;
import android.net.VpnService;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import androidx.annotation.NonNull;

public class MainActivity extends FlutterActivity {

    private static final String VPN_CHANNEL  = "com.riotdns/vpn";
    private static final int    VPN_REQ_CODE = 100;

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
                    RiotVpnService.PRIMARY_DNS = null;
                    result.success(true);
                    break;
                case "isVpnRunning":
                    result.success(RiotVpnService.PRIMARY_DNS != null);
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
            startActivityForResult(intent, VPN_REQ_CODE);
        } else {
            launchVpnService();
            if (pendingResult != null) {
                pendingResult.success(true);
                pendingResult = null;
            }
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
        intent.putExtra(RiotVpnService.EXTRA_DNS1,
            pendingDns1 != null ? pendingDns1 : "1.1.1.1");
        intent.putExtra(RiotVpnService.EXTRA_DNS2,
            pendingDns2 != null ? pendingDns2 : "8.8.8.8");
        intent.putExtra(RiotVpnService.EXTRA_PROTO,
            pendingProto != null ? pendingProto : "DoU");
        intent.putExtra(RiotVpnService.EXTRA_DOTHOST,
            pendingDotHost != null ? pendingDotHost : "");
        startService(intent);
    }
}
