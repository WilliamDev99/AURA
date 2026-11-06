import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/liquid_glass.dart';
import '../../domain/models/guardian_message.dart';
import '../../state/app_state.dart';
import 'intervention_sheet.dart';
import 'widgets/aura_robot.dart';
import '../../core/l10n/l10n.dart';

const _navy = Color(0xFF0B2A8C);
const _chipBlue = Color(0xFF3D6BEA);
const _chipText = Color(0xFF2B57D6);
const _sendNavy = Color(0xFF0A1C6E);
const _inputFill = Color(0xFFEFF1F6);

/// Ruang obrolan anak dengan Aura.
///
/// Saat belum ada obrolan, layar menampilkan sapaan Aura dalam balon besar,
/// maskot di kanan, dan pilihan cepat di panel putih bawah. Setelah anak
/// mulai bercerita, bagian atas berganti menjadi percakapan.
class GuardianChatPage extends StatefulWidget {
  const GuardianChatPage({super.key});

  @override
  State<GuardianChatPage> createState() => _GuardianChatPageState();
}

class _GuardianChatPageState extends State<GuardianChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _inputFocus = FocusNode();
  bool _thinking = false;

  /// Setiap kunjungan dimulai dari sapaan Aura. Obrolan sebelumnya tetap
  /// tersimpan dan tetap dipakai Aura untuk memahami konteks, tetapi tidak
  /// ditampilkan ulang. Diberi kelonggaran sedikit untuk jam yang meleset.
  final _openedAt = DateTime.now().subtract(const Duration(seconds: 2));

  /// Tinggi panel putih, untuk menempatkan maskot tepat di atas tepinya.
  double _panelHeight = 0;

  /// Tinggi balon sapaan: maskot mengisi ruang di antara balon dan panel.
  double _bubbleHeight = 0;

  /// Kaki maskot sedikit menimpa tepi panel, seperti pada desain.
  static const _mascotOverlap = 24.0;

  /// Pilihan pembuka. Yang tanpa pesan membuka kolom ketik saja: ajakan
  /// untuk bercerita dengan kata-kata sendiri.
  static List<(String, String?)> get _starters => <(String, String?)>[
    (tr('Aku ada masalah di game'), 'Aku ada masalah di game'),
    (tr('Ada yang chat aneh...'), 'Ada yang chat aneh'),
    (tr('Aku merasa takut...'), 'Aku merasa takut'),
    (tr('Ceritain aja, aku disini kok!'), null),
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _thinking) return;

    _controller.clear();
    setState(() => _thinking = true);
    _scrollToBottom();

    final state = context.read<AppState>();
    try {
      final reply = await state.sendToGuardian(trimmed);
      if (!mounted) return;

      if (reply.assessment.level.interruptsChild) {
        await showInterventionSheet(context, reply.assessment);
      }
    } finally {
      if (mounted) setState(() => _thinking = false);
      _scrollToBottom();
    }
  }

  void _onBubbleSize(Size size) {
    if (size.height != _bubbleHeight) {
      setState(() => _bubbleHeight = size.height);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final messages = state.chat
        .where((m) => !m.sentAt.isBefore(_openedAt))
        .toList();
    final intro = messages.isEmpty && !_thinking;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    final last = messages.isEmpty ? null : messages.last;
    final chips = intro
        ? _starters
        : (!_thinking && last != null && !last.isChild)
        // Label diterjemahkan; yang dikirim tetap teks aslinya supaya
        // dikenali Aura.
        ? last.quickReplies.map((r) => (tr(r), r as String?)).toList()
        : const <(String, String?)>[];

    return Scaffold(
      backgroundColor: const Color(0xFF05061A),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final topInset = MediaQuery.paddingOf(context).top;
          // Ruang dari bawah balon sapaan sampai tepi panel (ditambah
          // bagian kaki yang menimpa panel). Kepala header = 64, jarak atas
          // balon = 18, jarak balon ke maskot = 6.
          final bubbleBottom = topInset + 64 + 18 + _bubbleHeight + 6;
          final room =
              constraints.maxHeight -
              _panelHeight +
              _mascotOverlap -
              bubbleBottom;
          final mascotHeight = room.clamp(110.0, 380.0);
          final showMascot =
              intro && !keyboardOpen && _panelHeight > 0 && _bubbleHeight > 0;

          return Stack(
            fit: StackFit.expand,
            children: [
              const _ChatBackdrop(),
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    _Header(onBack: () => Navigator.of(context).maybePop()),
                    Expanded(
                      child: intro
                          ? SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  18,
                                  0,
                                  0,
                                ),
                                child: Align(
                                  alignment: Alignment.topLeft,
                                  child: FractionallySizedBox(
                                    widthFactor: 0.8,
                                    child: _SizeReporter(
                                      onSize: _onBubbleSize,
                                      child: const _GreetingBubble(),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : _Conversation(
                              messages: messages,
                              thinking: _thinking,
                              controller: _scrollController,
                            ),
                    ),
                    _SizeReporter(
                      onSize: (size) {
                        if (size.height != _panelHeight) {
                          setState(() => _panelHeight = size.height);
                        }
                      },
                      child: _BottomPanel(
                        chips: chips,
                        onChip: (send) => send == null
                            ? _inputFocus.requestFocus()
                            : _send(send),
                        controller: _controller,
                        focusNode: _inputFocus,
                        enabled: !_thinking,
                        onSend: () => _send(_controller.text),
                        usesAi: state.usesAiChat,
                      ),
                    ),
                  ],
                ),
              ),
              // Digambar di atas panel supaya kakinya sedikit menimpa tepi
              // putih, seperti pada desain.
              if (showMascot)
                Positioned(
                  right: 6,
                  bottom: _panelHeight - _mascotOverlap,
                  child: IgnorePointer(
                    child: AuraRobot(
                      width: mascotHeight * AuraRobot.aspectRatio,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Latar: hitam di kiri atas, biru di sisi kiri, cahaya merah-oranye di
/// kanan atas.
class _ChatBackdrop extends StatelessWidget {
  const _ChatBackdrop();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF03040F), Color(0xFF0A1658), Color(0xFF1838C4)],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-1.3, 0.05),
              radius: 0.95,
              colors: [Color(0xCC2D5BFF), Color(0x002D5BFF)],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(1.15, -0.85),
              radius: 0.85,
              colors: [Color(0xE6FF4D2A), Color(0x99E0245E), Color(0x00E0245E)],
              stops: [0.0, 0.45, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

/// Kepala halaman bergaya Liquid Glass iOS: tombol kembali berupa lingkaran
/// kaca di kiri, judul dalam kapsul kaca tepat di tengah.
class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: SizedBox(
        height: 48,
        // Stack, bukan Row: judul selalu tepat di tengah layar, berapa pun
        // lebar tombol di sisinya.
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: LiquidGlassButton(
                onTap: onBack,
                semanticLabel: tr('Kembali'),
                child: const Icon(
                  Icons.chevron_left_rounded,
                  size: 32,
                  color: Colors.white,
                ),
              ),
            ),
            LiquidGlass(
              borderRadius: 24,
              padding: EdgeInsets.symmetric(horizontal: 28, vertical: 11),
              child: Text(
                tr('AURA'),
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: Colors.white,
                  height: 1.2,
                  shadows: [Shadow(color: Color(0x33000000), blurRadius: 6)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sapaan Aura yang "muncul berbicara": balon tumbuh dari ekornya, tulisan
/// masuk bergantian, lalu hati berdetak pelan.
class _GreetingBubble extends StatefulWidget {
  const _GreetingBubble();

  @override
  State<_GreetingBubble> createState() => _GreetingBubbleState();
}

class _GreetingBubbleState extends State<_GreetingBubble>
    with TickerProviderStateMixin {
  late final _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  late final _heart = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  late final _pop = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0, 0.45, curve: Curves.easeOutBack),
  );
  late final _fade = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0, 0.25, curve: Curves.easeOut),
  );
  late final _title = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.3, 0.65, curve: Curves.easeOutCubic),
  );
  late final _subtitle = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.5, 0.9, curve: Curves.easeOutCubic),
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Anak yang mematikan animasi di pengaturan ponsel langsung melihat
    // sapaan lengkap, tanpa gerak.
    if (MediaQuery.disableAnimationsOf(context)) {
      _intro.value = 1;
      return;
    }
    _intro.forward().whenComplete(() {
      if (mounted) _heart.repeat();
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _heart.dispose();
    super.dispose();
  }

  /// Masuk dari sedikit di bawah sambil memudar.
  Widget _rise(Animation<double> animation, Widget child) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.35),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        // Tumbuh dari ekor balon, yang menunjuk ke maskot.
        alignment: const Alignment(0.5, 1),
        scale: Tween(begin: 0.55, end: 1.0).animate(_pop),
        child: CustomPaint(
          painter: const _BubblePainter(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _rise(
                  _title,
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          tr('Halo! Saya Aura'),
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: _navy,
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _Heartbeat(animation: _heart),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                _rise(
                  _subtitle,
                  Text(
                    tr(
                      'Ada yang bisa aku bantuin?\nKamu lagi ngerasa apa hari ini?',
                    ),
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _navy,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hati yang berdetak dua kali lalu diam sejenak, seperti detak jantung.
class _Heartbeat extends StatelessWidget {
  const _Heartbeat({required this.animation});

  final Animation<double> animation;

  static final _beat = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1, end: 1.28), weight: 8),
    TweenSequenceItem(tween: Tween(begin: 1.28, end: 1), weight: 8),
    TweenSequenceItem(tween: Tween(begin: 1, end: 1.2), weight: 8),
    TweenSequenceItem(tween: Tween(begin: 1.2, end: 1), weight: 10),
    TweenSequenceItem(tween: ConstantTween(1), weight: 66),
  ]);

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _beat.animate(animation),
      child: const Text(
        '💙',
        semanticsLabel: '',
        style: TextStyle(fontSize: 20, height: 1.2),
      ),
    );
  }
}

/// Balon putih polos dengan ekor di kanan bawah yang menunjuk ke arah
/// maskot.
class _BubblePainter extends CustomPainter {
  const _BubblePainter();

  static const _tail = 14.0;

  @override
  void paint(Canvas canvas, Size size) {
    final body = Rect.fromLTWH(0, 0, size.width, size.height - _tail);
    final tailX = size.width * 0.74;
    // Ekor dimulai sedikit di dalam badan balon lalu disatukan, supaya tidak
    // ada garis atau celah di sambungannya.
    final tail = Path()
      ..moveTo(tailX - 16, body.bottom - 8)
      ..lineTo(tailX + 22, size.height)
      ..lineTo(tailX + 10, body.bottom - 8)
      ..close();
    final path = Path.combine(
      PathOperation.union,
      Path()
        ..addRRect(RRect.fromRectAndRadius(body, const Radius.circular(24))),
      tail,
    );

    canvas.drawShadow(path, Colors.black, 6, false);
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_BubblePainter oldDelegate) => false;
}

class _Conversation extends StatelessWidget {
  const _Conversation({
    required this.messages,
    required this.thinking,
    required this.controller,
  });

  final List<GuardianMessage> messages;
  final bool thinking;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: messages.length + (thinking ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == messages.length) return const _TypingBubble();
        return _MessageBubble(message: messages[index]);
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final GuardianMessage message;

  @override
  Widget build(BuildContext context) {
    final isChild = message.isChild;
    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.72,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      decoration: BoxDecoration(
        color: isChild ? null : Colors.white,
        gradient: isChild
            ? const LinearGradient(
                colors: [Color(0xFF4A7BFF), Color(0xFF2448D8)],
              )
            : null,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(isChild ? 20 : 6),
          bottomRight: Radius.circular(isChild ? 6 : 20),
        ),
      ),
      child: Text(
        message.text,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          height: 1.45,
          fontWeight: FontWeight.w500,
          color: isChild ? Colors.white : _navy,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isChild
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (isChild)
            bubble
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [const _AuraAvatar(), const SizedBox(width: 8), bubble],
            ),
          if (message.escalated)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 44),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.notifications_active_rounded,
                    size: 13,
                    color: Color(0xFFFFC857),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    tr('Orang tuamu diberi tahu soal ini'),
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11.5,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const _AuraAvatar(),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              tr('Aura sedang mengetik...'),
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: Color(0xFF5B6B9A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuraAvatar extends StatelessWidget {
  const _AuraAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.all(3),
      child: Image.asset(
        'assets/images/aura_mascot_head.png',
        semanticLabel: tr('Aura'),
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.chips,
    required this.onChip,
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.onSend,
    required this.usesAi,
  });

  /// Anak yang dibalas AI perlu tahu ia mengobrol dengan AI.
  final bool usesAi;

  final List<(String, String?)> chips;
  final void Function(String? send) onChip;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
      ),
      padding: EdgeInsets.fromLTRB(
        18,
        chips.isEmpty ? 16 : 20,
        18,
        10 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (chips.isNotEmpty)
            // Di layar pendek atau dengan huruf besar, pilihan bisa digulir:
            // kolom ketik harus selalu terlihat.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.26,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (label, send) in chips)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ChoiceChip(
                          label: label,
                          onTap: () => onChip(send),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (chips.isNotEmpty) const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: enabled,
                  // Tombol Enter di keyboard langsung mengirim, seperti
                  // aplikasi chat yang biasa dipakai anak.
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  minLines: 1,
                  maxLines: 4,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: _navy,
                  ),
                  decoration: InputDecoration(
                    hintText: tr('Ketik pesan...'),
                    hintStyle: const TextStyle(
                      fontFamily: 'Poppins',
                      color: Color(0xFF9AA3B8),
                    ),
                    filled: true,
                    fillColor: _inputFill,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: const BorderSide(color: _chipBlue),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Semantics(
                button: true,
                label: tr('Kirim pesan'),
                child: Material(
                  color: enabled ? _sendNavy : const Color(0xFF8C96B8),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: enabled ? onSend : null,
                    child: const SizedBox(
                      width: 52,
                      height: 52,
                      child: Icon(
                        Icons.send_outlined,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              // Anak berhak tahu ia mengobrol dengan AI.
              usesAi
                  ? tr(
                      'Aura dibantu AI. Jangan bagikan data pribadi. Orang tuamu hanya '
                      'diberi tahu kalau kamu dalam bahaya.',
                    )
                  : tr(
                      'Ceritamu aman. Orang tuamu hanya diberi tahu kalau kamu dalam '
                      'bahaya.',
                    ),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10.5,
                color: Color(0xFF8A93AB),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const StadiumBorder(
        side: BorderSide(color: _chipBlue, width: 1.4),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.schedule_rounded, size: 15, color: _chipText),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _chipText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Melaporkan ukuran anaknya setelah tata letak, untuk menempatkan maskot.
class _SizeReporter extends SingleChildRenderObjectWidget {
  const _SizeReporter({required this.onSize, required super.child});

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSizeReporter(onSize);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSizeReporter renderObject,
  ) {
    renderObject.onSize = onSize;
  }
}

class _RenderSizeReporter extends RenderProxyBox {
  _RenderSizeReporter(this.onSize);

  ValueChanged<Size> onSize;
  Size? _last;

  @override
  void performLayout() {
    super.performLayout();
    if (size == _last) return;
    _last = size;
    final reported = size;
    WidgetsBinding.instance.addPostFrameCallback((_) => onSize(reported));
  }
}
