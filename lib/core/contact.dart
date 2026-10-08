/// Opening the dialer, WhatsApp and e-mail, and sharing the app. The app
/// itself needs no phone or internet permission: Android opens the other app.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'constants.dart';
import 'files.dart';
import 'l10n/app_localizations.dart';

const String kPlayStoreUrl = 'https://play.google.com/store/apps/details?id=com.posorting.app';

/// The developer: corrections, new sorting data and app updates.
const String kDeveloperName = 'Mahesh Rai';
const String kDeveloperPhone = '8105693721';
const String kDeveloperEmail = 'maheshraikg@gmail.com';

const _channel = MethodChannel('po_sorting/contact');

Future<void> _open(BuildContext context, String method, Map<String, String> args) async {
  final messenger = ScaffoldMessenger.of(context);
  final l = AppLocalizations.of(context);
  bool ok;
  try {
    ok = await _channel.invokeMethod<bool>(method, args) ?? false;
  } on MissingPluginException {
    ok = false;
  } on PlatformException {
    ok = false;
  }
  if (!ok) messenger.showSnackBar(SnackBar(content: Text(l.cannotOpenApp)));
}

/// Opens the dialer with [phone] (10 digits) filled in.
Future<void> dial(BuildContext context, String phone) => _open(context, 'dial', {'number': phone});

/// Opens a WhatsApp chat with [phone] (10-digit Indian number).
Future<void> whatsApp(BuildContext context, String phone, {String text = ''}) =>
    _open(context, 'whatsapp', {'number': '91$phone', 'text': text});

/// Opens the e-mail app with a new message.
Future<void> email(BuildContext context, String to, {String subject = '', String body = ''}) =>
    _open(context, 'email', {'to': to, 'subject': subject, 'body': body});

Future<void> shareApp(AppLocalizations l) => shareText(l.shareAppText(kPlayStoreUrl), subject: kAppNameEn);

/// "81056 93721".
String spacedPhone(String n) => n.length == 10 ? '${n.substring(0, 5)} ${n.substring(5)}' : n;
