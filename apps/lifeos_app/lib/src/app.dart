import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:lifeos_design_system/lifeos_design_system.dart';
import 'package:lifeos_security/lifeos_security.dart';

import 'router.dart';

/// Wurzel der App: Theme, Router, Inaktivitäts-Sperre, Sichtschutz.
class LifeosApp extends StatefulWidget {
  const LifeosApp({super.key, required this.lock, this.onResume});

  final AppLockController lock;

  /// Wird aufgerufen, wenn die App wieder in den Vordergrund kommt
  /// (z. B. um sofort zu synchronisieren).
  final VoidCallback? onResume;

  @override
  State<LifeosApp> createState() => _LifeosAppState();
}

class _LifeosAppState extends State<LifeosApp> {
  late final GoRouter _router = buildRouter(widget.lock);
  late final AppLifecycleListener _lifecycle;

  /// Verdeckt den Inhalt in der App-Übersicht von Android und iOS.
  bool _obscured = false;

  static bool get _isMobile =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycleChange);
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  bool _onKey(KeyEvent event) {
    widget.lock.registerActivity();
    return false;
  }

  void _onLifecycleChange(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.lock.onForeground();
      widget.onResume?.call();
    }
    if (_isMobile) {
      setState(() => _obscured = state != AppLifecycleState.resumed);
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _lifecycle.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'LifeOS',
      debugShowCheckedModeBanner: false,
      theme: buildLifeosTheme(Brightness.light),
      darkTheme: buildLifeosTheme(Brightness.dark),
      // Deutsche Datumsauswahl, Montag als Wochenbeginn.
      locale: const Locale('de', 'DE'),
      supportedLocales: const [Locale('de', 'DE')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: _router,
      builder: (context, child) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => widget.lock.registerActivity(),
        child: Stack(
          children: [
            child ?? const SizedBox.shrink(),
            if (_obscured) const Positioned.fill(child: _PrivacyCover()),
          ],
        ),
      ),
    );
  }
}

class _PrivacyCover extends StatelessWidget {
  const _PrivacyCover();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surface,
      child: Center(child: Icon(Icons.lock_outline, size: 56, color: scheme.primary)),
    );
  }
}
