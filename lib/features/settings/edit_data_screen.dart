/// One place to change any data the app uses: lines, bags, rules, air codes,
/// NSH / ICH hubs, office names, and whole sorting files.
library;

import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/widgets.dart';
import '../../data/nsh.dart';
import '../lines/lines_screen.dart';
import '../schemes/scheme_editor.dart';
import '../schemes/schemes_screen.dart';
import 'nsh_editor_screen.dart';
import 'office_fixes.dart';

class EditDataScreen extends StatelessWidget {
  const EditDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = context.services.active;
    void open(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    Widget tile(String key, IconData icon, String title, String sub, Widget? page) => Card(
      child: ListTile(
        key: ValueKey('edit_$key'),
        leading: Icon(icon, size: 34, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        subtitle: Text(sub),
        trailing: const Icon(Icons.chevron_right),
        enabled: page != null,
        onTap: page == null ? null : () => open(page),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l.editData)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 8), child: Text(l.editDataIntro)),
          if (scheme == null) WarningBanner(text: l.learnNeedsScheme),
          tile('lines', Icons.format_list_numbered, l.editLines, l.editLinesSub, const LinesScreen()),
          tile('rules', Icons.rule_folder_outlined, l.editRules, l.editRulesSub, scheme == null ? null : SchemeEditor(schemeId: scheme.scheme.id!)),
          tile('air', Icons.flight_takeoff, l.airCodes, l.editAirSub, scheme == null ? null : SchemeEditor(schemeId: scheme.scheme.id!)),
          tile('nsh', Icons.local_shipping_outlined, l.nshHubs, l.nshHubsSub, const NshEditorScreen()),
          tile('l1', Icons.alt_route, l.rmsL1Hubs, l.rmsL1HubsSub, const NshEditorScreen(kind: HubTableKind.l1)),
          tile('nph', Icons.inventory_2_outlined, l.nphHubs, l.nphHubsSub, const NshEditorScreen(kind: HubTableKind.nph)),
          tile('offices', Icons.edit_location_alt_outlined, l.officeFixes, l.officeFixesSub, const OfficeFixesScreen()),
          tile('schemes', Icons.file_open_outlined, l.editFiles, l.editFilesSub, const SchemesScreen()),
        ],
      ),
    );
  }
}
