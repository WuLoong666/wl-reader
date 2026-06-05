import 'package:flutter/material.dart';

import '../models/reader_mode.dart';

class ReaderBottomMenu extends StatelessWidget {
  const ReaderBottomMenu({
    super.key,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.currentChapterIndex,
    required this.chapterCount,
    required this.progressText,
    required this.fontSize,
    required this.isDarkMode,
    required this.readerMode,
    required this.onPreviousChapter,
    required this.onNextChapter,
    required this.onDecreaseFont,
    required this.onIncreaseFont,
    required this.onCycleBackground,
    required this.onToggleNightMode,
    required this.onModeChanged,
  });

  final Color backgroundColor;
  final Color foregroundColor;
  final int currentChapterIndex;
  final int chapterCount;
  final String progressText;
  final double fontSize;
  final bool isDarkMode;
  final ReaderMode readerMode;
  final VoidCallback onPreviousChapter;
  final VoidCallback onNextChapter;
  final VoidCallback onDecreaseFont;
  final VoidCallback onIncreaseFont;
  final VoidCallback onCycleBackground;
  final VoidCallback onToggleNightMode;
  final ValueChanged<ReaderMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final buttonStyle = OutlinedButton.styleFrom(
      foregroundColor: foregroundColor,
      side: BorderSide(color: foregroundColor.withAlpha(95)),
      visualDensity: VisualDensity.compact,
    );

    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: isDarkMode
            ? const ColorScheme.dark(primary: Color(0xFFE6E1D8))
            : const ColorScheme.light(primary: Color(0xFF2F6F6D)),
      ),
      child: Container(
        color: backgroundColor.withAlpha(238),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: buttonStyle,
                        onPressed: onPreviousChapter,
                        icon: const Icon(Icons.chevron_left),
                        label: const Text('上一章'),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        '第 ${currentChapterIndex + 1} / $chapterCount 章',
                        style: TextStyle(
                          color: foregroundColor,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: buttonStyle,
                        onPressed: onNextChapter,
                        icon: const Icon(Icons.chevron_right),
                        label: const Text('下一章'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: '减小字号',
                      color: foregroundColor,
                      onPressed: onDecreaseFont,
                      icon: const Icon(Icons.text_decrease),
                    ),
                    SizedBox(
                      width: 76,
                      child: Text(
                        '${fontSize.round()} 号',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: foregroundColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '增大字号',
                      color: foregroundColor,
                      onPressed: onIncreaseFont,
                      icon: const Icon(Icons.text_increase),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      progressText,
                      style: TextStyle(
                        color: foregroundColor,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      style: buttonStyle,
                      onPressed: onCycleBackground,
                      icon: const Icon(Icons.palette_outlined),
                      label: const Text('背景'),
                    ),
                    OutlinedButton.icon(
                      style: buttonStyle,
                      onPressed: onToggleNightMode,
                      icon: Icon(
                        isDarkMode ? Icons.dark_mode : Icons.light_mode,
                      ),
                      label: Text(isDarkMode ? '夜间' : '日间'),
                    ),
                    SizedBox(
                      width: 210,
                      child: SegmentedButton<ReaderMode>(
                        style: ButtonStyle(
                          foregroundColor:
                              WidgetStatePropertyAll(foregroundColor),
                          side: WidgetStatePropertyAll(
                            BorderSide(color: foregroundColor.withAlpha(95)),
                          ),
                        ),
                        segments: const [
                          ButtonSegment(
                            value: ReaderMode.horizontalPage,
                            icon: Icon(Icons.swap_horiz),
                            label: Text('分页'),
                          ),
                          ButtonSegment(
                            value: ReaderMode.verticalScroll,
                            icon: Icon(Icons.format_align_left),
                            label: Text('连续'),
                          ),
                        ],
                        selected: {readerMode},
                        onSelectionChanged: (modes) {
                          if (modes.isEmpty) {
                            return;
                          }
                          onModeChanged(modes.first);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
