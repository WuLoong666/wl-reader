import 'dart:io';

import 'package:flutter/material.dart';

import '../models/book.dart';

class BookCoverCard extends StatelessWidget {
  const BookCoverCard({
    super.key,
    required this.book,
    this.onTap,
  });

  static const _coverAspectRatio = 0.68;

  final Book book;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final progressText = '${(book.progress * 100).clamp(0, 100).round()}%';

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: AspectRatio(
                aspectRatio: _coverAspectRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _CoverImage(book: book),
                    Positioned(
                      left: 6,
                      bottom: 6,
                      child: _CoverBadge(
                        label: book.typeLabel,
                        icon: book.bookType == BookType.comic
                            ? Icons.collections_bookmark_outlined
                            : Icons.menu_book_outlined,
                      ),
                    ),
                    if (book.isWantToRead)
                      const Positioned(
                        left: 6,
                        top: 6,
                        child: _BookmarkBadge(),
                      ),
                    Positioned(
                      right: 6,
                      top: 6,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.66),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          child: Text(
                            progressText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
          ),
        ],
      ),
    );
  }
}

class _CoverBadge extends StatelessWidget {
  const _CoverBadge({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 12,
            ),
            const SizedBox(width: 3),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookmarkBadge extends StatelessWidget {
  const _BookmarkBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Padding(
        padding: EdgeInsets.all(4),
        child: Icon(
          Icons.bookmark,
          color: Colors.white,
          size: 14,
        ),
      ),
    );
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final file = File(book.coverPath);
    final hasCover = book.coverPath.isNotEmpty && file.existsSync();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasCover
          ? Image.file(
              file,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _FallbackCover(title: book.title),
            )
          : _FallbackCover(title: book.title),
    );
  }
}

class _FallbackCover extends StatelessWidget {
  const _FallbackCover({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      color: Theme.of(context).colorScheme.secondaryContainer,
      padding: const EdgeInsets.all(10),
      child: Text(
        title,
        maxLines: 5,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
      ),
    );
  }
}
