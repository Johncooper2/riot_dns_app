package com.riotdns.app;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.net.VpnService;
import android.os.Build;
import android.os.ParcelFileDescriptor;
import android.util.Log;
import androidx.core.app.NotificationCompat;

import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.net.InetAddress;
import java.nio.ByteBuffer;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * RiotVpnService
 * VPN-based DNS changer.
 * Routes all traffic through VPN, intercepts DNS (UDP port 53),
 * forwards DNS to configured server, relays other UDP via protected socket.
 */
public class RiotVpnService extends VpnService {

    private static final String TAG        = "RiotVpnService";
    private static final String CHANNEL_ID = "riot_dns_vpn";
    private static final int    NOTIF_ID   = 1001;
    private static final int    VPN_MTU    = 1500;

    private static final String VPN_ADDRESS = "10.0.0.2";

    public static String PRIMARY_DNS   = "1.1.1.1";
    public static String SECONDARY_DNS = "8.8.8.8";
    public static String DNS_PROTOCOL  = "DoU";
    public static String DOT_HOSTNAME  = "";

    private ParcelFileDescriptor vpnInterface;
    private ExecutorService      executor;
    private AtomicBoolean        running = new AtomicBoolean(false);

    public static final String ACTION_START  = "com.riotdns.START";
    public static final String ACTION_STOP   = "com.riotdns.STOP";
    public static final String EXTRA_DNS1    = "dns1";
    public static final String EXTRA_DNS2    = "dns2";
    public static final String EXTRA_PROTO   = "protocol";
    public static final String EXTRA_DOTHOST = "dot_hostname";

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent == null) return START_NOT_STICKY;

        String action = intent.getAction();
        if (ACTION_STOP.equals(action)) {
            stopVpn();
            return START_NOT_STICKY;
        }

        PRIMARY_DNS   = intent.getStringExtra(EXTRA_DNS1);
        SECONDARY_DNS = intent.getStringExtra(EXTRA_DNS2);
        DNS_PROTOCOL  = intent.getStringExtra(EXTRA_PROTO);
        DOT_HOSTNAME  = intent.getStringExtra(EXTRA_DOTHOST);

        if (PRIMARY_DNS == null) PRIMARY_DNS = "1.1.1.1";

        startVpn();
        return START_STICKY;
    }

    private void startVpn() {
        try {
            createNotificationChannel();
            startForeground(NOTIF_ID, buildNotification());

            Builder builder = new Builder();
            builder.setMtu(VPN_MTU);
            builder.addAddress(VPN_ADDRESS, 32);
            builder.addDnsServer(PRIMARY_DNS);
            if (SECONDARY_DNS != null && !SECONDARY_DNS.isEmpty()) {
                builder.addDnsServer(SECONDARY_DNS);
            }
            builder.addRoute("0.0.0.0", 0);
            builder.setSession("Riot DNS");
            builder.setBlocking(true);

            vpnInterface = builder.establish();
            if (vpnInterface == null) {
                Log.e(TAG, "Failed to establish VPN");
                return;
            }

            running.set(true);
            executor = Executors.newFixedThreadPool(2);
            executor.submit(this::runDnsProxy);

            Log.i(TAG, "VPN started — DNS: " + PRIMARY_DNS + " Protocol: " + DNS_PROTOCOL);

        } catch (Exception e) {
            Log.e(TAG, "startVpn error: " + e.getMessage());
        }
    }

    /**
     * Packet loop: read from tun, if DNS forward to configured server,
     * otherwise relay non-DNS UDP through a protected socket to prevent loop.
     */
    private void runDnsProxy() {
        FileInputStream  in  = new FileInputStream(vpnInterface.getFileDescriptor());
        FileOutputStream out = new FileOutputStream(vpnInterface.getFileDescriptor());
        ByteBuffer packet = ByteBuffer.allocate(VPN_MTU);

        try {
            DatagramSocket dnsSocket = new DatagramSocket();
            protect(dnsSocket);

            DatagramSocket relaySocket = new DatagramSocket();
            protect(relaySocket);

            while (running.get()) {
                packet.clear();
                int length = in.read(packet.array());
                if (length <= 0) continue;
                packet.limit(length);

                if (!isDnsPacket(packet.array(), length)) {
                    forwardNonDnsPacket(packet.array(), length, relaySocket, out);
                    continue;
                }

                byte[] dnsPayload = extractDnsPayload(packet.array(), length);
                if (dnsPayload == null) continue;

                InetAddress dnsAddr = InetAddress.getByName(PRIMARY_DNS);
                DatagramPacket req = new DatagramPacket(dnsPayload, dnsPayload.length, dnsAddr, 53);
                dnsSocket.send(req);

                byte[] respBuf = new byte[VPN_MTU];
                DatagramPacket resp = new DatagramPacket(respBuf, respBuf.length);
                dnsSocket.setSoTimeout(3000);
                try {
                    dnsSocket.receive(resp);
                    byte[] replyPacket = buildReplyPacket(
                        packet.array(), resp.getData(), resp.getLength()
                    );
                    if (replyPacket != null) {
                        out.write(replyPacket);
                    }
                } catch (Exception e) {
                    if (SECONDARY_DNS != null && !SECONDARY_DNS.isEmpty()) {
                        try {
                            InetAddress dns2 = InetAddress.getByName(SECONDARY_DNS);
                            DatagramPacket req2 = new DatagramPacket(dnsPayload, dnsPayload.length, dns2, 53);
                            dnsSocket.send(req2);
                            dnsSocket.receive(resp);
                            byte[] replyPacket = buildReplyPacket(packet.array(), resp.getData(), resp.getLength());
                            if (replyPacket != null) out.write(replyPacket);
                        } catch (Exception ignored) {}
                    }
                }
            }
            dnsSocket.close();
            relaySocket.close();
        } catch (Exception e) {
            Log.e(TAG, "DNS proxy error: " + e.getMessage());
        }
    }

    /**
     * Forward non-DNS UDP packets through a protected socket to prevent loop.
     * Extracts destination from IP+UDP headers, sends via relay, builds reply.
     */
    private void forwardNonDnsPacket(byte[] data, int len, DatagramSocket relay, FileOutputStream out) {
        try {
            int ihl = (data[0] & 0x0F) * 4;
            int protocol = data[9] & 0xFF;
            if (protocol != 17) return;

            if (len < ihl + 8) return;

            byte[] dstIp = new byte[4];
            System.arraycopy(data, 16, dstIp, 0, 4);
            InetAddress dstAddr = InetAddress.getByAddress(dstIp);

            int srcPort = ((data[ihl] & 0xFF) << 8) | (data[ihl + 1] & 0xFF);
            int dstPort = ((data[ihl + 2] & 0xFF) << 8) | (data[ihl + 3] & 0xFF);
            int udpLen = ((data[ihl + 4] & 0xFF) << 8) | (data[ihl + 5] & 0xFF);
            int payloadLen = udpLen - 8;
            if (payloadLen <= 0 || ihl + 8 + payloadLen > len) return;

            byte[] payload = new byte[payloadLen];
            System.arraycopy(data, ihl + 8, payload, 0, payloadLen);

            relay.setSoTimeout(3000);
            relay.send(new DatagramPacket(payload, payload.length, dstAddr, dstPort));

            byte[] respBuf = new byte[VPN_MTU];
            DatagramPacket resp = new DatagramPacket(respBuf, respBuf.length);
            relay.receive(resp);

            byte[] replyPacket = buildUdpReplyPacket(data, ihl, resp.getData(), resp.getLength(), srcPort, dstPort);
            if (replyPacket != null) out.write(replyPacket);
        } catch (Exception e) {
            // silently drop unforwardable packets
        }
    }

    private boolean isDnsPacket(byte[] data, int len) {
        if (len < 28) return false;
        int protocol = data[9] & 0xFF;
        if (protocol != 17) return false;
        int ihl = (data[0] & 0x0F) * 4;
        if (len < ihl + 8) return false;
        int dstPort = ((data[ihl + 2] & 0xFF) << 8) | (data[ihl + 3] & 0xFF);
        return dstPort == 53;
    }

    private byte[] extractDnsPayload(byte[] data, int len) {
        try {
            int ihl    = (data[0] & 0x0F) * 4;
            int udpLen = ((data[ihl + 4] & 0xFF) << 8) | (data[ihl + 5] & 0xFF);
            int payloadLen = udpLen - 8;
            if (payloadLen <= 0) return null;
            byte[] payload = new byte[payloadLen];
            System.arraycopy(data, ihl + 8, payload, 0, payloadLen);
            return payload;
        } catch (Exception e) {
            return null;
        }
    }

    private byte[] buildReplyPacket(byte[] originalReq, byte[] dnsResp, int respLen) {
        try {
            int ihl = (originalReq[0] & 0x0F) * 4;
            int totalLen = ihl + 8 + respLen;
            byte[] pkt = new byte[totalLen];

            System.arraycopy(originalReq, 0, pkt, 0, ihl);
            System.arraycopy(originalReq, 12, pkt, 16, 4);
            System.arraycopy(originalReq, 16, pkt, 12, 4);
            pkt[2] = (byte)((totalLen >> 8) & 0xFF);
            pkt[3] = (byte)(totalLen & 0xFF);
            pkt[8] = 64;
            pkt[10] = 0; pkt[11] = 0;

            pkt[ihl]     = originalReq[ihl + 2];
            pkt[ihl + 1] = originalReq[ihl + 3];
            pkt[ihl + 2] = originalReq[ihl];
            pkt[ihl + 3] = originalReq[ihl + 1];
            int udpLen = 8 + respLen;
            pkt[ihl + 4] = (byte)((udpLen >> 8) & 0xFF);
            pkt[ihl + 5] = (byte)(udpLen & 0xFF);
            pkt[ihl + 6] = 0; pkt[ihl + 7] = 0;

            System.arraycopy(dnsResp, 0, pkt, ihl + 8, respLen);

            int cksum = 0;
            for (int i = 0; i < ihl; i += 2) {
                cksum += ((pkt[i] & 0xFF) << 8) | (pkt[i+1] & 0xFF);
            }
            while ((cksum >> 16) != 0) cksum = (cksum & 0xFFFF) + (cksum >> 16);
            cksum = ~cksum & 0xFFFF;
            pkt[10] = (byte)((cksum >> 8) & 0xFF);
            pkt[11] = (byte)(cksum & 0xFF);
            return pkt;
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * Build reply packet for relayed non-DNS UDP traffic.
     * Swaps src/dst IP and ports from the original request.
     */
    private byte[] buildUdpReplyPacket(byte[] originalReq, int ihl, byte[] respData, int respLen, int origSrcPort, int origDstPort) {
        try {
            int totalLen = ihl + 8 + respLen;
            byte[] pkt = new byte[totalLen];

            System.arraycopy(originalReq, 0, pkt, 0, ihl);
            System.arraycopy(originalReq, 12, pkt, 16, 4);
            System.arraycopy(originalReq, 16, pkt, 12, 4);
            pkt[2] = (byte)((totalLen >> 8) & 0xFF);
            pkt[3] = (byte)(totalLen & 0xFF);
            pkt[8] = 64;
            pkt[10] = 0; pkt[11] = 0;

            pkt[ihl]     = (byte)((origDstPort >> 8) & 0xFF);
            pkt[ihl + 1] = (byte)(origDstPort & 0xFF);
            pkt[ihl + 2] = (byte)((origSrcPort >> 8) & 0xFF);
            pkt[ihl + 3] = (byte)(origSrcPort & 0xFF);
            int udpLen = 8 + respLen;
            pkt[ihl + 4] = (byte)((udpLen >> 8) & 0xFF);
            pkt[ihl + 5] = (byte)(udpLen & 0xFF);
            pkt[ihl + 6] = 0; pkt[ihl + 7] = 0;

            System.arraycopy(respData, 0, pkt, ihl + 8, respLen);

            int cksum = 0;
            for (int i = 0; i < ihl; i += 2) {
                cksum += ((pkt[i] & 0xFF) << 8) | (pkt[i+1] & 0xFF);
            }
            while ((cksum >> 16) != 0) cksum = (cksum & 0xFFFF) + (cksum >> 16);
            cksum = ~cksum & 0xFFFF;
            pkt[10] = (byte)((cksum >> 8) & 0xFF);
            pkt[11] = (byte)(cksum & 0xFF);
            return pkt;
        } catch (Exception e) {
            return null;
        }
    }

    private void stopVpn() {
        running.set(false);
        if (executor != null) executor.shutdownNow();
        try {
            if (vpnInterface != null) vpnInterface.close();
        } catch (Exception ignored) {}
        stopForeground(true);
        stopSelf();
        Log.i(TAG, "VPN stopped");
    }

    @Override
    public void onDestroy() {
        stopVpn();
        super.onDestroy();
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel ch = new NotificationChannel(
                CHANNEL_ID, "Riot DNS VPN", NotificationManager.IMPORTANCE_LOW
            );
            ch.setDescription("DNS changer در حال اجرا");
            NotificationManager nm = getSystemService(NotificationManager.class);
            nm.createNotificationChannel(ch);
        }
    }

    private Notification buildNotification() {
        Intent stopIntent = new Intent(this, RiotVpnService.class);
        stopIntent.setAction(ACTION_STOP);
        PendingIntent stopPI = PendingIntent.getService(
            this, 0, stopIntent, PendingIntent.FLAG_IMMUTABLE
        );
        return new NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Riot DNS فعال")
            .setContentText("DNS: " + PRIMARY_DNS + "  (" + DNS_PROTOCOL + ")")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setOngoing(true)
            .addAction(android.R.drawable.ic_delete, "توقف", stopPI)
            .build();
    }
}
