import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/book.dart';

typedef BookContextMenuAction = FutureOr<void> Function();

class BookContextMenuItem {
  const BookContextMenuItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final BookContextMenuAction onTap;
  final bool destructive;
}

Future<void> showBookContextMenu({
  required BuildContext context,
  required Book book,
  required Offset position,
  required BookContextMenuAction onSelect,
  required BookContextMenuAction onEditInfo,
  required BookContextMenuAction onMarkAsRead,
  required BookContextMenuAction onMarkAsUnread,
  required BookContextMenuAction onEditCover,
  required BookContextMenuAction onShareFile,
  required BookContextMenuAction onDelete,
  BookContextMenuAction? onToggleWantToRead,
}) {
  final items = [
    BookContextMenuItem(
      label: '选择',
      icon: Icons.checklist_rounded,
      onTap: onSelect,
    ),
    BookContextMenuItem(
      label: '编辑信息',
      icon: Icons.edit_outlined,
      onTap: onEditInfo,
    ),
    BookContextMenuItem(
      label: '标记为已读完',
      icon: Icons.check_rounded,
      onTap: onMarkAsRead,
    ),
    BookContextMenuItem(
      label: '标记为未阅读',
      icon: Icons.close_rounded,
      onTap: onMarkAsUnread,
    ),
    if (onToggleWantToRead != null)
      BookContextMenuItem(
        label: book.isWantToRead ? '移出欲读' : '加入欲读',
        icon: book.isWantToRead
            ? Icons.bookmark_rounded
            : Icons.bookmark_border_rounded,
        onTap: onToggleWantToRead,
      ),
    BookContextMenuItem(
      label: '编辑封面',
      icon: Icons.image_outlined,
      onTap: onEditCover,
    ),
    BookContextMenuItem(
      label: '分享文件',
      icon: Icons.share_outlined,
      onTap: onShareFile,
    ),
    BookContextMenuItem(
      label: '删除',
      icon: Icons.delete_outline_rounded,
      onTap: onDelete,
      destructive: true,
    ),
  ];

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 140),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _BookContextMenuOverlay(
        anchorPosition: position,
        items: items,
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}

class _BookContextMenuOverlay extends StatelessWidget {
  const _BookContextMenuOverlay({
    required this.anchorPosition,
    required this.items,
  });

  static const _menuWidth = 304.0;
  static const _itemHeight = 58.0;
  static const _edgePadding = 16.0;

  final Offset anchorPosition;
  final List<BookContextMenuItem> items;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.28),
                ),
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final safeLeft = _edgePadding + mediaQuery.padding.left;
              final safeTop = _edgePadding + mediaQuery.padding.top;
              final safeRight = constraints.maxWidth -
                  _edgePadding -
                  mediaQuery.padding.right;
              final safeBottom = constraints.maxHeight -
                  _edgePadding -
                  mediaQuery.padding.bottom;
              final availableWidth = safeRight > safeLeft
                  ? safeRight - safeLeft
                  : constraints.maxWidth;
              final menuWidth = availableWidth < 160
                  ? availableWidth
                  : _menuWidth.clamp(160.0, availableWidth).toDouble();
              final availableHeight = safeBottom > safeTop
                  ? safeBottom - safeTop
                  : constraints.maxHeight;
              final maxMenuHeight = availableHeight < 160
                  ? availableHeight
                  : availableHeight.clamp(160.0, 520.0).toDouble();
              final wantedMenuHeight = items.length * _itemHeight + 12;
              final menuHeight = wantedMenuHeight > maxMenuHeight
                  ? maxMenuHeight
                  : wantedMenuHeight;
              final maxLeft = safeRight - menuWidth;
              final maxTop = safeBottom - menuHeight;
              final left = maxLeft < safeLeft
                  ? safeLeft
                  : anchorPosition.dx.clamp(safeLeft, maxLeft).toDouble();
              final top = maxTop < safeTop
                  ? safeTop
                  : anchorPosition.dy.clamp(safeTop, maxTop).toDouble();

              return Positioned(
                left: left,
                top: top,
                width: menuWidth,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxMenuHeight),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 32,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final item in items)
                              _BookContextMenuTile(item: item),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BookContextMenuTile extends StatelessWidget {
  const _BookContextMenuTile({
    required this.item,
  });

  final BookContextMenuItem item;

  @override
  Widget build(BuildContext context) {
    final color =
        item.destructive ? const Color(0xFFE53935) : const Color(0xFF25212E);

    return InkWell(
      onTap: () async {
        Navigator.of(context).pop();
        await item.onTap();
      },
      child: SizedBox(
        height: _BookContextMenuOverlay._itemHeight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 18, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Icon(item.icon, color: color, size: 23),
            ],
          ),
        ),
      ),
    );
  }
}
