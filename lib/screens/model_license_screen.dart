import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ModelLicenseScreen extends StatefulWidget {
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const ModelLicenseScreen({
    required this.onAccept,
    required this.onDecline,
    super.key,
  });

  @override
  State<ModelLicenseScreen> createState() => _ModelLicenseScreenState();
}

class _ModelLicenseScreenState extends State<ModelLicenseScreen> {
  bool _agreedToLicense = false;

  Future<void> _openHuggingFaceLink() async {
    const url = 'https://huggingface.co/google/gemma-4-E2B-it';
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open link: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Model License Agreement'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // License header
              Text(
                'Gemma 4 E2B Model License',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),

              // License content
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[50],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'GEMMA 4 E2B MODEL LICENSE',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'This application uses Google\'s Gemma 4 E2B model for offline '
                      'emotional support and conversation.\n\n'
                      'Model: gemma-4-E2B-it\n'
                      'Provider: Google via HuggingFace\n\n'
                      'The model will be downloaded to your device (~2.4GB) on first '
                      'launch and cached locally. No data is sent to external servers.\n\n'
                      'By accepting this license, you agree to:\n'
                      '• Use the model only for personal, non-commercial purposes\n'
                      '• Comply with the Gemma model license terms\n'
                      '• Accept responsibility for model outputs\n\n'
                      'For full license details, visit:\n'
                      'https://huggingface.co/google/gemma-4-E2B-it',
                      style: TextStyle(fontSize: 14, height: 1.6),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // HuggingFace link button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openHuggingFaceLink,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('View Full License on HuggingFace'),
                ),
              ),
              const SizedBox(height: 16),

              // Checkbox for agreement
              Row(
                children: [
                  Checkbox(
                    value: _agreedToLicense,
                    onChanged: (value) {
                      setState(() {
                        _agreedToLicense = value ?? false;
                      });
                    },
                  ),
                  Expanded(
                    child: Text(
                      'I understand and accept the Gemma model license',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onDecline,
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _agreedToLicense ? widget.onAccept : null,
                      child: const Text('Accept & Download'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Information note
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info, color: Colors.blue[600], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Model download will begin after accepting. This may take '
                        'several minutes depending on your internet connection.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
