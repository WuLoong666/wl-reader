import 'package:flutter/material.dart';

import '../models/book.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import 'local_image_view.dart';

class BookCoverCard extends StatelessWidget {
  const BookCoverCard({
    super.key,
    required this.book,
    this.onTap,
    this.onLongPressStart,
    this.onSecondaryTapDown,
  });

  static const _coverAspectRatio = 0.68;

  final Book book;
  final VoidCallback? onTap;
  final GestureLongPressStartCallback? onLongPressStart;
  final GestureTapDownCallback? onSecondaryTapDown;

  @override
  Widget build(BuildContext context) {
    final progressText = '${(book.progress * 100).clamp(0, 100).round()}%';

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPressStart: onLongPressStart,
      onSecondaryTapDown: onSecondaryTapDown,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: AspectRatio(
                      aspectRatio: _coverAspectRatio,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          boxShadow: [AppShadows.coverGlow()],
                        ),
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
                                  color: AppColors.deepPurple
                                      .withValues(alpha: 0.76),
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.sm),
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
                                      fontWeight: FontWeight.w800,
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
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  book.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                        height: 1.16,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  book.author.trim().isEmpty ? '作者未记录' : book.author.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.mutedInk,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ),
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
        color: AppColors.deepPurple.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(AppRadius.sm),
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
        color: AppColors.sakuraPink,
        borderRadius: BorderRadius.circular(AppRadius.sm),
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
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.parchment,
            AppColors.lavenderMist,
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
      ),
      clipBehavior: Clip.antiAlias,
      child: book.coverPath.isNotEmpty
          ? LocalImageView(
              path: book.coverPath,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.contain,
              fallbackBuilder: (_) => _FallbackCover(title: book.title),
              unsupportedBuilder: (_) => _FallbackCover(title: book.title),
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.sakuraMist,
            AppColors.lavenderMist,
            AppColors.parchment,
          ],
        ),
      ),
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
