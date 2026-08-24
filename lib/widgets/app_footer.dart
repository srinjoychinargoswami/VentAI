import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';

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
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Disclaimer section
          const Text(
            'Vent AI is not a substitute for professional mental health care.\n100% on-device • Fully private • No data stored',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),

          // Copyright section
          const Text(
            '© 2024-2026 Srinjoy Goswami & Resolveera\nLicensed under GNU Affero General Public License v3.0',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),

          // Links section
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              // Privacy Policy link
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pushNamed('/legal', arguments: 'privacy');
                },
                child: const Text(
                  'Privacy Policy',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),

              const Text(
                '•',
                style: TextStyle(color: AppColors.textTertiary),
              ),

              // Disclaimers link
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pushNamed('/legal', arguments: 'disclaimers');
                },
                child: const Text(
                  'Disclaimers',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),

              const Text(
                '•',
                style: TextStyle(color: AppColors.textTertiary),
              ),

              // AGPL link (external)
              GestureDetector(
                onTap: () => _openUrl('https://www.gnu.org/licenses/agpl-3.0.en.html'),
                child: const Text(
                  'AGPL v3.0',
                  style: TextStyle(
                    fontSize: 12,
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
