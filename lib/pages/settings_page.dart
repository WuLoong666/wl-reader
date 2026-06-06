import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../widgets/anime_background.dart';
import '../widgets/magic_gradient_card.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _defaultFontSize = 18.0;
  static const _defaultLineHeight = 1.6;
  static const _defaultPageVerticalPadding = 32.0;
  static const _defaultPageHorizontalPadding = 32.0;
  static const _minLineHeight = 1.2;
  static const _maxLineHeight = 2.2;
  static const _minPageVerticalPadding = 16.0;
  static const _maxPageVerticalPadding = 80.0;
  static const _minPageHorizontalPadding = 16.0;
  static const _maxPageHorizontalPadding = 64.0;

  double _fontSize = _defaultFontSize;
  double _lineHeight = _defaultLineHeight;
  double _pageVerticalPadding = _defaultPageVerticalPadding;
  double _pageHorizontalPadding = _defaultPageHorizontalPadding;
  bool _nightMode = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return AnimeBackground(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                const _SettingsHeader(),
                const SizedBox(height: AppSpacing.lg),
                _SettingsSection(
                  title: '阅读排版',
                  icon: Icons.tune,
                  children: [
                    _SliderSettingTile(
                      title: '默认字号',
                      valueText: _fontSize.toStringAsFixed(0),
                      value: _fontSize,
                      min: 14,
                      max: 26,
                      divisions: 12,
                      onChanged: (value) => _save(fontSize: value),
                    ),
                    _SliderSettingTile(
                      title: '默认行间距',
                      valueText: _lineHeight.toStringAsFixed(1),
                      value: _lineHeight,
                      min: _minLineHeight,
                      max: _maxLineHeight,
                      divisions: 10,
                      onChanged: (value) => _save(lineHeight: value),
                    ),
                    _SliderSettingTile(
                      title: '默认上下边距',
                      valueText: _pageVerticalPadding.toStringAsFixed(0),
                      value: _pageVerticalPadding,
                      min: _minPageVerticalPadding,
                      max: _maxPageVerticalPadding,
                      divisions:
                          ((_maxPageVerticalPadding - _minPageVerticalPadding) /
                                  4)
                              .round(),
                      onChanged: (value) => _save(pageVerticalPadding: value),
                    ),
                    _SliderSettingTile(
                      title: '默认左右边距',
                      valueText: _pageHorizontalPadding.toStringAsFixed(0),
                      value: _pageHorizontalPadding,
                      min: _minPageHorizontalPadding,
                      max: _maxPageHorizontalPadding,
                      divisions: ((_maxPageHorizontalPadding -
                                  _minPageHorizontalPadding) /
                              4)
                          .round(),
                      onChanged: (value) => _save(pageHorizontalPadding: value),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _SettingsSection(
                  title: '阅读主题',
                  icon: Icons.auto_awesome,
                  children: [
                    _ThemePreviewCard(nightMode: _nightMode),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('夜间模式'),
                      subtitle: const Text('阅读页默认使用柔和暗色背景'),
                      value: _nightMode,
                      onChanged: (value) => _save(nightMode: value),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    setState(() {
      _fontSize = preferences.getDouble('reader_font_size') ?? _defaultFontSize;
      _lineHeight =
          (preferences.getDouble('reader_line_height') ?? _defaultLineHeight)
              .clamp(_minLineHeight, _maxLineHeight)
              .toDouble();
      _pageVerticalPadding =
          (preferences.getDouble('reader_page_vertical_padding') ??
                  _defaultPageVerticalPadding)
              .clamp(_minPageVerticalPadding, _maxPageVerticalPadding)
              .toDouble();
      _pageHorizontalPadding =
          (preferences.getDouble('reader_page_horizontal_padding') ??
                  _defaultPageHorizontalPadding)
              .clamp(_minPageHorizontalPadding, _maxPageHorizontalPadding)
              .toDouble();
      _nightMode = preferences.getBool('reader_night_mode') ?? false;
    });
  }

  Future<void> _save({
    double? fontSize,
    double? lineHeight,
    double? pageVerticalPadding,
    double? pageHorizontalPadding,
    bool? nightMode,
  }) async {
    setState(() {
      _fontSize = fontSize ?? _fontSize;
      _lineHeight = (lineHeight ?? _lineHeight)
          .clamp(_minLineHeight, _maxLineHeight)
          .toDouble();
      _pageVerticalPadding = (pageVerticalPadding ?? _pageVerticalPadding)
          .clamp(_minPageVerticalPadding, _maxPageVerticalPadding)
          .toDouble();
      _pageHorizontalPadding = (pageHorizontalPadding ?? _pageHorizontalPadding)
          .clamp(_minPageHorizontalPadding, _maxPageHorizontalPadding)
          .toDouble();
      _nightMode = nightMode ?? _nightMode;
    });

    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble('reader_font_size', _fontSize);
    await preferences.setDouble('reader_line_height', _lineHeight);
    await preferences.setDouble(
      'reader_page_vertical_padding',
      _pageVerticalPadding,
    );
    await preferences.setDouble(
      'reader_page_horizontal_padding',
      _pageHorizontalPadding,
    );
    await preferences.setBool('reader_night_mode', _nightMode);
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader();

  @override
  Widget build(BuildContext context) {
    return MagicGradientCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '设置',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppColors.deepPurple,
                        fontWeight: FontWeight.w900,
                        height: 1.08,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '乌龙茶书页的阅读手感',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.teaAmberDeep,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.64),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Icon(
                Icons.menu_book_outlined,
                color: AppColors.deepPurple,
                size: 30,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.parchment.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
        boxShadow: AppShadows.soft,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.teaAmberDeep),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _SliderSettingTile extends StatelessWidget {
  const _SliderSettingTile({
    required this.title,
    required this.valueText,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String title;
  final String valueText;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.cream.withValues(alpha: 0.76),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.line.withValues(alpha: 0.72)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.sakuraMist,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      child: Text(
                        valueText,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppColors.deepPurple,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                  ),
                ],
              ),
              Slider(
                min: min,
                max: max,
                divisions: divisions,
                label: valueText,
                value: value,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemePreviewCard extends StatelessWidget {
  const _ThemePreviewCard({required this.nightMode});

  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    final colors = nightMode
        ? AppColors.purpleGradient
        : const [
            AppColors.cream,
            AppColors.sakuraMist,
            AppColors.lavenderMist,
          ];

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.68)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            const Icon(
              Icons.auto_stories_outlined,
              color: AppColors.teaAmberDeep,
              size: 28,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                nightMode ? '夜间阅读' : '日间阅读',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: nightMode ? AppColors.parchment : AppColors.ink,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            const Icon(
              Icons.auto_awesome,
              color: AppColors.star,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
