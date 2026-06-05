import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/book.dart';
import '../services/reading_time_service.dart';

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
  static const _backgroundColor = Color(0xFF4B3B63);
  static const _foregroundColor = Color(0xFFF2ECF7);
  static const _mutedColor = Color(0xFFD4C8DE);
  static const _buttonColor = Color(0xFFE9E2EC);
  static const _buttonTextColor = Color(0xFF473856);

  final _readingTimeService = ReadingTimeService();
  Duration _readingDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadReadingDuration();
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.book;
    final mediaQuery = MediaQuery.of(context);
    final author = book.author.trim().isEmpty ? '未知作者' : book.author.trim();
    final format = _formatLabel(book);
    final status = _readingStatus(book);

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bottomPadding = math.max(mediaQuery.padding.bottom, 12.0);
            final infoHeight = 124.0 + bottomPadding;
            final mainHeight =
                math.max(0.0, constraints.maxHeight - infoHeight);
            final coverHeight = (mainHeight - 190).clamp(170.0, 420.0);

            return Column(
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
                              color: _foregroundColor.withAlpha(90),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _DetailCover(
                            book: book,
                            height: coverHeight,
                          ),
                          const SizedBox(height: 20),
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
                                  fontWeight: FontWeight.w800,
                                  height: 1.18,
                                ),
                          ),
                          const SizedBox(height: 8),
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
                          const SizedBox(height: 22),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: _buttonColor,
                              foregroundColor: _buttonTextColor,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 42,
                                vertical: 15,
                              ),
                              shape: const StadiumBorder(),
                              textStyle: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('开始阅读'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _DetailInfoBar(
                  readingTime: _formatDuration(_readingDuration),
                  format: format,
                  status: status,
                  bottomPadding: bottomPadding,
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

  String _formatLabel(Book book) {
    return switch (book.bookType) {
      BookType.text => 'TXT',
      BookType.epub => 'EPUB',
      BookType.comic => 'Comic',
    };
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
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(70),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
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
      color: const Color(0xFFEDE7F2),
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
        border: Border(
          top: BorderSide(color: Colors.white.withAlpha(85)),
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
      color: Colors.white.withAlpha(85),
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
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Icon(
            icon,
            color: const Color(0xFFE6DDEA),
            size: 27,
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
