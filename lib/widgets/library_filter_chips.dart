import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../utils/library_filter.dart';

class LibraryFilterChips extends StatelessWidget {
  const LibraryFilterChips({
    super.key,
    required this.currentFilter,
    required this.counts,
    required this.onChanged,
  });

  final LibraryFilter currentFilter;
  final Map<LibraryFilter, int> counts;
  final ValueChanged<LibraryFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in LibraryFilter.values) ...[
            ChoiceChip(
              label: Text('${filter.label} ${counts[filter] ?? 0}'),
              selected: currentFilter == filter,
              onSelected: (_) => onChanged(filter),
              showCheckmark: false,
              backgroundColor: AppColors.parchment.withValues(alpha: 0.78),
              selectedColor: AppColors.sakuraMist,
              side: BorderSide(
                color: currentFilter == filter
                    ? AppColors.sakuraPink
                    : AppColors.line,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              avatar: Icon(
                _iconFor(filter),
                size: 18,
                color: currentFilter == filter
                    ? AppColors.deepPurple
                    : AppColors.mutedInk,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }

  IconData _iconFor(LibraryFilter filter) {
    return switch (filter) {
      LibraryFilter.all => Icons.auto_stories_outlined,
      LibraryFilter.wantToRead => Icons.bookmark_border,
      LibraryFilter.novel => Icons.menu_book_outlined,
      LibraryFilter.comic => Icons.collections_bookmark_outlined,
    };
  }
}
