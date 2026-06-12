package com.riotdns.app;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;

public class BootReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        if (!Intent.ACTION_BOOT_COMPLETED.equals(intent.getAction())) return;
        SharedPreferences prefs = context.getSharedPreferences("riot_dns", Context.MODE_PRIVATE);
        boolean autoStart = prefs.getBoolean("auto_start", false);
        if (!autoStart) return;
        String dns1  = prefs.getString("dns1",     "1.1.1.1");
        String dns2  = prefs.getString("dns2",     "8.8.8.8");
        String proto = prefs.getString("protocol", "DoU");
        String host  = prefs.getString("dot_host", "");
        Intent vpn = new Intent(context, RiotVpnService.class);
        vpn.setAction(RiotVpnService.ACTION_START);
        vpn.putExtra(RiotVpnService.EXTRA_DNS1,    dns1);
        vpn.putExtra(RiotVpnService.EXTRA_DNS2,    dns2);
        vpn.putExtra(RiotVpnService.EXTRA_PROTO,   proto);
        vpn.putExtra(RiotVpnService.EXTRA_DOTHOST, host);
        context.startService(vpn);
    }
}
