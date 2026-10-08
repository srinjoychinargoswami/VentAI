import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';
import '../utils/platform_utils.dart';

class AppFooter extends StatelessWidget {
  const AppFooter({super.key});


  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final verticalPadding = isMobilePhone(context) ? 4.0 : 8.0;
    final disclaimerFontSize = isMobilePhone(context) ? 8.0 : 9.0;
    final disclaimerHeight = isMobilePhone(context) ? 1.1 : 1.3;
    final copyrightHeight = isMobilePhone(context) ? 1.0 : 1.2;
    final linksFontSize = isMobilePhone(context) ? 8.0 : 9.0;
    final gapHeight = isMobilePhone(context) ? 3.0 : 6.0;
    final midGapHeight = isMobilePhone(context) ? 2.0 : 6.0;

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
            spacing: isMobilePhone(context) ? 4 : 8,
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

              // Licenses link (in-app, platform-aware)
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pushNamed('/licenses');
                },
                child: Text(
                  'Licenses',
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
