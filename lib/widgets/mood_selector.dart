import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class MoodSelector extends StatelessWidget {
  final String? selectedMood;
  final Function(String) onMoodSelected;
  final bool isMobile;

  const MoodSelector({
    super.key,
    this.selectedMood,
    required this.onMoodSelected,
    this.isMobile = false,
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
    final moodHeight = isMobile ? 50 : 56;
    final moodWidth = isMobile ? 44 : 48;
    final iconSize = isMobile ? 18 : 20;
    final labelFontSize = isMobile ? 8.0 : 8.5;
    final gapHeight = isMobile ? 2.0 : 3.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'How are you feeling? (Optional)',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: AppColors.textTertiary,
              fontSize: isMobile ? 9 : 10,
            ),
          ),
        ),
        SizedBox(height: isMobile ? 4 : 6),
        SizedBox(
          height: moodHeight.toDouble(),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            itemCount: moodIcons.length,
            itemBuilder: (context, index) {
              final mood = moodIcons.keys.elementAt(index);
              final icon = moodIcons[mood]!;
              final color = moodColors[mood]!;
              final isSelected = selectedMood == mood;

              return Padding(
                padding: EdgeInsets.only(right: isMobile ? 5 : 7),
                child: GestureDetector(
                  onTap: () => onMoodSelected(mood),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: moodWidth.toDouble(),
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
                            size: iconSize.toDouble(),
                          ),
                        ),
                        SizedBox(height: gapHeight),
                        Text(
                          _capitalizeMood(mood),
                          style: TextStyle(
                            fontSize: labelFontSize,
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
          SizedBox(height: isMobile ? 6 : 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => onMoodSelected(''),
              icon: const Icon(Icons.clear, size: 14),
              label: const Text('Clear selection'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.outline,
                textStyle: TextStyle(fontSize: isMobile ? 11 : 12),
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
