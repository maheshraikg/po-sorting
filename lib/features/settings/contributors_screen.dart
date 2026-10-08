/// People who made the app and the sources it builds on.
library;

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/l10n/app_localizations.dart';

/// Contributors: (name, role) per group. Edit here to add people.
const kDeveloper = 'KAVYA';
const kDataContributors = ['Ganesh Sir', 'Ranjith'];

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
