// lib/widgets/common.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../models/dns_server.dart';

// ── Latency Badge ─────────────────────────────────────────────
class LatencyBadge extends StatelessWidget {
  final double? ms;
  final double fontSize;
  const LatencyBadge({super.key, this.ms, this.fontSize = 13});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.latencyColor(ms);
    final label = ms == null ? 'TIMEOUT' : '${ms!.toStringAsFixed(0)}ms';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label, style: TextStyle(
        color: color, fontSize: fontSize, fontWeight: FontWeight.w700,
        fontFamily: 'monospace',
      )),
    );
  }
}

// ── Protocol Badge ────────────────────────────────────────────
class ProtocolBadge extends StatelessWidget {
  final String protocol;
  const ProtocolBadge({super.key, required this.protocol});

  static Color _color(String p) {
    switch (p) {
      case 'DoT': return AppTheme.green;
      case 'DoH': return AppTheme.accent;
      case 'DoU': return AppTheme.yellow;
      default:    return AppTheme.textSec;
    }
  }

  static String _icon(String p) {
    switch (p) {
      case 'DoT': return '🔒';
      case 'DoH': return '🌐';
      case 'DoU': return '📶';
      default:    return '✗';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _color(protocol);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withOpacity(0.4)),
      ),
      child: Text(
        '${_icon(protocol)} $protocol',
        style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ── DNS Card ──────────────────────────────────────────────────
class DnsCard extends StatelessWidget {
  final DnsServer server;
  final bool isActive;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onActivate;
  final VoidCallback? onLongPress;

  const DnsCard({
    super.key,
    required this.server,
    this.isActive   = false,
    this.isSelected = false,
    this.onTap,
    this.onActivate,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isActive
        ? AppTheme.green
        : isSelected
            ? AppTheme.accent
            : AppTheme.border;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: isActive ? 2 : 1),
          boxShadow: isActive ? [BoxShadow(color: AppTheme.green.withOpacity(0.15), blurRadius: 12)] : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                // نام و IP
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      if (isActive) ...[
                        const Icon(Icons.shield, color: AppTheme.green, size: 14),
                        const SizedBox(width: 4),
                      ],
                      Flexible(child: Text(server.name,
                        style: TextStyle(
                          color: isActive ? AppTheme.green : AppTheme.textPrim,
                          fontSize: 14, fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      )),
                    ]),
                    const SizedBox(height: 2),
                    Text(server.ip, style: const TextStyle(
                      color: AppTheme.textSec, fontSize: 12, fontFamily: 'monospace',
                    )),
                  ],
                )),

                // latency
                if (server.isScanning)
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent))
                else
                  LatencyBadge(ms: server.latencyMs),
              ]),

              if (server.latencyMs != null) ...[
                const SizedBox(height: 10),
                // Protocol badges
                Row(children: [
                  if (server.douSupported == true) ...[
                    const ProtocolBadge(protocol: 'DoU'),
                    const SizedBox(width: 5),
                  ],
                  if (server.dotSupported == true) ...[
                    const ProtocolBadge(protocol: 'DoT'),
                    const SizedBox(width: 5),
                  ],
                  if (server.dohSupported == true) ...[
                    const ProtocolBadge(protocol: 'DoH'),
                    const SizedBox(width: 5),
                  ],
                  const Spacer(),
                  // بهترین روش اندروید
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.bg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '📱 ${server.bestProtocolForAndroid}',
                      style: const TextStyle(color: AppTheme.textSec, fontSize: 11),
                    ),
                  ),
                ]),

                // جزئیات latency
                const SizedBox(height: 8),
                Row(children: [
                  _stat('AVG', '${server.latencyMs!.toStringAsFixed(0)}ms', AppTheme.latencyColor(server.latencyMs)),
                  const SizedBox(width: 12),
                  if (server.jitterMs != null)
                    _stat('JIT', '${server.jitterMs!.toStringAsFixed(0)}ms', AppTheme.textSec),
                  const SizedBox(width: 12),
                  if (server.lossPct != null)
                    _stat('LOSS', '${server.lossPct!.toStringAsFixed(0)}%',
                      server.lossPct! > 0 ? AppTheme.red : AppTheme.green),
                  const Spacer(),
                  // دکمه فعال‌سازی
                  if (!isActive && onActivate != null)
                    TextButton.icon(
                      onPressed: onActivate,
                      icon: const Icon(Icons.play_arrow, size: 15),
                      label: const Text('فعال کن', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.accent,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                      ),
                    )
                  else if (isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.green.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('● فعال', style: TextStyle(color: AppTheme.green, fontSize: 12)),
                    ),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String val, Color color) => Row(
    children: [
      Text('$label ', style: const TextStyle(color: AppTheme.textSec, fontSize: 10)),
      Text(val, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
    ],
  );
}

// ── Android Config Sheet ──────────────────────────────────────
class AndroidConfigSheet extends StatelessWidget {
  final DnsServer server;
  const AndroidConfigSheet({super.key, required this.server});

  @override
  Widget build(BuildContext context) {
    final proto = server.bestProtocolForAndroid;
    final value = server.androidSettingValue;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('📱 تنظیم در اندروید', style: TextStyle(
            color: AppTheme.textPrim, fontSize: 17, fontWeight: FontWeight.w700,
          )),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: AppTheme.textSec),
            onPressed: () => Navigator.pop(context),
          ),
        ]),
        const Divider(color: AppTheme.border),
        const SizedBox(height: 8),

        // نام و پروتکل
        Row(children: [
          Text(server.name, style: const TextStyle(color: AppTheme.textPrim, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          ProtocolBadge(protocol: proto),
        ]),
        const SizedBox(height: 16),

        // مقدار برای کپی
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(children: [
            Expanded(child: Text(value, style: const TextStyle(
              color: AppTheme.accent, fontSize: 13, fontFamily: 'monospace',
            ))),
            IconButton(
              icon: const Icon(Icons.copy, color: AppTheme.textSec, size: 18),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('کپی شد!'), duration: Duration(seconds: 1)),
                );
              },
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // راهنمای مرحله‌ای
        const Text('راهنمای تنظیم:', style: TextStyle(color: AppTheme.textSec, fontSize: 13)),
        const SizedBox(height: 8),
        _steps(proto, value),
        const SizedBox(height: 16),

        // توضیح پروتکل
        _protocolInfo(proto),
        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _steps(String proto, String value) {
    final List<String> steps;
    switch (proto) {
      case 'DoT':
        steps = [
          'تنظیمات گوشی رو باز کن',
          'برو به: اتصالات (Connections)',
          'تنظیمات بیشتر (More connection settings)',
          'Private DNS رو بزن',
          'گزینه «Private DNS provider hostname» رو انتخاب کن',
          'این آدرس رو وارد کن ↑',
          'ذخیره کن',
        ];
      case 'DoH':
        steps = [
          'اپ AdGuard یا Intra رو نصب کن',
          'در تنظیمات اپ، DNS server رو انتخاب کن',
          'گزینه «Custom DNS» یا «DoH» رو بزن',
          'این URL رو وارد کن ↑',
          'فعال کن',
        ];
      default: // DoU
        steps = [
          'به Wi-Fi فعلیت وصل باش',
          'روی اسم شبکه ضربدر بزن و «Modify» یا «جزئیات» رو انتخاب کن',
          'IP Settings رو از DHCP به Static تغییر بده',
          'آدرس DNS 1 رو پاک کن و IP بالا رو وارد کن ↑',
          'ذخیره کن',
        ];
    }

    return Column(
      children: steps.asMap().entries.map((e) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: Text('${e.key + 1}', style: const TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(e.value, style: const TextStyle(color: AppTheme.textPrim, fontSize: 13))),
        ]),
      )).toList(),
    );
  }

  Widget _protocolInfo(String proto) {
    String title, desc, warn;
    Color color;
    switch (proto) {
      case 'DoT':
        title = '🔒 DNS over TLS';
        desc  = 'رمزنگاری TLS — ISP نمی‌تونه query‌هات رو ببینه.';
        warn  = 'Native اندروید ≥ 9 — بهترین انتخاب';
        color = AppTheme.green;
      case 'DoH':
        title = '🌐 DNS over HTTPS';
        desc  = 'رمزنگاری HTTPS — مخفی از ISP.';
        warn  = 'نیاز به اپ جداگانه دارد';
        color = AppTheme.accent;
      default:
        title = '📶 DNS over UDP';
        desc  = 'بدون رمزنگاری — ساده‌ترین روش.';
        warn  = '⚠ ISP می‌تونه DNS query‌هات رو ببینه';
        color = AppTheme.yellow;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(desc, style: const TextStyle(color: AppTheme.textPrim, fontSize: 12)),
        const SizedBox(height: 4),
        Text(warn, style: TextStyle(color: color, fontSize: 11)),
      ]),
    );
  }
}

// ── Section Header ────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const SectionHeader({super.key, required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
    child: Row(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(
          color: AppTheme.textPrim, fontSize: 16, fontWeight: FontWeight.w700,
        )),
        if (subtitle != null)
          Text(subtitle!, style: const TextStyle(color: AppTheme.textSec, fontSize: 12)),
      ]),
      if (trailing != null) ...[const Spacer(), trailing!],
    ]),
  );
}
