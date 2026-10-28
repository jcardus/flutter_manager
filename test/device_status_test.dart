import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manager/l10n/app_localizations.dart';
import 'package:manager/utils/device_status.dart';

void main() {
  test('status chips follow the app language', () async {
    final es = await AppLocalizations.delegate.load(const Locale('es'));
    expect(deviceStatusLabel(es, 'online'), 'EN LÍNEA');
    expect(deviceStatusLabel(es, 'offline'), 'FUERA DE LÍNEA');
    expect(deviceStatusLabel(es, null), 'DESCONOCIDO');

    final en = await AppLocalizations.delegate.load(const Locale('en'));
    expect(deviceStatusLabel(en, 'online'), 'ONLINE');
  });
}
