import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Width at which layouts switch from phone to tablet sizing. iPads in
/// Split View / Slide Over can be narrower than this and get phone sizing.
const double kTabletBreakpoint = 600;

/// LAYOUT: true when the available window is phone-sized. Use for sizes,
/// padding and fonts. Based on width, not OS, so an iPad gets tablet sizing.
bool isMobilePhone(BuildContext context) =>
    MediaQuery.sizeOf(context).width < kTabletBreakpoint;

/// LAYOUT: true when the available window is tablet-sized or larger.
bool isTablet(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kTabletBreakpoint;

/// BEHAVIOR: running on a desktop OS (no BuildContext needed).
bool isDesktop() =>
    !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

/// BEHAVIOR: running on a touch OS (Android or iOS/iPadOS), including iPad.
/// Use for input handling (tap vs long-press, keyboard) and logging/labels,
/// not for sizing.
bool isMobileOS() => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
