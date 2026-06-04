# WL Reader

一个使用 Flutter + Dart 搭建的跨平台轻小说阅读器 MVP，目标平台为 Android 手机、Android 平板和 Windows 桌面端。

## 当前 MVP 功能

- 书库首页
- TXT / EPUB 本地导入
- 自动复制原文件到 App 本地目录
- TXT 自动章节识别
- EPUB 基础元数据、封面和章节解析
- SQLite 持久化书籍、章节和阅读进度
- 阅读页章节显示、上一章 / 下一章、字号调整、夜间模式
- 手机、平板、Windows 书库网格响应式布局

## 运行

如果网络无法访问 Google 存储，建议在当前 PowerShell 会话里先设置 Flutter 镜像：

```powershell
$env:FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
$env:PUB_HOSTED_URL="https://pub.flutter-io.cn"
```

安装依赖：

```powershell
flutter pub get
```

本仓库已生成 Android 和 Windows 平台模板。如果以后需要重新修复平台模板，可以执行：

```powershell
flutter create --platforms=android,windows .
flutter pub get
```

运行 Windows 桌面端：

```powershell
flutter run -d windows
```

也可以运行已构建的 release 程序：

```powershell
flutter build windows
.\build\windows\x64\runner\Release\wl_reader.exe
```

Android 模拟器：

```powershell
flutter doctor -v
flutter emulators --launch <emulator_id>
flutter run -d <device_id>
```

如果 `flutter doctor -v` 提示 `No Android SDK found`，需要先安装 Android Studio，并在首次启动时安装 Android SDK。若 SDK 安装在自定义位置，执行：

```powershell
flutter config --android-sdk "C:\path\to\Android\Sdk"
```

查看设备：

```powershell
flutter devices
```

Windows SQLite 初始化已在 `lib/main.dart` 中处理：Windows 下会调用 `sqfliteFfiInit()` 并把 `databaseFactory` 设置为 `databaseFactoryFfi`。

## 已验证

```powershell
flutter pub get
flutter analyze
flutter test
flutter build windows
```

Windows release 启动 smoke test 已通过。Android 构建当前停在本机缺少 Android SDK：

```text
[!] No Android SDK found. Try setting the ANDROID_HOME environment variable.
```

## 后续扩展方向

- EPUB 目录层级、注释、图片和更完整排版
- 阅读页双栏模式
- 更细的阅读进度统计
- 书籍搜索与标签
- 设置项迁移到 `reading_setting` 表并做主题预设
