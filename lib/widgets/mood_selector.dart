import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class MoodSelector extends StatelessWidget {
  final String? selectedMood;
  final Function(String) onMoodSelected;

  const MoodSelector({
    super.key,
    this.selectedMood,
    required this.onMoodSelected,
  });

  static const Map<String, IconData> moodIcons = {
    'happy': Icons.sentiment_satisfied,
    'sad': Icons.sentiment_dissatisfied,
    'angry': Icons.sentiment_very_dissatisfied,
    'anxious': Icons.psychology,
    'calm': Icons.spa,
    'stressed': Icons.bolt,
    'confused': Icons.help_outline,
    'excited': Icons.star,
    'lonely': Icons.person_outline,
    'grateful': Icons.favorite_outline,
  };

  static const Map<String, Color> moodColors = {
    'happy': AppColors.warning,
    'sad': AppColors.primary,
    'angry': AppColors.error,
    'anxious': AppColors.primary,
    'calm': AppColors.success,
    'stressed': AppColors.warning,
    'confused': AppColors.textTertiary,
    'excited': AppColors.primary,
    'lonely': AppColors.primary,
    'grateful': AppColors.success,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'How are you feeling? (Optional)',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: AppColors.textTertiary,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: moodIcons.length,
            itemBuilder: (context, index) {
              final mood = moodIcons.keys.elementAt(index);
              final icon = moodIcons[mood]!;
              final color = moodColors[mood]!;
              final isSelected = selectedMood == mood;

              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () => onMoodSelected(mood),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 60,
                    decoration: BoxDecoration(
                      color: isSelected
                        ? color.withOpacity(0.15)
                        : AppColors.surface,
                      border: Border.all(
                        color: isSelected
                          ? color
                          : Colors.transparent,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: isSelected ? [
                        BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ] : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedScale(
                          scale: isSelected ? 1.1 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            icon,
                            color: isSelected 
                              ? color 
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _capitalizeMood(mood),
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected 
                              ? color 
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: isSelected 
                              ? FontWeight.w600 
                              : FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        
        //Clear selection option
        if (selectedMood != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => onMoodSelected(''),
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Clear selection'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.outline,
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Capitalize the first letter of mood name
  String _capitalizeMood(String mood) {
    if (mood.isEmpty) return mood;
    return mood[0].toUpperCase() + mood.substring(1);
  }
}
