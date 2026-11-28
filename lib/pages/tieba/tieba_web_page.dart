import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/cap_icon.dart';
import '../../widgets/cap_page.dart';
import '../../widgets/cap_toast.dart';
import '../../widgets/cap_webview.dart';
import '../../services/cap_system.dart';

/// In-app browser for Tieba video pages / profile pages / plain links.
/// Keeps the user inside CapuLife instead of jumping to the system browser.
class TiebaWebPage extends StatefulWidget {
  const TiebaWebPage({
    super.key,
    required this.url,
    this.title = '贴吧网页',
    this.userAgent = '',
  });

  final String url;
  final String title;
  final String userAgent;

  @override
  State<TiebaWebPage> createState() => _TiebaWebPageState();
}

class _TiebaWebPageState extends State<TiebaWebPage> {
  final GlobalKey<CapWebViewState> _webKey = GlobalKey<CapWebViewState>();
  late String _title = widget.title;
  int _progress = 0;

  @override
  Widget build(BuildContext context) {
    return CapPage(
      child: Column(
        children: [
          CapAppHeader(
            title: _title,
            subtitle: 'CapuLife 内打开',
            back: true,
            right: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _action(
                  'refresh-cw',
                  () {
                    setState(() => _progress = 0);
                    _webKey.currentState?.reload();
                  },
                ),
                SizedBox(width: capRpx(context, 4)),
                _action('external-link', () {
                  CapSystem.openUrl(widget.url);
                  showCapToast(context, '已在系统浏览器打开');
                }),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.white,
              child: CapWebView(
                key: _webKey,
                url: widget.url,
                userAgent: widget.userAgent,
                onProgress: (value) {
                  if (mounted) setState(() => _progress = value);
                },
                onTitle: (title) {
                  final clean = title.trim();
                  if (clean.isNotEmpty && mounted) {
                    setState(() => _title = clean);
                  }
                },
              ),
            ),
          ),
          if (_progress > 0 && _progress < 100)
            LinearProgressIndicator(
              value: _progress / 100,
              minHeight: 2,
              backgroundColor: AppColors.surfaceSoft,
              color: AppColors.accent,
            ),
        ],
      ),
    );
  }

  Widget _action(String icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: capRpx(context, 58),
        height: capRpx(context, 58),
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.line, width: 0.8),
        ),
        child: Center(
          child: CapIcon(
            icon,
            size: capRpx(context, 25),
            color: AppColors.ink,
          ),
        ),
      ),
    );
  }
}