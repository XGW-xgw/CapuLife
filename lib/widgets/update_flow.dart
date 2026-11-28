import 'package:flutter/material.dart';

import '../services/update_installer.dart';
import '../services/update_service.dart';
import '../theme.dart';
import 'cap_icon.dart';
import 'cap_toast.dart';

/// Download + install flow used by both the startup prompt and settings.
Future<void> startLocalUpdate(BuildContext context, ReleaseInfo release) async {
  final canInstall = await UpdateInstaller.canInstall();
  if (!context.mounted) return;
  if (!canInstall) {
    await _askInstallPermission(context, beforeDownload: true);
    return;
  }
  final progress = ValueNotifier<double?>(null);
  final size = ValueNotifier<int>(0);
  var dialogOpen = true;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UpdateProgressDialog(
      release: release,
      progress: progress,
      received: size,
    ),
  ).then((_) => dialogOpen = false);
  await Future<void>.delayed(const Duration(milliseconds: 80));
  String? path;
  Object? error;
  try {
    path = await UpdateInstaller.download(
      release,
      onProgress: (ratio, received, total) {
        progress.value = total > 0 ? ratio : null;
        size.value = received;
      },
    );
  } catch (e) {
    error = e;
  }
  if (dialogOpen && context.mounted) {
    Navigator.of(context, rootNavigator: true).pop();
  }
  if (!context.mounted) return;
  if (error != null || path == null) {
    showCapToast(
      context,
      error is StateError ? error.message : '更新下载失败，请稍后重试',
    );
    return;
  }
  await installLocalApk(context, path);
}

Future<void> pickAndInstallLocalApk(BuildContext context) async {
  final path = await UpdateInstaller.pickApk();
  if (!context.mounted) return;
  if (path == null || path.isEmpty) return;
  await installLocalApk(context, path);
}

Future<void> installLocalApk(BuildContext context, String path) async {
  final result = await UpdateInstaller.installApk(path);
  if (!context.mounted) return;
  if (result.needPermission) {
    await _askInstallPermission(context, beforeDownload: false);
    return;
  }
  if (!result.ok) {
    showCapToast(context, '没有调起安装程序，请检查 APK 是否完整');
    return;
  }
  showCapToast(context, '已调起系统安装程序');
}

Future<void> _askInstallPermission(
  BuildContext context, {
  required bool beforeDownload,
}) async {
  final go = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(capRpx(context, 28)),
      ),
      title: Text(
        '需要安装权限',
        style: TextStyle(
          fontSize: capRpx(context, 29),
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
        ),
      ),
      content: Text(
        beforeDownload
            ? '请先允许 CapuLife 安装未知来源应用，回来后再点一次「立即本地更新」。'
            : '请允许 CapuLife 安装未知来源应用，再回到这里点一次「本地更新」。APK 已经下载在本机，不会重复下载。',
        style: TextStyle(
          fontSize: capRpx(context, 21),
          height: 1.6,
          color: AppColors.muted,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('稍后', style: TextStyle(color: AppColors.muted)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('去设置', style: TextStyle(color: AppColors.accent)),
        ),
      ],
    ),
  );
  if (go == true) {
    await UpdateInstaller.openInstallSettings();
  }
}

class _UpdateProgressDialog extends StatelessWidget {
  const _UpdateProgressDialog({
    required this.release,
    required this.progress,
    required this.received,
  });

  final ReleaseInfo release;
  final ValueNotifier<double?> progress;
  final ValueNotifier<int> received;

  String _mb(int bytes) => (bytes / 1024 / 1024).toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(capRpx(context, 28)),
      ),
      title: Row(
        children: [
          Container(
            width: capRpx(context, 46),
            height: capRpx(context, 46),
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(capRpx(context, 14)),
            ),
            child: Center(
              child: CapIcon(
                'download',
                size: capRpx(context, 24),
                color: AppColors.accent,
              ),
            ),
          ),
          SizedBox(width: capRpx(context, 10)),
          Expanded(
            child: Text(
              '正在下载 v${release.version}',
              style: TextStyle(
                fontSize: capRpx(context, 27),
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
      content: ValueListenableBuilder<double?>(
        valueListenable: progress,
        builder: (context, value, child) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: value,
                minHeight: capRpx(context, 8),
                backgroundColor: AppColors.surfaceSoft,
                color: AppColors.accent,
              ),
            ),
            SizedBox(height: capRpx(context, 10)),
            ValueListenableBuilder<int>(
              valueListenable: received,
              builder: (context, bytes, child) => Text(
                value == null
                    ? '正在连接更新服务器…'
                    : '${(value * 100).round()}% · 已下载 ${_mb(bytes)} MB',
                style: TextStyle(
                  fontSize: capRpx(context, 19),
                  color: AppColors.muted,
                ),
              ),
            ),
            SizedBox(height: capRpx(context, 6)),
            Text(
              '下载完成后会调起系统安装程序，请按系统提示完成更新。',
              style: TextStyle(
                fontSize: capRpx(context, 17),
                height: 1.5,
                color: AppColors.mutedSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}