/// People who made the app and the sources it builds on.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants.dart';
import '../../core/l10n/app_localizations.dart';

/// Contributors. Edit here to add people.
const kDeveloper = 'Mahesh Rai';

/// Developer's contact number (shown in the app, so it is public).
const kDeveloperPhone = '8105693721';
const kDataContributors = ['Ganesh Sir', 'Ranjith'];

const _contact = MethodChannel('po_sorting/contact');

class ContributorsScreen extends StatelessWidget {
  const ContributorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    Widget person(String name, String role, IconData icon, {Key? key}) => Card(
      key: key,
      child: ListTile(
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: cs.primaryContainer,
          foregroundColor: cs.onPrimaryContainer,
          child: Text(name.characters.first, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19)),
        subtitle: Row(children: [Icon(icon, size: 16, color: cs.primary), const SizedBox(width: 6), Expanded(child: Text(role))]),
      ),
    );
    Widget heading(String s) => Padding(padding: const EdgeInsets.fromLTRB(4, 16, 4, 6), child: Text(s, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)));
    return Scaffold(
      appBar: AppBar(title: Text(l.contributors)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Icon(Icons.groups_outlined, size: 64, color: cs.primary),
          Text(kAppNameEn, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w900), textAlign: TextAlign.center),
          Text(l.contributorsIntro, textAlign: TextAlign.center, style: t.bodyMedium),
          heading(l.developedBy),
          person(kDeveloper, l.roleDeveloper, Icons.code, key: const ValueKey('contributor_developer')),
          Card(
            key: const ValueKey('contact_card'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.contactDeveloper, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.phone, color: cs.primary),
                    const SizedBox(width: 8),
                    SelectableText(_spaced(kDeveloperPhone), style: t.titleLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ]),
                  Text(l.contactDeveloperHint, style: t.bodySmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        key: const ValueKey('contact_call'),
                        onPressed: () => _open(context, 'dial', kDeveloperPhone),
                        icon: const Icon(Icons.call),
                        label: Text(l.call),
                      ),
                      FilledButton.tonalIcon(
                        key: const ValueKey('contact_whatsapp'),
                        onPressed: () => _open(context, 'whatsapp', '91$kDeveloperPhone'),
                        icon: const Icon(Icons.chat_outlined),
                        label: const Text('WhatsApp'),
                      ),
                      OutlinedButton.icon(
                        key: const ValueKey('contact_copy'),
                        onPressed: () {
                          Clipboard.setData(const ClipboardData(text: kDeveloperPhone));
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.copied)));
                        },
                        icon: const Icon(Icons.copy),
                        label: Text(l.copy),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          heading(l.dataProvidedBy),
          for (final n in kDataContributors) person(n, l.roleData, Icons.local_shipping_outlined, key: ValueKey('contributor_$n')),
          heading(l.creditsTitle),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(l.creditsText))),
          const SizedBox(height: 12),
          Text(l.contributorsThanks, textAlign: TextAlign.center, style: t.titleSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

String _spaced(String n) => n.length == 10 ? '${n.substring(0, 5)} ${n.substring(5)}' : n;

Future<void> _open(BuildContext context, String method, String number) async {
  final messenger = ScaffoldMessenger.of(context);
  final l = AppLocalizations.of(context);
  bool ok;
  try {
    ok = await _contact.invokeMethod<bool>(method, {'number': number}) ?? false;
  } on MissingPluginException {
    ok = false;
  } on PlatformException {
    ok = false;
  }
  if (!ok) messenger.showSnackBar(SnackBar(content: Text(l.cannotOpenApp)));
}
