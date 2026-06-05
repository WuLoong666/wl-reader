import 'package:flutter/material.dart';

import '../models/book.dart';
import '../services/reading_time_service.dart';

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
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatDuration(_todayDuration),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 14),
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
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  Center(
                    child: Icon(
                      Icons.timer_outlined,
                      color: Theme.of(context).colorScheme.primary,
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
