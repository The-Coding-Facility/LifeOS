import 'model.dart';

/// Abschnitt beim Abspielen eines Plans.
enum PlaybackPhase { work, rest, done }

/// Abspielen eines Trainingsplans als reine Zustandsmaschine (ohne Uhr):
/// Übung → Ruhe → nächste Übung … ; nach der letzten Übung keine Ruhe.
/// Die Oberfläche ruft [tick] mit der vergangenen Zeit auf.
class TrainingPlayback {
  TrainingPlayback(this.steps) {
    _enter(0, PlaybackPhase.work);
  }

  final List<PlanStep> steps;

  var _index = 0;
  var _phase = PlaybackPhase.work;
  var _remaining = Duration.zero;
  var _paused = false;

  int get stepIndex => _index;
  PlaybackPhase get phase => _phase;
  Duration get remaining => _remaining;
  bool get paused => _paused;
  bool get isDone => _phase == PlaybackPhase.done;

  PlanStep? get currentStep => isDone || steps.isEmpty ? null : steps[_index];

  /// Ohne Vorgabezeit wartet die Übung auf [next].
  bool get waitsForUser => _phase == PlaybackPhase.work && (currentStep?.seconds ?? 0) == 0;

  void _enter(int index, PlaybackPhase phase) {
    if (index >= steps.length) {
      _phase = PlaybackPhase.done;
      _remaining = Duration.zero;
      return;
    }
    _index = index;
    _phase = phase;
    final step = steps[index];
    _remaining = Duration(seconds: phase == PlaybackPhase.work ? step.seconds : step.restSeconds);
  }

  /// Geht zum nächsten Abschnitt. Gibt `true` zurück, wenn sich etwas
  /// geändert hat (für den Wechselton).
  bool next() {
    if (isDone) return false;
    if (_phase == PlaybackPhase.work) {
      final isLast = _index == steps.length - 1;
      if (!isLast && steps[_index].restSeconds > 0) {
        _enter(_index, PlaybackPhase.rest);
      } else {
        _enter(_index + 1, PlaybackPhase.work);
      }
    } else {
      _enter(_index + 1, PlaybackPhase.work);
    }
    return true;
  }

  /// Zurück zum Anfang der aktuellen bzw. vorigen Übung.
  void previous() {
    if (steps.isEmpty) return;
    if (isDone) {
      _enter(steps.length - 1, PlaybackPhase.work);
    } else if (_phase == PlaybackPhase.rest) {
      _enter(_index, PlaybackPhase.work);
    } else {
      _enter(_index > 0 ? _index - 1 : 0, PlaybackPhase.work);
    }
  }

  void togglePause() => _paused = !_paused;

  /// Zieht [elapsed] ab und wechselt bei Ablauf. Gibt `true` zurück, wenn
  /// ein Wechsel stattfand.
  bool tick(Duration elapsed) {
    if (_paused || isDone || waitsForUser) return false;
    var left = elapsed;
    var changed = false;
    while (left > Duration.zero && !isDone && !waitsForUser) {
      if (left < _remaining) {
        _remaining -= left;
        return changed;
      }
      left -= _remaining;
      next();
      changed = true;
    }
    return changed;
  }
}
