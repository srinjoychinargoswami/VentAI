import 'package:flutter_test/flutter_test.dart';
import 'package:vent_ai/legal/app_licence.dart';

void main() {
  group('licenceFor', () {
    test('Apple platforms (iOS, macOS) get Apache 2.0', () {
      expect(licenceFor(isWeb: false, isApplePlatform: true), AppLicence.apache2);
    });

    test('Android, Windows, Linux get AGPL v3.0', () {
      expect(licenceFor(isWeb: false, isApplePlatform: false), AppLicence.agplV3);
    });

    test('web gets AGPL v3.0', () {
      expect(licenceFor(isWeb: true, isApplePlatform: false), AppLicence.agplV3);
    });
  });

  group('footerLine', () {
    test('apache2 names Apache 2.0, not GNU Affero', () {
      final line = AppLicence.apache2.footerLine;
      expect(line, contains('Apache License 2.0'));
      expect(line, isNot(contains('GNU Affero')));
    });

    test('agplV3 names GNU Affero v3.0, not Apache', () {
      final line = AppLicence.agplV3.footerLine;
      expect(line, contains('GNU Affero General Public License v3.0'));
      expect(line, isNot(contains('Apache')));
    });
  });
}
