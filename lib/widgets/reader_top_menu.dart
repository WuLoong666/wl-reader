import 'package:flutter/material.dart';

class ReaderTopMenu extends StatelessWidget {
  const ReaderTopMenu({
    super.key,
    required this.title,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onBack,
    required this.onMore,
  });

  final String title;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onBack;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor.withAlpha(235),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              IconButton(
                tooltip: '返回',
                color: foregroundColor,
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foregroundColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: '更多',
                color: foregroundColor,
                onPressed: onMore,
                icon: const Icon(Icons.more_horiz),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
