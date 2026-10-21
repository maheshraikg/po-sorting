/// Share & backup: send all of this phone's data as one Excel file, save it
/// (phone or Google Drive), or import a file another user sent.
library;

import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/files.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'export_all.dart';
import 'import_shared.dart';

/// Builds the share pack with a "Preparing…" dialog, then runs [then]
/// (share sheet / save screen). Errors are shown, not swallowed.
Future<void> runShareAction(BuildContext context, Future<void> Function(Uint8List bytes, String name) then) async {
  final l = AppLocalizations.of(context);
  final services = context.services;
  final settings = context.settings;
  final nav = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        key: const ValueKey('share_preparing'),
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(child: Text(l.sharePreparing)),
          ],
        ),
      ),
    ),
  );
  Object? error;
  Uint8List? bytes;
  final now = DateTime.now();
  try {
    bytes = await buildSharePack(services, settings, now: now);
  } catch (e) {
    error = e;
  }
  nav.pop();
  if (error == null) {
    try {
      await then(bytes!, sharePackName(now));
    } catch (e) {
      error = e;
    }
  }
  if (error != null && context.mounted) {
    await showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l.shareFailed),
        content: Text('$error'),
        actions: [FilledButton(onPressed: () => Navigator.pop(d), child: Text(l.ok))],
      ),
    );
  }
}

class ShareDataScreen extends StatelessWidget {
  const ShareDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final messenger = ScaffoldMessenger.of(context);

    Future<void> share() => runShareAction(context, (bytes, name) => shareFiles({name: bytes}, text: l.shareDataText));

    Future<void> save() => runShareAction(context, (bytes, name) async {
      bool saved;
      try {
        saved = await saveBytes(name, bytes);
      } catch (_) {
        // No file screen on this phone: send it instead (Drive / Files are
        // in the share list too).
        await shareFiles({name: bytes}, text: l.shareDataText);
        return;
      }
      if (saved) messenger.showSnackBar(SnackBar(content: Text(l.shareSaved)));
    });

    Widget action(String key, IconData icon, Color colour, String title, String sub, VoidCallback onTap) => Card(
      child: ListTile(
        key: ValueKey('share_data_$key'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: IconBadge(icon, colour, size: 46),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        subtitle: Text(sub),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l.shareData)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 8), child: Text(l.shareDataIntro)),
          action('send', Icons.send_outlined, kPostGreen, l.shareDataSend, l.shareDataSendSub, share),
          action('save', Icons.save_alt, kAccentCycle[1 % kAccentCycle.length], l.shareDataSave, l.shareDataSaveSub, save),
          action(
            'import',
            Icons.download_for_offline_outlined,
            kAccentCycle[2 % kAccentCycle.length],
            l.shareImport,
            l.shareImportSub,
            () => importSharedData(context),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.shareDataHow, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  for (final (i, s) in [l.shareStep1, l.shareStep2, l.shareStep3, l.shareStep4].indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 12,
                            child: Text('${i + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(s)),
                        ],
                      ),
                    ),
                  const Divider(),
                  Text(l.shareSheetsTitle, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(l.shareSheetsHint),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
