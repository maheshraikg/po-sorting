/// Share & backup: send all of this phone's data as one Excel file, save it
/// (phone or Google Drive), or import a file another user sent.
library;

import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/files.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'export_all.dart';
import 'import_shared.dart';

class ShareDataScreen extends StatelessWidget {
  const ShareDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final messenger = ScaffoldMessenger.of(context);

    Future<void> share() async {
      final now = DateTime.now();
      final bytes = await buildSharePack(context.services, context.settings, now: now);
      await shareFiles({sharePackName(now): bytes}, text: l.shareDataText);
    }

    Future<void> save() async {
      final now = DateTime.now();
      final bytes = await buildSharePack(context.services, context.settings, now: now);
      if (await saveBytes(sharePackName(now), bytes)) messenger.showSnackBar(SnackBar(content: Text(l.shareSaved)));
    }

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
