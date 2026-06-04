import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/reading_progress_service.dart';

class ImportPage extends StatelessWidget {
  const ImportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final importing = context.watch<LibraryStore>().importing;

    return Scaffold(
      appBar: AppBar(title: const Text('导入')),
      body: Center(
        child: FilledButton.icon(
          onPressed: importing ? null : () => _import(context),
          icon: importing
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.file_open_outlined),
          label: const Text('选择 TXT / EPUB'),
        ),
      ),
    );
  }

  Future<void> _import(BuildContext context) async {
    try {
      final book = await context.read<LibraryStore>().importBook();
      if (book == null || !context.mounted) {
        return;
      }
      Navigator.of(context).pop(book);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }
}
