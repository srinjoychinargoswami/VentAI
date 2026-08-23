import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_footer.dart';

class LegalPage extends StatefulWidget {
  const LegalPage({super.key});

  @override
  State<LegalPage> createState() => _LegalPageState();
}

class _LegalPageState extends State<LegalPage> {
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    // Check if navigated with tab argument
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as String?;
      if (args == 'privacy') {
        setState(() => _selectedTabIndex = 0);
      } else if (args == 'disclaimers') {
        setState(() => _selectedTabIndex = 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Privacy Policy & Disclaimers'),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Tab buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTabIndex = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _selectedTabIndex == 0
                                ? AppColors.primary
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        'Privacy Policy',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _selectedTabIndex == 0
                              ? AppColors.primary
                              : AppColors.textTertiary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTabIndex = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _selectedTabIndex == 1
                                ? AppColors.primary
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        'Disclaimers',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _selectedTabIndex == 1
                              ? AppColors.primary
                              : AppColors.textTertiary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Content (scrollable)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _selectedTabIndex == 0
                  ? _buildPrivacyPolicy()
                  : _buildDisclaimers(),
            ),
          ),
          // Footer (sticky at bottom, not scrolled)
          const AppFooter(),
        ],
      ),
    );
  }

  Widget _buildPrivacyPolicy() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('OVERVIEW'),
        _bodyText(
          'VentAI is a privacy-first emotional support companion app. We are committed to protecting your privacy. This policy explains how we handle your data.',
        ),
        const SizedBox(height: 24),
        _heading('DATA WE DO NOT COLLECT'),
        _bodyText('VentAI does NOT collect, store, or transmit any personal information about you, including:'),
        _bulletPoint('Your name, email, phone number, or location'),
        _bulletPoint('Your conversations or emotional support chats'),
        _bulletPoint('Your device information or identifiers'),
        _bulletPoint('Analytics or usage statistics'),
        _bulletPoint('Behavioral data or activity logs'),
        _bulletPoint('Any biometric or health data beyond what you voluntarily share in conversations'),
        const SizedBox(height: 24),
        _heading('ALL DATA STAYS ON YOUR DEVICE'),
        _bulletPoint('Every conversation you have with VentAI is stored ONLY on your device'),
        _bulletPoint('No data is sent to servers or cloud storage'),
        _bulletPoint('No data is shared with third parties'),
        _bulletPoint('Conversations are deleted only when you uninstall the app or manually clear app data'),
        const SizedBox(height: 24),
        _heading('HOW THE APP WORKS'),
        _bodyText('VentAI uses an offline AI model (Gemma 4 E2B) that runs entirely on your device:'),
        _bulletPoint('The AI model is downloaded once from Hugging Face (~2.6GB) on first launch'),
        _bulletPoint('After download, the app works completely offline'),
        _bulletPoint('No internet connection is required after the initial setup'),
        _bulletPoint('Your conversations never leave your device'),
        const SizedBox(height: 24),
        _heading('PERMISSIONS WE REQUEST'),
        _bodyText('VentAI requests certain permissions:'),
        _bulletPoint('INTERNET: Only used to download the AI model on first launch'),
        _bulletPoint('STORAGE: To cache the AI model locally on your device'),
        _bulletPoint('No other data is transmitted'),
        const SizedBox(height: 24),
        _heading('THIRD-PARTY SERVICES'),
        _bulletPoint('HuggingFace: Used only for downloading the AI model on first launch. No personal data is shared.'),
        _bulletPoint('No analytics, crash reporting, or tracking services are used'),
        _bulletPoint('No advertisements or ad networks'),
        const SizedBox(height: 24),
        _heading('YOUR RIGHTS'),
        _bulletPoint('You have full control over your data'),
        _bulletPoint('You can delete all app data by uninstalling or clearing app data in settings'),
        _bulletPoint('You are not required to provide any personal information to use VentAI'),
        _bulletPoint('Your privacy is respected at all times'),
        const SizedBox(height: 24),
        _heading('CHANGES TO THIS POLICY'),
        _bodyText('We may update this privacy policy occasionally. Any changes will be reflected here with an updated date.'),
        const SizedBox(height: 24),
        _heading('CONTACT US'),
        _bodyText('If you have privacy questions or concerns, please contact: resolveera@gmail.com'),
        const SizedBox(height: 24),
        _heading('COMMITMENT'),
        _bodyText(
          'VentAI is designed with privacy as the foundation. We believe emotional support should be private, secure, and personal. Your data belongs to you, not to us.',
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildDisclaimers() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('IMPORTANT LEGAL DISCLAIMER'),
        _bodyText('VentAI is NOT:'),
        _bulletPoint('A medical device'),
        _bulletPoint('A substitute for professional mental health care'),
        _bulletPoint('Therapy, counseling, or medical advice'),
        _bulletPoint('A crisis intervention service'),
        const SizedBox(height: 24),
        _heading('LIMITATION OF LIABILITY'),
        _bodyText('VentAI and its creators are NOT responsible for:'),
        _bulletPoint('Any actions, decisions, or harm resulting from use of this app'),
        _bulletPoint('Self-harm, injury, or any consequences of user actions'),
        _bulletPoint('Failure to seek professional help'),
        _bulletPoint('Misuse or misinterpretation of app responses'),
        _bulletPoint('Technical failures or service interruptions'),
        _bulletPoint('Any damages, direct or indirect, arising from app use'),
        const SizedBox(height: 24),
        _heading('YOU ASSUME ALL RISK'),
        _bodyText(
          'By using VentAI, you accept full responsibility for any outcomes of your actions. VentAI provides no guarantees about emotional outcomes or safety.',
        ),
        const SizedBox(height: 24),
        _heading('IF YOU ARE IN CRISIS'),
        _bodyText('Do NOT rely on this app. Immediately:'),
        _bulletPoint('Call 911 (US emergency)'),
        _bulletPoint('Call 988 (Suicide & Crisis Lifeline, US)'),
        _bulletPoint('Text HOME to 741741 (Crisis Text Line)'),
        _bulletPoint('Contact emergency services in your country'),
        _bulletPoint('Tell a trusted adult or healthcare provider'),
        const SizedBox(height: 24),
        _heading('PARENTAL RESPONSIBILITY'),
        _bodyText(
          'If you are under 18, your parent/guardian is responsible for your use of this app. This app is NOT suitable for unsupervised minor use.',
        ),
        const SizedBox(height: 24),
        _heading('NO MEDICAL RELATIONSHIP'),
        _bodyText(
          'Using VentAI does NOT create a doctor-patient relationship. You are not receiving medical, psychiatric, or therapeutic treatment.',
        ),
        const SizedBox(height: 24),
        _heading('USE AT YOUR OWN RISK'),
        _bodyText(
          'The creators of VentAI assume NO liability for any harm, injury, or consequences resulting from app use.',
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  // Text helpers - Left-aligned with 18px font
  Widget _heading(String text) {
    return Text(
      text,
      textAlign: TextAlign.left,
      style: const TextStyle(
        color: AppColors.primary,
        fontSize: 16,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _bodyText(String text) {
    return Text(
      text,
      textAlign: TextAlign.left,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 18,
        height: 1.7,
      ),
    );
  }

  Widget _bulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 18,
            ),
          ),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.left,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 18,
                height: 1.7,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
