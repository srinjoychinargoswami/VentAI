import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../widgets/app_footer.dart';
import '../providers/setup_state_provider.dart';

class ModelLicenseScreen extends StatefulWidget {
  const ModelLicenseScreen({super.key});

  @override
  State<ModelLicenseScreen> createState() => _ModelLicenseScreenState();
}

class _ModelLicenseScreenState extends State<ModelLicenseScreen> {
  bool _licenseAccepted = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    debugPrint('📜 [LICENSE-SCREEN] License screen initiated');
    // Show license screen immediately when opened
    setState(() => _isLoading = false);
  }

  Future<void> _handleAccept() async {
    if (!_licenseAccepted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('ventai_license_accepted', true);
      await prefs.setString('ventai_license_date', DateTime.now().toIso8601String());

      if (mounted) {
        // Notify setup provider that license was accepted
        final setupProvider = Provider.of<SetupStateProvider>(context, listen: false);
        await setupProvider.markLicenseAccepted();

        // Close this screen - let setup flow continue
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Error saving license acceptance: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error saving acceptance. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleDecline() async {
    // Close the app or return to startup
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('📜 [LICENSE-SCREEN] Building license screen (isLoading: $_isLoading)');

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    debugPrint('📜 [LICENSE-SCREEN] Rendering license content');
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.background,
              border: Border(
                bottom: BorderSide(
                  color: Color(0xFF94A3B8).withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Terms of Service & Agreements',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                // Close button
                GestureDetector(
                  onTap: _handleDecline,
                  child: Text(
                    '×',
                    style: TextStyle(
                      fontSize: 32,
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLicenseSection(),
                  const SizedBox(height: 24),
                  _buildPrivacySection(),
                  const SizedBox(height: 24),
                  _buildDisclaimersSection(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // HuggingFace License Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: GestureDetector(
              onTap: () async {
                final url = Uri.parse('https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary, width: 1),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.transparent,
                ),
                child: const Text(
                  '🔗 View Full Gemma License on HuggingFace',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),

          // Checkbox + Buttons section
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Color(0xFF94A3B8).withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Checkbox with label
                GestureDetector(
                  onTap: () {
                    setState(() => _licenseAccepted = !_licenseAccepted);
                  },
                  child: Row(
                    children: [
                      Checkbox(
                        value: _licenseAccepted,
                        onChanged: (value) {
                          setState(() => _licenseAccepted = value ?? false);
                        },
                        activeColor: AppColors.primary,
                        checkColor: AppColors.textOnPrimary,
                      ),
                      Expanded(
                        child: Text(
                          'I have read and accept all terms',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Buttons row
                Row(
                  children: [
                    // Decline button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _handleDecline,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.surface,
                          foregroundColor: AppColors.textPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: Color(0xFF94A3B8).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                        ),
                        child: const Text(
                          'Decline',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Accept button (disabled if checkbox not checked)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _licenseAccepted ? _handleAccept : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _licenseAccepted
                              ? AppColors.primary
                              : AppColors.primary.withOpacity(0.5),
                          foregroundColor: AppColors.textOnPrimary,
                          disabledForegroundColor: AppColors.textOnPrimary.withOpacity(0.6),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Accept & Continue',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Footer
          const AppFooter(),
        ],
      ),
    );
  }

  Widget _buildLicenseSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'GEMMA 4 E2B MODEL LICENSE',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'This application uses Google\'s Gemma 4 E2B model for offline emotional support and conversation.\n\n'
          'Model: gemma-4-E2B-it (LiteRT-LM format)\n'
          'Provider: Google via HuggingFace\n\n'
          'The model will be downloaded to your device (2.59 GB) on first launch and cached locally. No data is sent to external servers.\n\n'
          'By accepting this license, you agree to:\n\n'
          '• Use the model only for personal, non-commercial purposes\n'
          '• Comply with the Gemma model license terms\n'
          '• Accept responsibility for model outputs\n\n'
          'For full license details, visit:\n'
          'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PRIVACY POLICY',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'OVERVIEW\n\n'
          'VentAI is a privacy-first emotional support companion app. We are committed to protecting your privacy. This policy explains how we handle your data.\n\n'
          'DATA WE DO NOT COLLECT\n\n'
          'VentAI does NOT collect, store, or transmit any personal information about you, including:\n\n'
          '• Your name, email, phone number, or location\n'
          '• Your conversations or emotional support chats\n'
          '• Your device information or identifiers\n'
          '• Analytics or usage statistics\n'
          '• Behavioral data or activity logs\n'
          '• Any biometric or health data beyond what you voluntarily share in conversations\n\n'
          'ALL DATA STAYS ON YOUR DEVICE\n\n'
          '• Every conversation you have with VentAI is stored ONLY on your device\n'
          '• No data is sent to servers or cloud storage\n'
          '• No data is shared with third parties\n'
          '• Conversations are deleted only when you uninstall the app or manually clear app data\n\n'
          'HOW THE APP WORKS\n\n'
          'VentAI uses an offline AI model (Gemma 4 E2B) that runs entirely on your device:\n\n'
          '• The AI model is downloaded once from Hugging Face (~2.6GB) on first launch\n'
          '• After download, the app works completely offline\n'
          '• No internet connection is required after the initial setup\n'
          '• Your conversations never leave your device\n\n'
          'PERMISSIONS WE REQUEST\n\n'
          'VentAI requests certain permissions:\n\n'
          '• INTERNET: Only used to download the AI model on first launch\n'
          '• STORAGE: To cache the AI model locally on your device\n'
          '• No other data is transmitted\n\n'
          'THIRD-PARTY SERVICES\n\n'
          '• HuggingFace: Used only for downloading the AI model on first launch. No personal data is shared.\n'
          '• No analytics, crash reporting, or tracking services are used\n'
          '• No advertisements or ad networks\n\n'
          'YOUR RIGHTS\n\n'
          '• You have full control over your data\n'
          '• You can delete all app data by uninstalling or clearing app data in settings\n'
          '• You are not required to provide any personal information to use VentAI\n'
          '• Your privacy is respected at all times\n\n'
          'CHANGES TO THIS POLICY\n\n'
          'We may update this privacy policy occasionally. Any changes will be reflected here with an updated date.\n\n'
          'CONTACT US\n\n'
          'If you have privacy questions or concerns, please contact: resolveera@gmail.com\n\n'
          'COMMITMENT\n\n'
          'VentAI is designed with privacy as the foundation. We believe emotional support should be private, secure, and personal. Your data belongs to you, not to us.',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildDisclaimersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'IMPORTANT DISCLAIMERS',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'IMPORTANT LEGAL DISCLAIMER\n\n'
          'VentAI is NOT:\n\n'
          '• A medical device\n'
          '• A substitute for professional mental health care\n'
          '• Therapy, counseling, or medical advice\n'
          '• A crisis intervention service\n\n'
          'LIMITATION OF LIABILITY\n\n'
          'VentAI and its creators are NOT responsible for:\n\n'
          '• Any actions, decisions, or harm resulting from use of this app\n'
          '• Self-harm, injury, or any consequences of user actions\n'
          '• Failure to seek professional help\n'
          '• Misuse or misinterpretation of app responses\n'
          '• Technical failures or service interruptions\n'
          '• Any damages, direct or indirect, arising from app use\n\n'
          'YOU ASSUME ALL RISK\n\n'
          'By using VentAI, you accept full responsibility for any outcomes of your actions. VentAI provides no guarantees about emotional outcomes or safety.\n\n'
          'IF YOU ARE IN CRISIS\n\n'
          'Do NOT rely on this app. Immediately:\n\n'
          '• Call 911 (US emergency)\n'
          '• Call 988 (Suicide & Crisis Lifeline, US)\n'
          '• Text HOME to 741741 (Crisis Text Line)\n'
          '• Contact emergency services in your country\n'
          '• Tell a trusted adult or healthcare provider\n\n'
          'PARENTAL RESPONSIBILITY\n\n'
          'If you are under 18, your parent/guardian is responsible for your use of this app. This app is NOT suitable for unsupervised minor use.\n\n'
          'NO MEDICAL RELATIONSHIP\n\n'
          'Using VentAI does NOT create a doctor-patient relationship. You are not receiving medical, psychiatric, or therapeutic treatment.\n\n'
          'USE AT YOUR OWN RISK\n\n'
          'The creators of VentAI assume NO liability for any harm, injury, or consequences resulting from app use.',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}
