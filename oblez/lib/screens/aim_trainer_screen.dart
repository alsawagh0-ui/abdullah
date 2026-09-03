import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/comedy_lines.dart';
import '../logic/aim_trainer_logic.dart';
import '../logic/energy_logic.dart';
import '../logic/ping_logic.dart';
import '../models/aim_target.dart';
import '../models/player_state.dart';
import 'game_over_screen.dart';

/// اللعبة المصغرة: أهداف عشوائية تظهر وتختفي، النقر السريع يسجل نقاط
/// وكومبو. بنق عالي (شبكة ضعيفة) يلغي بعض النقرات، وطاقة واطية تهز الهدف.
class AimTrainerScreen extends StatefulWidget {
  const AimTrainerScreen({super.key});

  @override
  State<AimTrainerScreen> createState() => _AimTrainerScreenState();
}

class _AimTrainerScreenState extends State<AimTrainerScreen> {
  static const _sessionSeconds = 30;

  /// نسبة حجم الهدف من أصغر بُعد بمنطقة اللعب، بحدود دنيا/عليا — على
  /// موبايل ضيق يقرب من الحد الأدنى، وعلى نافذة ديسكتوب واسعة يكبر
  /// بدل ما يضل بحجم إصبع ثابت بمنتصف شاشة كبيرة.
  static const _targetSizeRatio = 0.09;
  static const _minTargetSize = 44.0;
  static const _maxTargetSize = 110.0;

  double _targetSizeFor(double width, double height) {
    final base = min(width, height) * _targetSizeRatio;
    return base.clamp(_minTargetSize, _maxTargetSize).toDouble();
  }

  final _logic = AimTrainerLogic();
  final _pingLogic = PingLogic();
  final _random = Random();

  int _nextId = 0;
  AimTarget? _current;
  int _score = 0;
  int _combo = 0;
  int _secondsLeft = _sessionSeconds;
  String? _feedback;
  bool _feedbackIsPositive = false;

  Timer? _sessionTimer;
  Timer? _targetTimer;
  Timer? _jitterTimer;
  Offset _jitter = Offset.zero;

  late final PlayerState _player;
  late final bool _lowEnergy;

  @override
  void initState() {
    super.initState();
    _player = context.read<PlayerState>();
    _lowEnergy = EnergyLogic.isLow(_player.energy);

    _sessionTimer = Timer.periodic(const Duration(seconds: 1), _tickSession);
    if (_lowEnergy) {
      _jitterTimer =
          Timer.periodic(const Duration(milliseconds: 120), _tickJitter);
    }
    _spawnTarget();
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _targetTimer?.cancel();
    _jitterTimer?.cancel();
    super.dispose();
  }

  void _tickSession(Timer timer) {
    if (_secondsLeft <= 1) {
      timer.cancel();
      _endSession();
      return;
    }
    setState(() => _secondsLeft -= 1);
  }

  void _tickJitter(Timer timer) {
    final j = _logic.jitterOffset();
    setState(() => _jitter = Offset(j.dx, j.dy));
  }

  void _spawnTarget() {
    _targetTimer?.cancel();
    final pos = _logic.randomPosition();
    final lifetime = _logic.targetLifetime(_combo);
    final target = AimTarget(
      id: _nextId++,
      x: pos.x,
      y: pos.y,
      spawnedAt: DateTime.now(),
      lifetime: lifetime,
    );
    setState(() {
      _current = target;
    });
    _targetTimer = Timer(lifetime, _onTargetMissed);
  }

  String _randomLine(List<String> lines) => lines[_random.nextInt(lines.length)];

  void _onTargetMissed() {
    if (!mounted) return;
    setState(() {
      _combo = 0;
      _current = null;
      _feedback = _randomLine(ComedyLines.rankDownTaunts);
      _feedbackIsPositive = false;
    });
    _spawnTarget();
  }

  void _onTargetTapped() {
    if (_current == null) return;

    if (_pingLogic.rollLagSpike(_player.networkLevel)) {
      setState(() {
        _feedback = _randomLine(ComedyLines.lagSpikeLines);
        _feedbackIsPositive = false;
      });
      return;
    }

    _targetTimer?.cancel();
    final newCombo = _combo + 1;
    setState(() {
      _score += _logic.scoreForHit(_combo);
      _combo = newCombo;
      if (newCombo % 5 == 0) {
        _feedback = _randomLine(ComedyLines.hypeComments);
        _feedbackIsPositive = true;
      } else {
        _feedback = null;
      }
    });
    _spawnTarget();
  }

  void _endSession() {
    _targetTimer?.cancel();
    _jitterTimer?.cancel();
    setState(() => _current = null);

    final result = _player.recordAimTrainerResult(_score);

    if (result.kicked) {
      final reason = _randomLine(ComedyLines.kickedReasons);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => GameOverScreen(
            reason: reason,
            kind: GameOverKind.kickedFromTeam,
          ),
        ),
        (route) => false,
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('انتهت الجولة! ⏱'),
        content: Text(
          'نقاطك: $_score\nمكافأة: ${result.reward}\$\nنقاط رانك: +$_score',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('رجوع للغرفة'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Aim Trainer — $_secondsLeft ث')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('النقاط: $_score'),
                Text('كومبو: $_combo'),
              ],
            ),
          ),
          SizedBox(
            height: 20,
            child: _feedback == null
                ? null
                : Text(
                    _feedback!,
                    style: TextStyle(
                      color: _feedbackIsPositive
                          ? Colors.greenAccent
                          : Colors.redAccent,
                    ),
                  ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final target = _current;
                if (target == null) return const SizedBox.shrink();

                final w = constraints.maxWidth;
                final h = constraints.maxHeight;
                final targetSize = _targetSizeFor(w, h);

                final dx = _lowEnergy ? _jitter.dx * w : 0.0;
                final dy = _lowEnergy ? _jitter.dy * h : 0.0;

                final left = (target.x * w - targetSize / 2 + dx)
                    .clamp(0, w - targetSize);
                final top = (target.y * h - targetSize / 2 + dy)
                    .clamp(0, h - targetSize);

                return Stack(
                  children: [
                    Positioned(
                      left: left.toDouble(),
                      top: top.toDouble(),
                      child: GestureDetector(
                        onTap: _onTargetTapped,
                        child: Container(
                          width: targetSize,
                          height: targetSize,
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
