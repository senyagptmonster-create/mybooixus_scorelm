import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../app/brand.dart';
import '../app/store.dart';
import '../app/theme.dart';

/// Agility drills walked step by step, with the cone layout drawn above the
/// instruction so you can set the grid up before you start.
class ProductApp extends StatefulWidget {
  const ProductApp({super.key});

  @override
  State<ProductApp> createState() => _ProductAppState();
}

class _Drill {
  final String id;
  final String name;
  final String gear;
  final String focus;
  final String layout;
  final List<String> steps;

  const _Drill({
    required this.id,
    required this.name,
    required this.gear,
    required this.focus,
    required this.layout,
    required this.steps,
  });

  static _Drill? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final name = raw['name'];
    if (id is! String || id.isEmpty) return null;
    if (name is! String || name.isEmpty) return null;
    final rawSteps = raw['steps'];
    if (rawSteps is! List) return null;
    final steps = <String>[];
    for (final s in rawSteps) {
      if (s is String && s.isNotEmpty) steps.add(s);
    }
    if (steps.isEmpty) return null;
    String str(Object? v) => v is String ? v : '';
    return _Drill(
      id: id,
      name: name,
      gear: str(raw['gear']),
      focus: str(raw['focus']),
      layout: str(raw['layout']),
      steps: steps,
    );
  }
}

class _ProductAppState extends State<ProductApp> {
  static const _kDone = 'ag_done';

  List<_Drill> _drills = const [];
  Set<String> _done = <String>{};
  bool _loading = true;

  _Drill? _active;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var drills = <_Drill>[];
    try {
      final raw = await rootBundle.loadString('assets/json/content.json');
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded['drills'] is List) {
        for (final d in decoded['drills'] as List) {
          final parsed = _Drill.tryParse(d);
          if (parsed != null) drills.add(parsed);
        }
      }
    } catch (_) {
      drills = <_Drill>[];
    }
    final done = await Store.getStringSet(_kDone);
    if (!mounted) return;
    setState(() {
      _drills = drills;
      _done = done;
      _loading = false;
    });
  }

  Future<void> _markDone(_Drill drill) async {
    final next = Set<String>.of(_done)..add(drill.id);
    setState(() {
      _done = next;
      _active = null;
    });
    await Store.setStringSet(_kDone, next);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: cBg,
        body: Center(child: CircularProgressIndicator(color: cAccent)),
      );
    }
    if (_drills.isEmpty) {
      return Scaffold(
        backgroundColor: cBg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Text(
              'Drill pack unavailable.',
              textAlign: TextAlign.center,
              style: AppTheme.text(15, color: AppTheme.textSecondary),
            ),
          ),
        ),
      );
    }
    return _active == null ? _buildList() : _buildStepper(_active!);
  }

  Widget _buildList() {
    return Scaffold(
      backgroundColor: cBg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
            Text(
              kProductTitle.toUpperCase(),
              style: TextStyle(
                fontFamily: kDisplayFont,
                fontSize: 26,
                letterSpacing: 1.5,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              kProductTagline,
              style: AppTheme.text(13.5, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            for (final drill in _drills) ...[
              _drillRow(drill),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _drillRow(_Drill drill) {
    final done = _done.contains(drill.id);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() {
          _active = drill;
          _step = 0;
        }),
        borderRadius: AppTheme.radius,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: AppTheme.radius,
            color: AppTheme.surface,
            border: Border.all(
              color: done ? cAccent : AppTheme.border,
              width: done ? 1.6 : 1.1,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 54,
                height: 54,
                child: CustomPaint(
                  painter: _LayoutPainter(
                    layout: drill.layout,
                    dot: cAlt,
                    line: AppTheme.border,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      drill.name,
                      style: AppTheme.text(
                        16,
                        weight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        drill.focus,
                        drill.gear,
                      ].where((s) => s.isNotEmpty).join('  ·  '),
                      style: AppTheme.text(
                        12.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (done)
                Icon(Icons.check_circle_rounded, color: cAccent, size: 20)
              else
                Icon(Icons.chevron_right_rounded, color: cAlt, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepper(_Drill drill) {
    final isLast = _step >= drill.steps.length - 1;

    return Scaffold(
      backgroundColor: cBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => setState(() => _active = null),
                    icon: const Icon(Icons.close_rounded),
                    color: AppTheme.textSecondary,
                  ),
                  Expanded(
                    child: Text(
                      drill.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.text(
                        15,
                        weight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    '${_step + 1}/${drill.steps.length}',
                    style: AppTheme.text(13, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                children: [
                  Container(
                    height: 190,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: AppTheme.radius,
                      color: AppTheme.surface,
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: CustomPaint(
                      painter: _LayoutPainter(
                        layout: drill.layout,
                        dot: cAlt,
                        line: AppTheme.border,
                        accent: cAccent,
                      ),
                      size: Size.infinite,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      for (var i = 0; i < drill.steps.length; i++)
                        Expanded(
                          child: Container(
                            height: 4,
                            margin: EdgeInsets.only(
                              right: i == drill.steps.length - 1 ? 0 : 4,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              color: i <= _step ? cAccent : AppTheme.border,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'STEP ${_step + 1}',
                    style: AppTheme.text(
                      11.5,
                      color: cAlt,
                      weight: FontWeight.w700,
                      spacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    drill.steps[_step],
                    style: AppTheme.text(
                      18,
                      color: AppTheme.textPrimary,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Row(
                children: [
                  if (_step > 0) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _step--),
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () => isLast
                          ? _markDone(drill)
                          : setState(() => _step++),
                      child: Text(isLast ? 'Mark complete' : 'Next step'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LayoutPainter extends CustomPainter {
  final String layout;
  final Color dot;
  final Color line;
  final Color? accent;

  const _LayoutPainter({
    required this.layout,
    required this.dot,
    required this.line,
    this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cone = Paint()..color = dot;
    final path = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = accent ?? line;

    void marker(double x, double y) =>
        canvas.drawCircle(Offset(x, y), w * 0.035 + 2, cone);

    switch (layout) {
      case 'ladder':
        final rungs = 6;
        final left = w * 0.32;
        final right = w * 0.68;
        canvas.drawLine(Offset(left, h * 0.08), Offset(left, h * 0.92), path);
        canvas.drawLine(
          Offset(right, h * 0.08),
          Offset(right, h * 0.92),
          path,
        );
        for (var i = 0; i <= rungs; i++) {
          final y = h * 0.08 + (h * 0.84) * i / rungs;
          canvas.drawLine(Offset(left, y), Offset(right, y), path);
        }
      case 't':
        marker(w * 0.5, h * 0.88);
        marker(w * 0.5, h * 0.3);
        marker(w * 0.18, h * 0.3);
        marker(w * 0.82, h * 0.3);
        canvas.drawLine(
          Offset(w * 0.5, h * 0.88),
          Offset(w * 0.5, h * 0.3),
          path,
        );
        canvas.drawLine(
          Offset(w * 0.18, h * 0.3),
          Offset(w * 0.82, h * 0.3),
          path,
        );
      case 'box':
        marker(w * 0.2, h * 0.2);
        marker(w * 0.8, h * 0.2);
        marker(w * 0.8, h * 0.8);
        marker(w * 0.2, h * 0.8);
        canvas.drawRect(
          Rect.fromLTRB(w * 0.2, h * 0.2, w * 0.8, h * 0.8),
          path,
        );
      case 'line':
      default:
        marker(w * 0.15, h * 0.5);
        marker(w * 0.5, h * 0.5);
        marker(w * 0.85, h * 0.5);
        canvas.drawLine(
          Offset(w * 0.15, h * 0.5),
          Offset(w * 0.85, h * 0.5),
          path,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _LayoutPainter old) =>
      old.layout != layout ||
      old.dot != dot ||
      old.line != line ||
      old.accent != accent;
}
