import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  double _fontSize = 18;
  double _lineHeight = 1.7;
  bool _nightMode = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            '设置',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 20),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('默认字号'),
            subtitle: Slider(
              min: 14,
              max: 26,
              divisions: 12,
              label: _fontSize.toStringAsFixed(0),
              value: _fontSize,
              onChanged: (value) => _save(fontSize: value),
            ),
            trailing: Text(_fontSize.toStringAsFixed(0)),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('默认行高'),
            subtitle: Slider(
              min: 1.3,
              max: 2.2,
              divisions: 9,
              label: _lineHeight.toStringAsFixed(1),
              value: _lineHeight,
              onChanged: (value) => _save(lineHeight: value),
            ),
            trailing: Text(_lineHeight.toStringAsFixed(1)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('夜间模式'),
            value: _nightMode,
            onChanged: (value) => _save(nightMode: value),
          ),
        ],
      ),
    );
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    setState(() {
      _fontSize = preferences.getDouble('reader_font_size') ?? 18;
      _lineHeight = preferences.getDouble('reader_line_height') ?? 1.7;
      _nightMode = preferences.getBool('reader_night_mode') ?? false;
    });
  }

  Future<void> _save({
    double? fontSize,
    double? lineHeight,
    bool? nightMode,
  }) async {
    setState(() {
      _fontSize = fontSize ?? _fontSize;
      _lineHeight = lineHeight ?? _lineHeight;
      _nightMode = nightMode ?? _nightMode;
    });

    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble('reader_font_size', _fontSize);
    await preferences.setDouble('reader_line_height', _lineHeight);
    await preferences.setBool('reader_night_mode', _nightMode);
  }
}
