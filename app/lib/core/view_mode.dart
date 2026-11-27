import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'habits_view';

/// Cómo se muestran los hábitos en la pantalla principal:
/// tarjetas bajas (la primera y la vista por defecto), tarjetas anchas (una por
/// fila) y lista. El orden del enum es el del selector.
/// Una preferencia guardada antes con otro nombre (la vista de tarjetas altas,
/// que ya no existe) cae en la vista por defecto.
enum HabitsView { compact, wide, list }

/// Vista elegida por el usuario; se recuerda entre sesiones.
class ViewModeNotifier extends Notifier<HabitsView> {
  @override
  HabitsView build() {
    _load();
    return HabitsView.compact;
  }

  Future<void> _load() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString(
        _prefsKey,
      );
      final view = HabitsView.values.where((v) => v.name == saved).firstOrNull;
      if (view != null) state = view;
    } catch (_) {
      // Sin almacenamiento: se queda en la vista por defecto.
    }
  }

  Future<void> set(HabitsView view) async {
    state = view;
    try {
      await (await SharedPreferences.getInstance()).setString(
        _prefsKey,
        view.name,
      );
    } catch (_) {
      // La vista sigue cambiando aunque no se pueda guardar.
    }
  }
}

final viewModeProvider = NotifierProvider<ViewModeNotifier, HabitsView>(
  ViewModeNotifier.new,
);
