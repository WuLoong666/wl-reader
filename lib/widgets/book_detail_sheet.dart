import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/book.dart';
import '../services/reading_progress_service.dart';
import '../services/reading_time_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

Future<bool?> showBookDetailSheet({
  required BuildContext context,
  required Book book,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withAlpha(155),
    builder: (context) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight * 0.82;
          final width = math.min(constraints.maxWidth, 560.0);
          return Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: width,
              height: height,
              child: BookDetailSheet(book: book),
            ),
          );
        },
      );
    },
  );
}

class BookDetailSheet extends StatefulWidget {
  const BookDetailSheet({
    super.key,
    required this.book,
  });

  final Book book;

  @override
  State<BookDetailSheet> createState() => _BookDetailSheetState();
}

class _BookDetailSheetState extends State<BookDetailSheet> {
  static const _foregroundColor = Color(0xFFF2ECF7);
  static const _mutedColor = Color(0xFFD4C8DE);

  final _readingTimeService = ReadingTimeService();
  Duration _readingDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadReadingDuration();
  }

  @override
  Widget build(BuildContext context) {
    final book = _currentBook(context);
    final mediaQuery = MediaQuery.of(context);
    final author = book.author.trim().isEmpty ? '未知作者' : book.author.trim();
    final status = _readingStatus(book);
    final actionText = book.progress > 0 ? '继续阅读' : '开始阅读';

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.purpleGradient,
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bottomPadding = math.max(mediaQuery.padding.bottom, 12.0);
            final infoHeight = 124.0 + bottomPadding;
            final mainHeight =
                math.max(0.0, constraints.maxHeight - infoHeight);
            final coverHeight = (mainHeight - 206).clamp(160.0, 420.0);

            return Stack(
              children: [
                const Positioned.fill(child: _DetailPattern()),
                Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 10, 24, 18),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: mainHeight),
                          child: Column(
                            children: [
                              Container(
                                width: 44,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: _foregroundColor.withAlpha(100),
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.pill),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              _DetailCover(
                                book: book,
                                height: coverHeight,
                              ),
                              const SizedBox(height: 18),
                              Text(
                                book.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      color: _foregroundColor,
                                      fontWeight: FontWeight.w900,
                                      height: 1.18,
                                    ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                author,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: _mutedColor,
                                      height: 1.25,
                                    ),
                              ),
                              const SizedBox(height: 18),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.parchment,
                                  foregroundColor: AppColors.deepPurple,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 44,
                                    vertical: 15,
                                  ),
                                  shape: const StadiumBorder(),
                                  textStyle: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: Text(actionText),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _foregroundColor,
                                  side: BorderSide(
                                    color: _foregroundColor.withAlpha(125),
                                  ),
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.08),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  shape: const StadiumBorder(),
                                ),
                                onPressed: () => _toggleWantToRead(book),
                                icon: Icon(
                                  book.isWantToRead
                                      ? Icons.bookmark
                                      : Icons.bookmark_border,
                                ),
                                label: Text(
                                  book.isWantToRead ? '移出欲读' : '加入欲读',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _DetailInfoBar(
                      readingTime: _formatDuration(_readingDuration),
                      format: book.formatLabel,
                      status: status,
                      bottomPadding: bottomPadding,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _loadReadingDuration() async {
    final id = widget.book.id;
    if (id == null) {
      return;
    }

    final duration = await _readingTimeService.bookDuration(id);
    if (!mounted) {
      return;
    }
    setState(() => _readingDuration = duration);
  }

  Book _currentBook(BuildContext context) {
    final books = context.watch<LibraryStore>().allBooks;
    for (final book in books) {
      if (book.id == widget.book.id) {
        return book;
      }
    }
    return widget.book;
  }

  Future<void> _toggleWantToRead(Book book) async {
    await context.read<LibraryStore>().updateWantToRead(
          book: book,
          isWantToRead: !book.isWantToRead,
        );
  }

  String _readingStatus(Book book) {
    if (book.progress <= 0) {
      return '未读';
    }
    if (book.progress >= 0.995) {
      return '已读';
    }
    return '阅读中';
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    if (totalSeconds <= 0) {
      return '0 分钟';
    }

    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return minutes > 0 ? '$hours 小时 $minutes 分' : '$hours 小时';
    }
    if (minutes > 0) {
      return seconds > 0 ? '$minutes 分 $seconds 秒' : '$minutes 分';
    }
    return '$seconds 秒';
  }
}

class _DetailPattern extends StatelessWidget {
  const _DetailPattern();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _DetailPatternPainter());
  }
}

class _DetailPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final pagePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = Colors.white.withValues(alpha: 0.12);
    final starPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.4
      ..color = AppColors.star.withValues(alpha: 0.38);

    final path = Path()
      ..moveTo(size.width * 0.12, size.height * 0.16)
      ..quadraticBezierTo(
        size.width * 0.3,
        size.height * 0.06,
        size.width * 0.48,
        size.height * 0.16,
      )
      ..moveTo(size.width * 0.56, size.height * 0.18)
      ..quadraticBezierTo(
        size.width * 0.74,
        size.height * 0.08,
        size.width * 0.9,
        size.height * 0.2,
      );
    canvas.drawPath(path, pagePaint);

    for (final point in [
      Offset(size.width * 0.18, size.height * 0.28),
      Offset(size.width * 0.84, size.height * 0.32),
      Offset(size.width * 0.74, size.height * 0.64),
    ]) {
      canvas.drawLine(point.translate(-5, 0), point.translate(5, 0), starPaint);
      canvas.drawLine(point.translate(0, -5), point.translate(0, 5), starPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DetailCover extends StatelessWidget {
  const _DetailCover({
    required this.book,
    required this.height,
  });

  final Book book;
  final double height;

  @override
  Widget build(BuildContext context) {
    final file = File(book.coverPath);
    final hasCover = book.coverPath.isNotEmpty && file.existsSync();

    return SizedBox(
      height: height,
      child: AspectRatio(
        aspectRatio: 0.68,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(235),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: [
              BoxShadow(
                color: AppColors.sakuraPink.withValues(alpha: 0.26),
                blurRadius: 34,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withAlpha(84),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: hasCover
                ? Image.file(
                    file,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => _FallbackDetailCover(
                      title: book.title,
                    ),
                  )
                : _FallbackDetailCover(title: book.title),
          ),
        ),
      ),
    );
  }
}

class _FallbackDetailCover extends StatelessWidget {
  const _FallbackDetailCover({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.lavenderMist,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            title,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF4B3B63),
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
          ),
        ),
      ),
    );
  }
}

class _DetailInfoBar extends StatelessWidget {
  const _DetailInfoBar({
    required this.readingTime,
    required this.format,
    required this.status,
    required this.bottomPadding,
  });

  final String readingTime;
  final String format;
  final String status;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        border: Border(
          top: BorderSide(color: Colors.white.withAlpha(52)),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(10, 16, 10, bottomPadding),
        child: SizedBox(
          height: 96,
          child: Row(
            children: [
              Expanded(
                child: _InfoColumn(
                  title: '阅读时间',
                  icon: Icons.timer_outlined,
                  value: readingTime,
                ),
              ),
              const _InfoDivider(),
              Expanded(
                child: _InfoColumn(
                  title: '书籍格式',
                  icon: Icons.extension_outlined,
                  value: format,
                ),
              ),
              const _InfoDivider(),
              Expanded(
                child: _InfoColumn(
                  title: '阅读状态',
                  icon: Icons.library_books_outlined,
                  value: status,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoDivider extends StatelessWidget {
  const _InfoDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: double.infinity,
      color: Colors.white.withAlpha(48),
    );
  }
}

class _InfoColumn extends StatelessWidget {
  const _InfoColumn({
    required this.title,
    required this.icon,
    required this.value,
  });

  final String title;
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFF2ECF7),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                icon,
                color: const Color(0xFFEEDDF2),
                size: 23,
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFF2ECF7),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
