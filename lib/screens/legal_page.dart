import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_footer.dart';
import '../legal/privacy_policy_text.dart';

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

  /// Renders [kPrivacyPolicyText]: ALL-CAPS lines are headings, "* " lines
  /// are bullets, other lines are body text.
  Widget _buildPrivacyPolicy() {
    final children = <Widget>[];
    for (final rawLine in kPrivacyPolicyText.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final isHeading =
          line == line.toUpperCase() && line.contains(RegExp('[A-Z]'));
      if (line.startsWith('* ')) {
        children.add(_bulletPoint(line.substring(2)));
      } else if (isHeading) {
        if (children.isNotEmpty) children.add(const SizedBox(height: 24));
        children.add(_heading(line));
      } else {
        children.add(_bodyText(line));
      }
    }
    children.add(const SizedBox(height: 40));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
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
