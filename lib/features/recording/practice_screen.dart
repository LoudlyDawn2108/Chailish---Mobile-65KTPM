// Module M2 – Màn hình luyện tập (thu âm -> chấm điểm) · Phụ trách: Lê Tuấn Khanh
//
// Luồng: hiện từ/câu + IPA -> nghe mẫu -> bấm micro nói -> chấm điểm ->
// lưu kết quả -> màn hình phản hồi -> thử lại / tiếp theo.
// Thời gian học được đo bằng Stopwatch, tạm dừng khi app chạy nền.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app/theme.dart';
import '../../core/db/repositories.dart';
import '../../core/models/lesson.dart';
import '../../core/models/pronunciation_result.dart';
import '../../core/models/user_profile.dart';
import '../../core/providers.dart';
import '../../core/services/settings_service.dart';
import '../feedback/feedback_screen.dart';
import '../progress/progress_service.dart';
import '../pronunciation/pronunciation_service.dart';
import 'speech_service.dart';
import 'tts_service.dart';

enum _Phase { idle, listening, recording, assessing }

class PracticeScreen extends ConsumerStatefulWidget {
  const PracticeScreen({
    super.key,
    required this.title,
    required this.items,
    this.startIndex = 0,
    this.lessonId,
  });

  final String title;
  final List<LessonItem> items;
  final int startIndex;
  final String? lessonId;

  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends ConsumerState<PracticeScreen>
    with WidgetsBindingObserver {
  late int _index = widget.startIndex.clamp(0, widget.items.length - 1);
  _Phase _phase = _Phase.idle;
  String _partial = '';
  String? _error;
  double _level = 0;
  final List<double> _sessionScores = [];

  // Dịch vụ được lấy 1 lần trong initState (không được dùng ref trong dispose).
  late final SpeechService _speech;
  late final TtsService _tts;
  late final PronunciationService _pron;
  late final ProgressService _progress;
  late final AttemptRepository _attempts;
  late final UserProfile _user;

  final Stopwatch _watch = Stopwatch();
  int? _sessionId;
  final DateTime _startedAt = DateTime.now();
  int _flushedSeconds = 0;
  StreamSubscription<dynamic>? _ampSub;
  Timer? _autoStop;

  // Không tính giờ học khi người dùng để màn hình đó mà không thao tác
  // (lỗi tìm thấy khi QA: màn hình để yên 10 phút vẫn được tính 10 phút).
  static const _idleLimit = Duration(minutes: 2);
  DateTime _lastActivity = DateTime.now();
  bool _foreground = true;
  Timer? _idleTimer;

  void _touch() {
    _lastActivity = DateTime.now();
    if (_foreground && !_watch.isRunning) _watch.start();
  }

  void _checkIdle() {
    if (_watch.isRunning &&
        _phase == _Phase.idle &&
        DateTime.now().difference(_lastActivity) > _idleLimit) {
      _watch.stop();
      _flushTime();
    }
  }

  LessonItem get _item => widget.items[_index];

  @override
  void initState() {
    super.initState();
    _speech = ref.read(speechServiceProvider);
    _tts = ref.read(ttsServiceProvider);
    _pron = ref.read(pronunciationServiceProvider);
    _progress = ref.read(progressServiceProvider);
    _attempts = ref.read(attemptRepoProvider);
    _user = ref.read(activeUserProvider)!;
    WidgetsBinding.instance.addObserver(this);
    _watch.start();
    _idleTimer = Timer.periodic(const Duration(seconds: 15), (_) => _checkIdle());
    _attempts
        .startSession(_user.id!, widget.lessonId, _startedAt)
        .then((id) => _sessionId = id);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      _touch();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _foreground = false;
      _watch.stop();
      _flushTime();
    }
  }

  /// Cộng phần thời gian học chưa ghi vào thống kê ngày.
  Future<void> _flushTime() async {
    final total = _watch.elapsed.inSeconds;
    final delta = total - _flushedSeconds;
    if (delta <= 0) return;
    _flushedSeconds = total;
    await _progress.addPracticeTime(_user, delta);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _watch.stop();
    _autoStop?.cancel();
    _idleTimer?.cancel();
    _ampSub?.cancel();
    _speech.cancelListening();
    _speech.isRecording().then((r) {
      if (r) _speech.cancelRecording();
    });
    _tts.stop();
    _flushTime();
    final id = _sessionId;
    if (id != null) {
      _attempts.endSession(id, DateTime.now(), _watch.elapsed.inSeconds);
    }
    super.dispose();
  }

  // ------------------------------------------------------------------

  Future<void> _onMicPressed() async {
    _touch();
    final settings = ref.read(settingsProvider);
    final azure = settings.effectiveEngine == ScoringEngine.azure;
    switch (_phase) {
      case _Phase.idle:
        await _tts.stop();
        setState(() {
          _error = null;
          _partial = '';
        });
        if (azure) {
          await _startRecording();
        } else {
          await _startListening();
        }
      case _Phase.listening:
        await _speech.stopListening();
      case _Phase.recording:
        await _stopRecordingAndAssess(settings);
      case _Phase.assessing:
        break;
    }
  }

  Future<void> _startListening() async {
    setState(() => _phase = _Phase.listening);
    try {
      final capture = await _speech.listen(
        onPartial: (t) {
          if (mounted) setState(() => _partial = t);
        },
        onSoundLevel: (l) {
          if (mounted) setState(() => _level = l);
        },
      );
      if (!mounted) return;
      setState(() => _phase = _Phase.assessing);
      final result = await _pron.assessOffline(_item.text, capture);
      await _finish(result, null);
    } on SpeechException catch (e) {
      await _showError(e.message);
    } catch (e) {
      await _showError('Có lỗi xảy ra: $e');
    }
  }

  Future<void> _startRecording() async {
    try {
      await _speech.startRecording();
      setState(() => _phase = _Phase.recording);
      _ampSub = _speech.amplitude().listen((a) {
        // dBFS (-60..0) -> 0..10
        if (mounted) setState(() => _level = ((a.current + 60) / 6).clamp(0, 10));
      });
      _autoStop = Timer(const Duration(seconds: 15), () {
        if (_phase == _Phase.recording) {
          _stopRecordingAndAssess(ref.read(settingsProvider));
        }
      });
    } on SpeechException catch (e) {
      await _showError(e.message);
    }
  }

  Future<void> _stopRecordingAndAssess(AppSettings settings) async {
    _autoStop?.cancel();
    await _ampSub?.cancel();
    _ampSub = null;
    setState(() => _phase = _Phase.assessing);
    try {
      final path = await _speech.stopRecording();
      if (path == null) throw const SpeechException('Không ghi được âm thanh.');
      final result = await _pron.assessAzure(
        reference: _item.text,
        audioPath: path,
        key: settings.azureKey,
        region: settings.azureRegion,
      );
      await _finish(result, path);
    } catch (e) {
      await _showError(e.toString());
    }
  }

  Future<void> _showError(String msg) async {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.idle;
      _error = msg;
      _level = 0;
    });
    if (await _speech.isMicPermanentlyDenied() && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Quyền micro đã bị từ chối vĩnh viễn.'),
        action: SnackBarAction(label: 'Mở cài đặt', onPressed: openAppSettings),
      ));
    }
  }

  Future<void> _finish(PronunciationResult result, String? audioPath) async {
    await _flushTime();
    final saved = await _progress.recordAttempt(
      user: _user,
      sessionId: _sessionId,
      item: _item,
      result: result,
      audioPath: audioPath,
    );
    _sessionScores.add(result.overall);
    if (!mounted) return;
    ref.read(dataVersionProvider.notifier).bump();
    setState(() {
      _phase = _Phase.idle;
      _level = 0;
    });
    final action = await Navigator.of(context).push<FeedbackAction>(
      MaterialPageRoute(
        builder: (_) => FeedbackScreen(
          result: result,
          item: _item,
          audioPath: audioPath,
          streak: saved.streak,
          hasNext: _index < widget.items.length - 1,
        ),
      ),
    );
    if (!mounted) return;
    _touch(); // thời gian đọc phản hồi cũng là thời gian học
    if (action == FeedbackAction.next) _next();
  }

  void _next() {
    _touch();
    if (_index < widget.items.length - 1) {
      setState(() {
        _index++;
        _partial = '';
        _error = null;
      });
    } else {
      _showSummary();
    }
  }

  Future<void> _showSummary() async {
    final avg = _sessionScores.isEmpty
        ? 0.0
        : _sessionScores.reduce((a, b) => a + b) / _sessionScores.length;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
            _sessionScores.isEmpty ? Icons.info_outline : Icons.emoji_events,
            size: 48,
            color: AppColors.streak),
        // Bỏ qua hết mà vẫn chúc mừng là sai (lỗi tìm thấy khi QA).
        title: Text(_sessionScores.isEmpty ? 'Đã xem hết bài' : 'Hoàn thành bài!'),
        content: Text(
            'Bạn đã luyện ${_sessionScores.length} lượt.\nĐiểm trung bình: ${avg.round()}'
            '\nThời gian: ${(_watch.elapsed.inSeconds / 60).toStringAsFixed(1)} phút'),
        actions: [
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(), child: const Text('Tuyệt')),
        ],
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = ref.watch(settingsProvider);
    final rate = settings.ttsRate;
    final azure = settings.effectiveEngine == ScoringEngine.azure;
    final dictReady = ref.watch(dictionaryProvider).hasValue;
    final busy = _phase != _Phase.idle;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text('${_index + 1}/${widget.items.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
              value: (_index + 1) / widget.items.length, minHeight: 4),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Text(
                          _item.text,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: _item.type == 'word' ? 44 : 28,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(_item.ipa,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 20, color: scheme.primary)),
                        const SizedBox(height: 8),
                        Text(_item.meaning,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge),
                        const SizedBox(height: 20),
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          OutlinedButton.icon(
                            onPressed: busy
                                ? null
                                : () {
                                    _touch();
                                    _tts.speak(_item.text, rate: rate);
                                  },
                            icon: const Icon(Icons.volume_up),
                            label: const Text('Nghe mẫu'),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: busy
                                ? null
                                : () {
                                    _touch();
                                    _tts.speak(_item.text, rate: rate * 0.55);
                                  },
                            icon: const Icon(Icons.slow_motion_video),
                            label: const Text('Chậm'),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
              ),
              // Văn bản nhận dạng / thông báo lỗi
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _error != null
                    ? Container(
                        key: const ValueKey('err'),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: scheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(_error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: scheme.onErrorContainer)),
                      )
                    : Text(
                        key: ValueKey(_partial),
                        _statusText(azure),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
              ),
              const SizedBox(height: 20),
              _MicButton(
                phase: _phase,
                level: _level,
                onPressed: (!dictReady && !azure) || _phase == _Phase.assessing
                    ? null
                    : _onMicPressed,
              ),
              const SizedBox(height: 8),
              Text(
                !dictReady && !azure
                    ? 'Đang nạp từ điển phát âm...'
                    : azure
                        ? 'Chấm điểm: Azure AI'
                        : 'Chấm điểm: so sánh âm vị (offline)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Row(children: [
                TextButton.icon(
                  onPressed: busy || _index == 0
                      ? null
                      : () => setState(() {
                            _touch();
                            _index--;
                            _partial = '';
                            _error = null;
                          }),
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('Trước'),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: busy ? null : _next,
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('Bỏ qua'),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  String _statusText(bool azure) => switch (_phase) {
        _Phase.idle => 'Bấm micro rồi đọc to từ/câu trên',
        _Phase.listening => _partial.isEmpty
            ? 'Đang nghe... nói xong bấm ■ để chấm ngay'
            : '"$_partial"',
        _Phase.recording => 'Đang ghi âm... bấm lần nữa để dừng',
        _Phase.assessing => 'AI đang phân tích phát âm...',
      };
}

class _MicButton extends StatelessWidget {
  const _MicButton({required this.phase, required this.level, this.onPressed});
  final _Phase phase;
  final double level;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = phase == _Phase.listening || phase == _Phase.recording;
    final double glow = active ? 12 + level.clamp(0, 10) * 3.0 : 0.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          if (active)
            BoxShadow(
              color: AppColors.bad.withValues(alpha: 0.35),
              blurRadius: glow,
              spreadRadius: glow / 2,
            ),
        ],
      ),
      child: Material(
        shape: const CircleBorder(),
        color: active ? AppColors.bad : scheme.primary,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Center(
            child: phase == _Phase.assessing
                ? const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                : Icon(active ? Icons.stop : Icons.mic,
                    size: 44, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
