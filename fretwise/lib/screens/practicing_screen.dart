import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../theme.dart';

class PracticingScreen extends StatefulWidget {
  final AppTheme t;
  final void Function(String screen, {Map<String, dynamic>? props}) navigate;
  final String title;
  final String artist;
  final int bpm;
  final VoidCallback onOpenAI;

  const PracticingScreen({
    super.key,
    required this.t,
    required this.navigate,
    required this.title,
    required this.artist,
    required this.bpm,
    required this.onOpenAI,
  });

  @override
  State<PracticingScreen> createState() => _PracticingScreenState();
}

class _PracticingScreenState extends State<PracticingScreen> {
  int _seconds = 0;
  bool _running = true;
  bool _videoPlaying = false;
  bool _recording = false;
  String? _activePopup; // 'tuner' | 'metronome' | null
  bool _showStrumModal = true;

  // Metronome
  int _metroBpm = 80;
  bool _metroRunning = false;
  int _metroBeat = 0;
  Timer? _metroTimer;

  // Tuner
  double _tunerNeedle = 0;
  Timer? _tunerTimer;
  Timer? _sessionTimer;

  AppTheme get t => widget.t;

  @override
  void initState() {
    super.initState();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_running && mounted) setState(() => _seconds++);
    });
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _metroTimer?.cancel();
    _tunerTimer?.cancel();
    super.dispose();
  }

  void _startMetronome() {
    _metroTimer?.cancel();
    final ms = (60000 / _metroBpm).round();
    _metroTimer = Timer.periodic(Duration(milliseconds: ms), (_) {
      if (mounted) setState(() => _metroBeat = (_metroBeat + 1) % 4);
    });
  }

  void _stopMetronome() {
    _metroTimer?.cancel();
    _metroTimer = null;
  }

  void _startTuner() {
    _tunerTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (mounted) {
        setState(() => _tunerNeedle = sin(DateTime.now().millisecondsSinceEpoch / 800) * 18 +
            (Random().nextDouble() - 0.5) * 6);
      }
    });
  }

  void _stopTuner() {
    _tunerTimer?.cancel();
    _tunerTimer = null;
  }

  void _handleToolTap(String id) {
    setState(() {
      if (id == 'record') {
        _recording = !_recording;
        return;
      }
      if (_activePopup == id) {
        _activePopup = null;
        if (id == 'metronome') { _metroRunning = false; _stopMetronome(); }
        if (id == 'tuner') _stopTuner();
      } else {
        if (_activePopup == 'metronome') { _metroRunning = false; _stopMetronome(); }
        if (_activePopup == 'tuner') _stopTuner();
        _activePopup = id;
        if (id == 'tuner') _startTuner();
      }
    });
  }

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  static const _noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];

  String get _detectedNote => _noteNames[(_tunerNeedle.abs() / 3).round() % 12];
  int get _cents => (_tunerNeedle * 3.5).round();
  bool get _inTune => _cents.abs() < 8;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () { _running = false; widget.navigate('library'); },
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.arrow_back, size: 22, color: t.text),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(widget.title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: t.text)),
                  ),
                  Text(widget.artist, style: TextStyle(fontSize: 13, color: t.textSec)),
                ],
              ),
            ),

            // Timer
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: t.border),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4)],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SESSION TIME',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: t.textMuted, letterSpacing: 0.7)),
                        const SizedBox(height: 2),
                        Text(
                          _fmt(_seconds),
                          style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w900,
                            color: t.text,
                            letterSpacing: -2,
                            height: 1,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _running = !_running),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _running ? t.accent : t.surfaceAlt,
                          boxShadow: _running ? [BoxShadow(color: t.accent.withValues(alpha: 0.4), blurRadius: 20)] : null,
                        ),
                        child: Icon(
                          _running ? Icons.pause : Icons.play_arrow,
                          size: 22,
                          color: _running ? Colors.white : t.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Tools row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Row(
                children: [
                  Expanded(child: _ToolButton(id: 'tuner', label: 'Tuner', icon: Icons.graphic_eq, color: AppColors.blue, active: _activePopup == 'tuner', t: t, onTap: () => _handleToolTap('tuner'))),
                  const SizedBox(width: 10),
                  Expanded(child: _ToolButton(id: 'record', label: _recording ? 'Stop' : 'Record', icon: Icons.mic, color: AppColors.red, active: _recording, t: t, onTap: () => _handleToolTap('record'))),
                  const SizedBox(width: 10),
                  Expanded(child: _ToolButton(id: 'metronome', label: 'Metronome', icon: Icons.tune, color: AppColors.green, active: _activePopup == 'metronome', t: t, onTap: () => _handleToolTap('metronome'))),
                ],
              ),
            ),

            // Video
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: GestureDetector(
                onTap: () => setState(() => _videoPlaying = !_videoPlaying),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF2A2420), Color(0xFF1A1510)],
                              ),
                            ),
                          ),
                        ),
                        Center(
                          child: Container(
                            width: 52, height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.18),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
                            ),
                            child: Icon(
                              _videoPlaying ? Icons.pause : Icons.play_arrow,
                              size: 22, color: Colors.white,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0, left: 0, right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.75)],
                              ),
                            ),
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${widget.title} — Tutorial',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                                Text('${widget.artist} · Tap to ${_videoPlaying ? "pause" : "play"}',
                                    style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.65))),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Tool panel
            if (_activePopup != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: _activePopup == 'tuner' ? _TunerPanel(t: t, needle: _tunerNeedle, note: _detectedNote, cents: _cents, inTune: _inTune, onClose: () => _handleToolTap('tuner'))
                    : _MetronomePanel(
                        t: t,
                        bpm: _metroBpm,
                        running: _metroRunning,
                        beat: _metroBeat,
                        onBpmChange: (v) {
                          setState(() => _metroBpm = v);
                          if (_metroRunning) { _stopMetronome(); _startMetronome(); }
                        },
                        onToggle: () => setState(() {
                          _metroRunning = !_metroRunning;
                          _metroRunning ? _startMetronome() : _stopMetronome();
                        }),
                        onClose: () => _handleToolTap('metronome'),
                      ),
              ),

            const Spacer(),

            // Finish button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    _running = false;
                    widget.navigate('sessionComplete', props: {
                      'title': widget.title,
                      'artist': widget.artist,
                      'duration': _seconds,
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: t.border, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Finish Session',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: t.text)),
                ),
              ),
            ),
          ],
        ),

        // AI button
        Positioned(
          bottom: 84,
          right: 20,
          child: GestureDetector(
            onTap: widget.onOpenAI,
            child: Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A7A5E), Color(0xFF2EAD85)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [BoxShadow(color: const Color(0xFF1A7A5E).withValues(alpha: 0.45), blurRadius: 20)],
              ),
              child: const Icon(Icons.chat_bubble_outline, size: 22, color: Colors.white),
            ),
          ),
        ),

        // Strum modal
        if (_showStrumModal)
          GestureDetector(
            onTap: () => setState(() => _showStrumModal = false),
            child: Container(
              color: Colors.black.withValues(alpha: 0.45),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: GestureDetector(
                    onTap: () {},
                    child: Container(
                      decoration: BoxDecoration(
                        color: t.surface,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 48),
                          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8),
                        ],
                      ),
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Align(
                            alignment: Alignment.topRight,
                            child: GestureDetector(
                              onTap: () => setState(() => _showStrumModal = false),
                              child: Container(
                                width: 30, height: 30,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: t.surfaceAlt),
                                child: Center(child: Text('✕', style: TextStyle(fontSize: 16, color: t.textMuted))),
                              ),
                            ),
                          ),
                          Container(
                            width: 52, height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                colors: [t.accent.withValues(alpha: 0.13), t.accent.withValues(alpha: 0.27)],
                              ),
                            ),
                            child: Icon(Icons.mic, size: 26, color: t.accent),
                          ),
                          const SizedBox(height: 16),
                          Text("We'll listen to you strum",
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: t.text, fontFamily: 'Georgia', height: 1.2)),
                          const SizedBox(height: 8),
                          Text(
                            "Fretwise uses your microphone to give real-time feedback on your playing. Make sure your guitar is in tune and you're in a quiet spot.",
                            style: TextStyle(fontSize: 14, color: t.textSec, height: 1.6),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => setState(() => _showStrumModal = false),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: t.accent,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text("Got it, let's play",
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: () => setState(() => _showStrumModal = false),
                              child: Text("Don't show again",
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: t.textMuted)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ToolButton extends StatelessWidget {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final bool active;
  final AppTheme t;
  final VoidCallback onTap;

  const _ToolButton({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.active,
    required this.t,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isRecord = id == 'record';
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: active && isRecord ? AppColors.red : active ? color.withValues(alpha: 0.094) : t.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? color : t.border),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4)],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: color.withValues(alpha: 0.094),
              ),
              child: Icon(icon, size: 17, color: active && isRecord ? Colors.white : color),
            ),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: active && isRecord ? Colors.white : t.text,
                )),
          ],
        ),
      ),
    );
  }
}

class _TunerPanel extends StatelessWidget {
  final AppTheme t;
  final double needle;
  final String note;
  final int cents;
  final bool inTune;
  final VoidCallback onClose;

  const _TunerPanel({
    required this.t,
    required this.needle,
    required this.note,
    required this.cents,
    required this.inTune,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4)],
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TUNER', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: t.textMuted, letterSpacing: 0.8)),
              GestureDetector(
                onTap: onClose,
                child: Text('✕', style: TextStyle(fontSize: 18, color: t.textMuted)),
              ),
            ],
          ),
          Text(
            '${note}4',
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: inTune ? AppColors.green : t.text, letterSpacing: -1, height: 1),
          ),
          Text(
            inTune ? '✓ In tune' : '${cents > 0 ? "+" : ""}$cents cents',
            style: TextStyle(fontSize: 12, color: inTune ? AppColors.green : t.textSec, fontWeight: FontWeight.w600),
          ),
          SizedBox(
            height: 78,
            child: CustomPaint(
              size: const Size(double.infinity, 78),
              painter: _TunerPainter(needle: needle, inTune: inTune, borderColor: t.border),
            ),
          ),
        ],
      ),
    );
  }
}

class _TunerPainter extends CustomPainter {
  final double needle;
  final bool inTune;
  final Color borderColor;

  _TunerPainter({required this.needle, required this.inTune, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height - 4;
    const r = 58.0;
    const scale = sizeScale;

    final arcPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final greenPaint = Paint()
      ..color = AppColors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    final needlePaint = Paint()
      ..color = inTune ? AppColors.green : AppColors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    // Arc
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r * scale),
      pi, pi, false, arcPaint,
    );

    // Green zone
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r * scale),
      pi + pi * 0.47,
      pi * 0.06,
      false,
      greenPaint,
    );

    // Needle
    final angle = pi + (needle / 30) * (pi / 2);
    final nx = cx + (r - 6) * scale * cos(angle);
    final ny = cy + (r - 6) * scale * sin(angle);
    canvas.drawLine(Offset(cx, cy), Offset(nx, ny), needlePaint);

    // Pivot
    canvas.drawCircle(
      Offset(cx, cy),
      4.5 * scale,
      Paint()..color = inTune ? AppColors.green : AppColors.blue,
    );
  }

  static const sizeScale = 1.0;

  @override
  bool shouldRepaint(_TunerPainter old) => old.needle != needle || old.inTune != inTune;
}

class _MetronomePanel extends StatelessWidget {
  final AppTheme t;
  final int bpm;
  final bool running;
  final int beat;
  final ValueChanged<int> onBpmChange;
  final VoidCallback onToggle;
  final VoidCallback onClose;

  const _MetronomePanel({
    required this.t,
    required this.bpm,
    required this.running,
    required this.beat,
    required this.onBpmChange,
    required this.onToggle,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4)],
      ),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('METRONOME', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: t.textMuted, letterSpacing: 0.8)),
              GestureDetector(
                onTap: onClose,
                child: Text('✕', style: TextStyle(fontSize: 18, color: t.textMuted)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Beat dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 50),
                width: 20, height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: running && beat % 4 == i
                      ? (i == 0 ? AppColors.red : AppColors.green)
                      : t.surfaceAlt,
                  border: i == 0 ? Border.all(color: AppColors.red.withValues(alpha: 0.19), width: 2) : Border.all(color: t.border),
                ),
              ),
            )),
          ),
          const SizedBox(height: 10),
          // BPM controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => onBpmChange((bpm - 1).clamp(40, 240)),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: t.surfaceAlt),
                  child: Center(child: Text('−', style: TextStyle(fontSize: 22, color: t.text))),
                ),
              ),
              const SizedBox(width: 14),
              SizedBox(
                width: 80,
                child: Column(
                  children: [
                    Text('$bpm',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 46, fontWeight: FontWeight.w900, color: t.text, letterSpacing: -2, height: 1)),
                    Text('BPM', style: TextStyle(fontSize: 11, color: t.textMuted, fontWeight: FontWeight.w600, letterSpacing: 0.7)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              GestureDetector(
                onTap: () => onBpmChange((bpm + 1).clamp(40, 240)),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: t.surfaceAlt),
                  child: Center(child: Text('+', style: TextStyle(fontSize: 22, color: t.text))),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Slider(
            value: bpm.toDouble(),
            min: 40,
            max: 240,
            onChanged: (v) => onBpmChange(v.round()),
            activeColor: AppColors.green,
            inactiveColor: t.border,
          ),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: onToggle,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: running ? AppColors.green : t.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Center(
                  child: Text(
                    running ? '⏸ Stop' : '▶ Start',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: running ? Colors.white : t.text),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
