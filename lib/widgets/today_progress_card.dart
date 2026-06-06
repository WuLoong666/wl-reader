import 'package:flutter/material.dart';

import '../models/book.dart';
import '../services/reading_time_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import 'magic_gradient_card.dart';

class TodayProgressCard extends StatefulWidget {
  const TodayProgressCard({
    super.key,
    required this.book,
    this.onContinue,
  });

  final Book? book;
  final VoidCallback? onContinue;

  @override
  State<TodayProgressCard> createState() => _TodayProgressCardState();
}

class _TodayProgressCardState extends State<TodayProgressCard> {
  final _readingTimeService = ReadingTimeService();
  Duration _todayDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadTodayDuration();
  }

  @override
  void didUpdateWidget(covariant TodayProgressCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.book?.lastReadTime != widget.book?.lastReadTime ||
        oldWidget.book?.id != widget.book?.id) {
      _loadTodayDuration();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MagicGradientCard(
      child: Padding(
        padding: EdgeInsets.zero,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '今日阅读时间',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.deepPurple,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _formatDuration(_todayDuration),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.icon(
                    onPressed: widget.onContinue,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('继续阅读'),
                  ),
                ],
              ),
            ),
            SizedBox.square(
              dimension: 72,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.64),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                  ),
                  Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.lavenderMist,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(AppSpacing.sm),
                        child: Icon(
                          Icons.menu_book_outlined,
                          color: AppColors.deepPurple,
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                    right: 10,
                    top: 10,
                    child: Icon(
                      Icons.auto_awesome,
                      color: AppColors.star,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadTodayDuration() async {
    final duration = await _readingTimeService.todayDuration();
    if (!mounted) {
      return;
    }
    setState(() => _todayDuration = duration);
  }

  String _formatDuration(Duration duration) {
    final totalMinutes = duration.inMinutes;
    if (totalMinutes <= 0) {
      return '今日已阅读 0 分钟';
    }
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours <= 0) {
      return '今日已阅读 $minutes 分钟';
    }
    if (minutes == 0) {
      return '今日已阅读 $hours 小时';
    }
    return '今日已阅读 $hours 小时 $minutes 分钟';
  }
}
