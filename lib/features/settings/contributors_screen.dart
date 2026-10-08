/// People who made the app, how to reach the developer, and sharing the app.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants.dart';
import '../../core/contact.dart';
import '../../core/l10n/app_localizations.dart';

class Contributor {
  const Contributor(this.name, this.role, this.icon, {this.phone});

  final String name;
  final String Function(AppLocalizations l) role;
  final IconData icon;

  /// Shown in the app (public). Null = no contact buttons.
  final String? phone;
}

/// Edit here to add people.
final kContributors = <Contributor>[
  Contributor(kDeveloperName, (l) => l.roleDeveloper, Icons.code, phone: kDeveloperPhone),
  Contributor('Ranjith', (l) => l.roleIdeaData, Icons.lightbulb_outline, phone: '8296551488'),
  Contributor('Ganesh Gowda', (l) => l.rolePinData, Icons.pin_drop_outlined, phone: '9731243939'),
];

class ContributorsScreen extends StatelessWidget {
  const ContributorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    Widget heading(String s) => Padding(padding: const EdgeInsets.fromLTRB(4, 16, 4, 6), child: Text(s, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)));
    Widget person(Contributor c) => Card(
      key: ValueKey('contributor_${c.name}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
        child: Column(
          children: [
            ListTile(
              leading: CircleAvatar(
                radius: 26,
                backgroundColor: cs.primaryContainer,
                foregroundColor: cs.onPrimaryContainer,
                child: Text(c.name.characters.first, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              ),
              title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19)),
              subtitle: Row(children: [Icon(c.icon, size: 16, color: cs.primary), const SizedBox(width: 6), Expanded(child: Text(c.role(l)))]),
            ),
            if (c.phone != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(Icons.phone, size: 18, color: cs.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Expanded(child: SelectableText(spacedPhone(c.phone!), style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 1))),
                    IconButton.filledTonal(key: ValueKey('call_${c.name}'), tooltip: l.call, onPressed: () => dial(context, c.phone!), icon: const Icon(Icons.call)),
                    IconButton.filledTonal(key: ValueKey('wa_${c.name}'), tooltip: 'WhatsApp', onPressed: () => whatsApp(context, c.phone!), icon: const Icon(Icons.chat_outlined)),
                    IconButton(
                      tooltip: l.copy,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: c.phone!));
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.copied)));
                      },
                      icon: const Icon(Icons.copy),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l.contributors)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Icon(Icons.groups_outlined, size: 64, color: cs.primary),
          Text(kAppNameEn, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w900), textAlign: TextAlign.center),
          Text(l.contributorsIntro, textAlign: TextAlign.center, style: t.bodyMedium),
          heading(l.contributorsTeam),
          for (final c in kContributors) person(c),
          heading(l.contactDeveloper),
          const UpdatesCard(),
          heading(l.shareApp),
          const ShareAppCard(),
          heading(l.creditsTitle),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(l.creditsText))),
          const SizedBox(height: 12),
          Text(l.contributorsThanks, textAlign: TextAlign.center, style: t.titleSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Send a correction or an update to the developer (WhatsApp / e-mail).
class UpdatesCard extends StatelessWidget {
  const UpdatesCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final message = l.updateMessage(kAppVersion);
    return Card(
      key: const ValueKey('updates_card'),
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.contactDeveloperHint, style: t.bodyMedium),
            const SizedBox(height: 8),
            Text('$kDeveloperName · ${spacedPhone(kDeveloperPhone)}', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            SelectableText(kDeveloperEmail, style: t.bodyMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: const ValueKey('updates_whatsapp'),
                  onPressed: () => whatsApp(context, kDeveloperPhone, text: message),
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('WhatsApp'),
                ),
                FilledButton.tonalIcon(
                  key: const ValueKey('updates_email'),
                  onPressed: () => email(context, kDeveloperEmail, subject: '$kAppNameEn $kAppVersion – ${l.updateSubject}', body: message),
                  icon: const Icon(Icons.email_outlined),
                  label: Text(l.emailLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ShareAppCard extends StatelessWidget {
  const ShareAppCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Card(
      child: ListTile(
        key: const ValueKey('share_app'),
        leading: Icon(Icons.share, size: 32, color: Theme.of(context).colorScheme.primary),
        title: Text(l.shareApp, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(l.shareAppSub),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => shareApp(l),
      ),
    );
  }
}
