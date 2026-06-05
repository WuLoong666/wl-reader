import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/book_sorter.dart';

typedef BookSortChanged = void Function(
  BookSortType sortType,
  SortOrder sortOrder,
);

Future<void> showBookSortSheet({
  required BuildContext context,
  required BookSortType sortType,
  required SortOrder sortOrder,
  required BookSortChanged onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withAlpha(120),
    builder: (context) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final width = math.min(constraints.maxWidth, 560.0);
          return Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: width,
              child: BookSortSheet(
                sortType: sortType,
                sortOrder: sortOrder,
                onChanged: onChanged,
              ),
            ),
          );
        },
      );
    },
  );
}

class BookSortSheet extends StatefulWidget {
  const BookSortSheet({
    super.key,
    required this.sortType,
    required this.sortOrder,
    required this.onChanged,
  });

  final BookSortType sortType;
  final SortOrder sortOrder;
  final BookSortChanged onChanged;

  @override
  State<BookSortSheet> createState() => _BookSortSheetState();
}

class _BookSortSheetState extends State<BookSortSheet> {
  late BookSortType _sortType;
  late SortOrder _sortOrder;

  @override
  void initState() {
    super.initState();
    _sortType = widget.sortType;
    _sortOrder = widget.sortOrder;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  '书籍排序',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 18),
                const _SectionTitle(title: '排序方式'),
                const SizedBox(height: 8),
                ...BookSortType.values.map(
                  (type) => _SortOptionTile(
                    title: type.label,
                    selected: _sortType == type,
                    onTap: () => _update(sortType: type),
                  ),
                ),
                const SizedBox(height: 16),
                const _SectionTitle(title: '排序顺序'),
                const SizedBox(height: 8),
                ...SortOrder.values.map(
                  (order) => _SortOptionTile(
                    title: order.label,
                    selected: _sortOrder == order,
                    onTap: () => _update(sortOrder: order),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _update({
    BookSortType? sortType,
    SortOrder? sortOrder,
  }) {
    final nextSortType = sortType ?? _sortType;
    final nextSortOrder = sortOrder ?? _sortOrder;
    if (nextSortType == _sortType && nextSortOrder == _sortOrder) {
      return;
    }

    setState(() {
      _sortType = nextSortType;
      _sortOrder = nextSortOrder;
    });
    widget.onChanged(_sortType, _sortOrder);
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w800,
          ),
    );
  }
}

class _SortOptionTile extends StatelessWidget {
  const _SortOptionTile({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = selected
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest.withAlpha(115);
    final foreground =
        selected ? colorScheme.onPrimaryContainer : colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? colorScheme.primary : Colors.transparent,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 16,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 120),
                  opacity: selected ? 1 : 0,
                  child: Icon(
                    Icons.check_circle,
                    color: colorScheme.primary,
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
