import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SuggestedPromptsWidget extends StatelessWidget {
  final Function(String) onPromptTap;

  static const List<String> SUGGESTED_PROMPTS = [
    'I have been feeling strange for some days around my feelings. Can you help me understand them?',
    'I am getting very irritable and angry. Its affecting my work and relationships. How can I control my impulses?',
    'Why am I not able to focus?',
    'Why do I feel so hopeless and helpless?',
    'I am feeling isolated and uninterested in anything',
    'I am feeling stressed at the moment and need someone to talk to',
  ];

  const SuggestedPromptsWidget({
    required this.onPromptTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 6 : 12,
        vertical: 2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'Try asking about...',
              style: TextStyle(
                fontSize: isMobile ? 9 : 10,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 3,
            crossAxisSpacing: 3,
            childAspectRatio: isMobile ? 2.4 : 3.2,
            children: SUGGESTED_PROMPTS.map((prompt) {
              return GestureDetector(
                onTap: () => onPromptTap(prompt),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFF94A3B8).withOpacity(0.3),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(4),
                    color: AppColors.surface,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  child: Center(
                    child: Text(
                      prompt,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isMobile ? 8.5 : 9,
                        color: AppColors.textPrimary,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
