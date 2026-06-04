import 'dart:io';

import 'package:flutter/material.dart';

import '../models/book.dart';

class RecentReadingCard extends StatelessWidget {
  const RecentReadingCard({
    super.key,
    required this.book,
    this.onTap,
  });

  final Book? book;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final book = this.book;
    if (book == null) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '最近阅读',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      );
    }

    final progressText = '${(book.progress * 100).clamp(0, 100).round()}%';
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 58,
                  height: 82,
                  child: _cover(book),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '最近阅读',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      book.author.trim().isEmpty ? '作者未记录' : book.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: book.progress.clamp(0, 1)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                progressText,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cover(Book book) {
    final file = File(book.coverPath);
    if (book.coverPath.isNotEmpty && file.existsSync()) {
      return Image.file(file, fit: BoxFit.cover);
    }
    return const ColoredBox(color: Color(0xFFE4E7E7));
  }
}
