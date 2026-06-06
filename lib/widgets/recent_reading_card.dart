import 'dart:io';

import 'package:flutter/material.dart';

import '../models/book.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';

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
      return DecoratedBox(
        decoration: _cardDecoration(),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              const Icon(
                Icons.history_rounded,
                color: AppColors.teaAmberDeep,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '最近阅读',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    final progressText = '${(book.progress * 100).clamp(0, 100).round()}%';
    return DecoratedBox(
      decoration: _cardDecoration(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.parchment,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    boxShadow: [AppShadows.coverGlow(opacity: 0.18)],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: SizedBox(
                      width: 58,
                      height: 82,
                      child: _cover(book),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '最近阅读',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppColors.teaAmberDeep,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        book.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppColors.ink,
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        book.author.trim().isEmpty ? '作者未记录' : book.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.mutedInk,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: book.progress.clamp(0, 1),
                        minHeight: 5,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.sakuraMist,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      progressText,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColors.deepPurple,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cover(Book book) {
    final file = File(book.coverPath);
    if (book.coverPath.isNotEmpty && file.existsSync()) {
      return ColoredBox(
        color: const Color(0xFFF1F2F2),
        child: Image.file(
          file,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              const ColoredBox(color: Color(0xFFE4E7E7)),
        ),
      );
    }
    return const ColoredBox(color: AppColors.lavenderMist);
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppColors.parchment.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(color: Colors.white.withValues(alpha: 0.76)),
      boxShadow: AppShadows.soft,
    );
  }
}
