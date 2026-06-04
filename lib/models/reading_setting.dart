class ReadingSetting {
  const ReadingSetting({
    this.id = 1,
    required this.fontSize,
    required this.lineHeight,
    required this.themeMode,
    required this.backgroundColor,
  });

  final int id;
  final double fontSize;
  final double lineHeight;
  final String themeMode;
  final String backgroundColor;

  static const defaults = ReadingSetting(
    fontSize: 18,
    lineHeight: 1.7,
    themeMode: 'light',
    backgroundColor: '#FFFDF7',
  );

  ReadingSetting copyWith({
    int? id,
    double? fontSize,
    double? lineHeight,
    String? themeMode,
    String? backgroundColor,
  }) {
    return ReadingSetting(
      id: id ?? this.id,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      themeMode: themeMode ?? this.themeMode,
      backgroundColor: backgroundColor ?? this.backgroundColor,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'font_size': fontSize,
      'line_height': lineHeight,
      'theme_mode': themeMode,
      'background_color': backgroundColor,
    };
  }

  factory ReadingSetting.fromMap(Map<String, Object?> map) {
    return ReadingSetting(
      id: map['id'] as int? ?? 1,
      fontSize: (map['font_size'] as num?)?.toDouble() ?? 18,
      lineHeight: (map['line_height'] as num?)?.toDouble() ?? 1.7,
      themeMode: map['theme_mode'] as String? ?? 'light',
      backgroundColor: map['background_color'] as String? ?? '#FFFDF7',
    );
  }
}
