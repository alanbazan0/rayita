import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/locale.dart';

/// Menú para elegir el idioma: automático, español o inglés.
class LanguageButton extends ConsumerWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(localeProvider)?.languageCode;
    final l = context.l10n;

    return PopupMenuButton<String>(
      tooltip: l.language,
      icon: const Icon(Icons.translate),
      initialValue: current ?? 'system',
      onSelected: (v) => ref
          .read(localeProvider.notifier)
          .set(v == 'system' ? null : Locale(v)),
      itemBuilder: (_) => [
        PopupMenuItem(value: 'system', child: Text(l.languageSystem)),
        const PopupMenuItem(value: 'es', child: Text('Español')),
        const PopupMenuItem(value: 'en', child: Text('English')),
      ],
    );
  }
}
