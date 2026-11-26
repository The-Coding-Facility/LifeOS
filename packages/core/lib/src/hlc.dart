import 'dart:math' as math;

/// Zeitstempel einer Hybrid Logical Clock (HLC).
///
/// Besteht aus Systemzeit in Millisekunden, einem Zähler und der Geräte-ID.
/// Eine Ursache hat immer einen kleineren Zeitstempel als ihre Folge, auch
/// wenn die Uhr eines Geräts falsch geht. Bei Gleichstand entscheidet die
/// Geräte-ID, sodass alle Geräte dieselbe Reihenfolge sehen.
final class Hlc implements Comparable<Hlc> {
  const Hlc(this.millis, this.counter, this.nodeId)
      : assert(millis >= 0),
        assert(counter >= 0 && counter <= maxCounter);

  /// Höchster Zählerwert, danach rückt die Millisekunde vor.
  static const int maxCounter = 0xFFFF;

  static const int _millisWidth = 15;
  static const int _counterWidth = 4;

  /// Physische Zeit in Millisekunden seit 1970 (UTC).
  final int millis;

  /// Logischer Zähler innerhalb derselben Millisekunde.
  final int counter;

  /// ID des Geräts, das den Zeitstempel erzeugt hat.
  final String nodeId;

  /// Textform fester Breite. Ihre alphabetische Reihenfolge entspricht
  /// [compareTo], daher kann sie direkt in SQL sortiert werden.
  String pack() => '${millis.toString().padLeft(_millisWidth, '0')}'
      '-${counter.toRadixString(16).padLeft(_counterWidth, '0')}'
      '-$nodeId';

  /// Liest die Textform aus [pack] wieder ein.
  static Hlc parse(String packed) {
    final first = packed.indexOf('-');
    final second = first < 0 ? -1 : packed.indexOf('-', first + 1);
    if (first != _millisWidth || second != first + 1 + _counterWidth) {
      throw FormatException('Ungültiger HLC-Zeitstempel', packed);
    }
    final millis = int.parse(packed.substring(0, first));
    final counter = int.parse(packed.substring(first + 1, second), radix: 16);
    final nodeId = packed.substring(second + 1);
    if (nodeId.isEmpty) {
      throw FormatException('HLC-Zeitstempel ohne Geräte-ID', packed);
    }
    return Hlc(millis, counter, nodeId);
  }

  @override
  int compareTo(Hlc other) {
    final byMillis = millis.compareTo(other.millis);
    if (byMillis != 0) return byMillis;
    final byCounter = counter.compareTo(other.counter);
    if (byCounter != 0) return byCounter;
    return nodeId.compareTo(other.nodeId);
  }

  bool operator <(Hlc other) => compareTo(other) < 0;

  bool operator >(Hlc other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) =>
      other is Hlc &&
      other.millis == millis &&
      other.counter == counter &&
      other.nodeId == nodeId;

  @override
  int get hashCode => Object.hash(millis, counter, nodeId);

  @override
  String toString() => pack();
}

/// Ein entfernter Zeitstempel liegt unplausibel weit in der Zukunft.
class ClockDriftException implements Exception {
  ClockDriftException(this.remote, this.localWallMillis, this.maxDrift);

  final Hlc remote;
  final int localWallMillis;
  final Duration maxDrift;

  @override
  String toString() => 'ClockDriftException: Der Zeitstempel $remote liegt mehr '
      'als ${maxDrift.inHours} h vor der lokalen Uhr ($localWallMillis ms).';
}

/// Erzeugt streng monoton steigende HLC-Zeitstempel für ein Gerät.
class HlcClock {
  HlcClock({
    required this.nodeId,
    Hlc? last,
    int Function()? wallClock,
    this.maxDrift = const Duration(hours: 24),
  })  : _wallClock = wallClock ?? _systemMillis,
        _last = last == null
            ? Hlc(0, 0, nodeId)
            : Hlc(last.millis, last.counter, nodeId);

  /// Geräte-ID, die in jeden Zeitstempel eingeht.
  final String nodeId;

  /// Größte erlaubte Abweichung eines entfernten Zeitstempels in die Zukunft.
  final Duration maxDrift;

  final int Function() _wallClock;
  Hlc _last;

  /// Zuletzt erzeugter oder empfangener Zeitstempel.
  Hlc get last => _last;

  static int _systemMillis() => DateTime.now().toUtc().millisecondsSinceEpoch;

  /// Zeitstempel für eine lokale Änderung.
  Hlc now() {
    final wall = _wallClock();
    _last = wall > _last.millis
        ? Hlc(wall, 0, nodeId)
        : _advance(_last.millis, _last.counter + 1);
    return _last;
  }

  /// Verarbeitet einen empfangenen Zeitstempel und liefert einen lokalen
  /// Zeitstempel, der nach beiden liegt.
  ///
  /// Wirft [ClockDriftException], wenn [remote] mehr als [maxDrift] in der
  /// Zukunft liegt.
  Hlc receive(Hlc remote) {
    final wall = _wallClock();
    if (remote.millis - wall > maxDrift.inMilliseconds) {
      throw ClockDriftException(remote, wall, maxDrift);
    }
    final localMillis = _last.millis;
    final maxMillis = math.max(wall, math.max(localMillis, remote.millis));

    final int counter;
    if (maxMillis == localMillis && maxMillis == remote.millis) {
      counter = math.max(_last.counter, remote.counter) + 1;
    } else if (maxMillis == localMillis) {
      counter = _last.counter + 1;
    } else if (maxMillis == remote.millis) {
      counter = remote.counter + 1;
    } else {
      counter = 0;
    }
    _last = _advance(maxMillis, counter);
    return _last;
  }

  Hlc _advance(int millis, int counter) => counter > Hlc.maxCounter
      ? Hlc(millis + 1, 0, nodeId)
      : Hlc(millis, counter, nodeId);
}
