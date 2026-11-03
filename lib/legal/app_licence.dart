import 'dart:io';

import 'package:flutter/foundation.dart';

/// The licence the app itself is shown under. Single source for the footer
/// line and the Licences page tab.
enum AppLicence { apache2, agplV3 }

/// Pure decision, testable without a device: Apple platforms get Apache 2.0,
/// everything else (Android, Windows, Linux, web) gets AGPL v3.0.
AppLicence licenceFor({required bool isWeb, required bool isApplePlatform}) {
  if (isWeb) return AppLicence.agplV3;
  return isApplePlatform ? AppLicence.apache2 : AppLicence.agplV3;
}

/// Licence for the running app. kIsWeb is checked first because Platform
/// throws on web.
AppLicence currentAppLicence() => licenceFor(
      isWeb: kIsWeb,
      isApplePlatform: !kIsWeb && (Platform.isIOS || Platform.isMacOS),
    );

extension AppLicenceText on AppLicence {
  String get footerLine {
    switch (this) {
      case AppLicence.apache2:
        return 'Licensed under Apache License 2.0';
      case AppLicence.agplV3:
        return 'Licensed under GNU Affero General Public License v3.0';
    }
  }

  String get tabLabel {
    switch (this) {
      case AppLicence.apache2:
        return 'Apache 2.0';
      case AppLicence.agplV3:
        return 'AGPL v3.0';
    }
  }
}
