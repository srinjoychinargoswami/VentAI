import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';

class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final verticalPadding = _isMobile ? 8.0 : 16.0;
    final disclaimerFontSize = _isMobile ? 10.0 : 12.0;
    final disclaimerHeight = _isMobile ? 1.2 : 1.5;
    final copyrightHeight = _isMobile ? 1.1 : 1.4;
    final linksFontSize = _isMobile ? 10.0 : 12.0;
    final gapHeight = _isMobile ? 6.0 : 12.0;
    final midGapHeight = _isMobile ? 4.0 : 16.0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(
            color: Color(0xFF94A3B8).withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      padding: EdgeInsets.symmetric(vertical: verticalPadding, horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Disclaimer section
          Text(
            'Vent AI is not a substitute for professional mental health care.\n100% on-device • Fully private • No data stored',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: disclaimerFontSize,
              color: AppColors.textTertiary,
              height: disclaimerHeight,
            ),
          ),
          SizedBox(height: midGapHeight),

          // Copyright section
          Text(
            '© 2024-2026 Srinjoy Goswami & Resolveera\nLicensed under GNU Affero General Public License v3.0',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: disclaimerFontSize,
              color: AppColors.textTertiary,
              height: copyrightHeight,
            ),
          ),
          SizedBox(height: gapHeight),

          // Links section
          Wrap(
            alignment: WrapAlignment.center,
            spacing: _isMobile ? 4 : 8,
            children: [
              // Privacy Policy link
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pushNamed('/legal', arguments: 'privacy');
                },
                child: Text(
                  'Privacy Policy',
                  style: TextStyle(
                    fontSize: linksFontSize,
                    color: AppColors.primary,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),

              Text(
                '•',
                style: TextStyle(color: AppColors.textTertiary, fontSize: linksFontSize),
              ),

              // Disclaimers link
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pushNamed('/legal', arguments: 'disclaimers');
                },
                child: Text(
                  'Disclaimers',
                  style: TextStyle(
                    fontSize: linksFontSize,
                    color: AppColors.primary,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),

              Text(
                '•',
                style: TextStyle(color: AppColors.textTertiary, fontSize: linksFontSize),
              ),

              // AGPL link (external)
              GestureDetector(
                onTap: () => _openUrl('https://www.gnu.org/licenses/agpl-3.0.en.html'),
                child: Text(
                  'AGPL v3.0',
                  style: TextStyle(
                    fontSize: linksFontSize,
                    color: AppColors.primary,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
