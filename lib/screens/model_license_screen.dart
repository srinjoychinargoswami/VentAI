import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_footer.dart';

class ModelLicenseScreen extends StatelessWidget {
  const ModelLicenseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Model License & Terms'),
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _sectionTitle('📜 MODEL LICENSE'),
                  _bodyText(
                    'VentAI uses Gemma 4 E2B, an open-source AI model. This model is licensed under the Gemma Terms of Use.',
                  ),
                  const SizedBox(height: 32),
                  _sectionTitle('🔒 PRIVACY POLICY'),
                  _bodyText(
                    'VentAI is a privacy-first emotional support companion app. We are committed to protecting your privacy.',
                  ),
                  const SizedBox(height: 16),
                  _heading('DATA WE DO NOT COLLECT'),
                  _bulletPoint('Your name, email, phone number, or location'),
                  _bulletPoint('Your conversations or emotional support chats'),
                  _bulletPoint('Your device information or identifiers'),
                  _bulletPoint('Analytics or usage statistics'),
                  _bulletPoint('Behavioral data or activity logs'),
                  const SizedBox(height: 16),
                  _heading('ALL DATA STAYS ON YOUR DEVICE'),
                  _bulletPoint('Every conversation is stored ONLY on your device'),
                  _bulletPoint('No data is sent to servers or cloud storage'),
                  _bulletPoint('No data is shared with third parties'),
                  _bulletPoint('Deleted when you uninstall or clear app data'),
                  const SizedBox(height: 32),
                  _sectionTitle('⚖️ IMPORTANT LEGAL DISCLAIMER'),
                  _bodyText('VentAI is NOT:'),
                  _bulletPoint('A medical device'),
                  _bulletPoint('A substitute for professional mental health care'),
                  _bulletPoint('Therapy, counseling, or medical advice'),
                  _bulletPoint('A crisis intervention service'),
                  const SizedBox(height: 16),
                  _heading('YOU ASSUME ALL RISK'),
                  _bodyText(
                    'By using VentAI, you accept full responsibility for any outcomes. VentAI provides no guarantees about emotional outcomes or safety.',
                  ),
                  const SizedBox(height: 16),
                  _heading('IF YOU ARE IN CRISIS'),
                  _bodyText('Do NOT rely on this app. Immediately:'),
                  _bulletPoint('Call 911 (US emergency)'),
                  _bulletPoint('Call 988 (Suicide & Crisis Lifeline, US)'),
                  _bulletPoint('Text HOME to 741741 (Crisis Text Line)'),
                  _bulletPoint('Contact emergency services in your country'),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          // Accept button (sticky at bottom)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: AppColors.borderGray,
                  width: 1,
                ),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/chat');
                },
                child: const Text(
                  'Accept & Continue',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          // Footer
          const AppFooter(),
        ],
      ),
    );
  }

  static Widget _sectionTitle(String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: AppColors.primary,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }

  static Widget _heading(String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: AppColors.primary,
        fontSize: 16,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }

  static Widget _bodyText(String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 14,
        height: 1.7,
      ),
    );
  }

  static Widget _bulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '• ',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.7,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
