import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'pages/settings_page.dart';
import 'pages/shelf_page.dart';
import 'services/reading_progress_service.dart';
import 'widgets/bottom_nav_bar.dart';

class WlReaderApp extends StatelessWidget {
  const WlReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LibraryStore()..loadLibrary(),
      child: MaterialApp(
        title: 'WL Reader',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F6F6D)),
          useMaterial3: true,
        ),
        home: const HomeShell(),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          ShelfPage(),
          _SearchPlaceholderPage(),
          SettingsPage(),
        ],
      ),
      bottomNavigationBar: ReaderBottomNavBar(
        currentIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
      ),
    );
  }
}

class _SearchPlaceholderPage extends StatelessWidget {
  const _SearchPlaceholderPage();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Text(
          '搜索',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
  }
}
