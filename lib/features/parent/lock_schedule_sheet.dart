import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/aura_colors.dart';
import '../../core/widgets/clay.dart';
import '../../domain/models/app_user.dart';
import '../../domain/models/lock_schedule.dart';
import '../../state/app_state.dart';

const _poppins = 'Poppins';

/// Kartu "Jam istirahat" di lembar rincian anak.
///
/// Sakelarnya langsung berlaku, sama seperti sakelar "Perlindungan aktif"
/// di atasnya: tidak perlu menekan Simpan. Mengetuk kartunya membuka
/// pengaturan jam dan hari.
class LockScheduleCard extends StatefulWidget {
  const LockScheduleCard({super.key, required this.child});

  final AppUser child;

  @override
  State<LockScheduleCard> createState() => _LockScheduleCardState();
}

class _LockScheduleCardState extends State<LockScheduleCard> {
  /// Posisi sakelar yang dipilih orang tua, selagi disimpan dan sampai data
  /// anak dari server ikut berubah.
  bool? _chosen;
  bool _saving = false;
  String? _error;

  @override
  void didUpdateWidget(LockScheduleCard old) {
    super.didUpdateWidget(old);
    if (old.child.lockSchedule != widget.child.lockSchedule && !_saving) {
      _chosen = null;
    }
  }

  Future<void> _toggle(bool on) async {
    final saved = widget.child.lockSchedule;
    final LockSchedule next;
    if (on) {
      final resumed = saved?.copyWith(enabled: true);
      // Belum pernah diatur (atau jadwal lamanya tidak lengkap): 22.00 sampai
      // 09.00 setiap hari. Jamnya bisa diubah dengan mengetuk kartu.
      next = resumed != null && resumed.active
          ? resumed
          : LockSchedule.standard;
    } else {
      next = (saved ?? LockSchedule.standard).copyWith(enabled: false);
    }
    setState(() {
      _chosen = on;
      _saving = true;
      _error = null;
    });
    final state = context.read<AppState>();
    await state.setLockSchedule(widget.child.id, next);
    if (!mounted) return;
    final error = state.lastError;
    setState(() {
      _saving = false;
      if (error != null) {
        _chosen = null;
        _error = error;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    final schedule = child.lockSchedule;
    final on = _chosen ?? (schedule?.active ?? false);
    // Jadwal yang menyala tetapi belum bisa mengunci harus terlihat jelas:
    // orang tua tidak boleh mengira jam istirahat berjalan padahal belum.
    final String? warning = !on || _chosen != null
        ? null
        : switch (child.lockReady) {
            true => null,
            false => tr(
              'Belum siap: di HP {childName}, buka AURA > Pengaturan > '
              'Jam istirahat, lalu izinkan semuanya.',
              {'childName': child.name},
            ),
            null => tr(
              'Menunggu HP {childName} membuka AURA untuk memeriksa izinnya.',
              {'childName': child.name},
            ),
          };

    final hours = schedule?.copyWith(enabled: true);
    final String summary;
    if (on) {
      summary = (hours != null && hours.active ? hours : LockSchedule.standard)
          .describe();
    } else if (hours != null && hours.active) {
      summary = tr('Mati · {when}', {'when': hours.describe()});
    } else {
      summary = tr('Belum diatur');
    }

    return ClayCard(
      color: on ? ClayColors.pastel(AuraColors.cyan) : Colors.white,
      padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
      onTap: () => LockScheduleEditor.show(context, child),
      child: Row(
        children: [
          const Icon(Icons.bedtime_rounded, color: ClayColors.ink),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('Jam istirahat'),
                  style: const TextStyle(
                    fontFamily: _poppins,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: ClayColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  summary,
                  style: const TextStyle(
                    fontFamily: _poppins,
                    fontSize: 12.5,
                    height: 1.4,
                    color: ClayColors.inkSoft,
                  ),
                ),
                Text(
                  tr('Ketuk untuk mengatur jam dan hari.'),
                  style: const TextStyle(
                    fontFamily: _poppins,
                    fontSize: 12,
                    height: 1.4,
                    color: ClayColors.inkMuted,
                  ),
                ),
                if (_error != null || warning != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _error != null
                        ? tr('Belum tersimpan. {error}', {'error': _error!})
                        : warning!,
                    style: const TextStyle(
                      fontFamily: _poppins,
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: AuraColors.high,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Switch(
            value: on,
            onChanged: _saving ? null : _toggle,
            activeTrackColor: const Color(0xFF34C759),
            activeThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFD5D8DE),
            inactiveThumbColor: Colors.white,
            trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
        ],
      ),
    );
  }
}

/// Mengatur jam istirahat: jam mulai, jam selesai, dan harinya.
class LockScheduleEditor extends StatefulWidget {
  const LockScheduleEditor({super.key, required this.child});

  final AppUser child;

  static Future<void> show(BuildContext context, AppUser child) =>
      showClaySheet<void>(
        context: context,
        builder: (_) => LockScheduleEditor(child: child),
      );

  @override
  State<LockScheduleEditor> createState() => _LockScheduleEditorState();
}

class _LockScheduleEditorState extends State<LockScheduleEditor> {
  /// Menyimpan dari sini selalu menyalakan jam istirahat; mematikannya
  /// lewat sakelar di kartu.
  late LockSchedule _schedule =
      (widget.child.lockSchedule ?? LockSchedule.standard).copyWith(
        enabled: true,
      );
  late final bool _wasOn = widget.child.lockSchedule?.active ?? false;
  bool _saving = false;

  /// Jam yang sedang diatur dengan roda gulir: true = mulai, false =
  /// selesai, null = roda tertutup. Seperti di iPhone, roda muncul tepat di
  /// bawah jam yang diketuk.
  bool? _editingStart;

  void _toggleWheel(bool start) =>
      setState(() => _editingStart = _editingStart == start ? null : start);

  void _setTime(DateTime time) {
    // iPhone berdetak tiap angka lewat; CupertinoPicker hanya melakukannya
    // di iOS, jadi Android diberi detak yang sama di sini.
    if (defaultTargetPlatform == TargetPlatform.android) {
      HapticFeedback.selectionClick();
    }
    final value = time.hour * 60 + time.minute;
    setState(
      () => _schedule = _editingStart!
          ? _schedule.copyWith(startMinutes: value)
          : _schedule.copyWith(endMinutes: value),
    );
  }

  /// Alasan gagal menyimpan, ditampilkan di dalam lembar ini. Snackbar akan
  /// muncul di belakang lembar dan tidak terlihat, sehingga tombol Simpan
  /// seolah tidak berbuat apa-apa.
  String? _error;

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final state = context.read<AppState>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await state.setLockSchedule(widget.child.id, _schedule);
    if (!mounted) return;
    final error = state.lastError;
    setState(() {
      _saving = false;
      _error = error;
    });
    if (error != null) return;
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          _schedule.active
              ? tr('Jam istirahat {childName} disimpan: {when}.', {
                  'childName': widget.child.name,
                  'when': _schedule.describe(),
                })
              : tr('Jam istirahat {childName} dimatikan.', {
                  'childName': widget.child.name,
                }),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final names = LockSchedule.dayNames;
    final sameTime = _schedule.startMinutes == _schedule.endMinutes;
    final noDays = _schedule.days.isEmpty;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr('Jam istirahat {childName}', {'childName': widget.child.name}),
              style: const TextStyle(
                fontFamily: _poppins,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: ClayColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              tr(
                'Semua aplikasi di HP anak terkunci pada jam ini. AURA '
                '(tombol SOS), telepon, dan jam alarm tetap bisa dibuka.',
              ),
              style: const TextStyle(
                fontFamily: _poppins,
                fontSize: 13,
                height: 1.45,
                color: ClayColors.inkSoft,
              ),
            ),
            const SizedBox(height: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _TimeTile(
                        label: tr('Mulai'),
                        minutes: _schedule.startMinutes,
                        selected: _editingStart == true,
                        onTap: () => _toggleWheel(true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TimeTile(
                        label: tr('Selesai'),
                        minutes: _schedule.endMinutes,
                        selected: _editingStart == false,
                        onTap: () => _toggleWheel(false),
                      ),
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: _editingStart == null
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _TimeWheel(
                            // Kunci baru tiap ganti jam: roda dibuat ulang
                            // dan mulai dari jam yang diketuk.
                            key: ValueKey(_editingStart),
                            minutes: _editingStart!
                                ? _schedule.startMinutes
                                : _schedule.endMinutes,
                            onChanged: _setTime,
                          ),
                        ),
                ),
                if (sameTime) ...[
                  const SizedBox(height: 8),
                  Text(
                    tr('Jam mulai dan selesai tidak boleh sama.'),
                    style: const TextStyle(
                      fontFamily: _poppins,
                      fontSize: 12.5,
                      color: AuraColors.high,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  tr('Hari'),
                  style: const TextStyle(
                    fontFamily: _poppins,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: ClayColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var day = 1; day <= 7; day++)
                      FilterChip(
                        label: Text(names[day - 1]),
                        selected: _schedule.days.contains(day),
                        onSelected: (selected) => setState(() {
                          final days = {..._schedule.days};
                          selected ? days.add(day) : days.remove(day);
                          _schedule = _schedule.copyWith(days: days);
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  noDays
                      ? tr('Pilih minimal satu hari.')
                      : tr(
                          'Hari adalah malam mulainya kunci: Senin '
                          '22.00 sampai Selasa 09.00 termasuk hari Senin.',
                        ),
                  style: TextStyle(
                    fontFamily: _poppins,
                    fontSize: 12,
                    height: 1.4,
                    color: noDays ? AuraColors.high : ClayColors.inkMuted,
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 20,
                    color: AuraColors.high,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr('Belum tersimpan. {error}', {'error': _error!}),
                      style: const TextStyle(
                        fontFamily: _poppins,
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: AuraColors.high,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving || sameTime || noDays ? null : _save,
              child: Text(
                _saving
                    ? tr('Menyimpan...')
                    : _wasOn
                    ? tr('Simpan')
                    : tr('Simpan dan nyalakan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.label,
    required this.minutes,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int minutes;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return ClayCard(
      color: selected ? ClayColors.pastel(accent) : Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: _poppins,
              fontSize: 12.5,
              color: ClayColors.inkSoft,
            ),
          ),
          Text(
            LockSchedule.display(minutes),
            style: TextStyle(
              fontFamily: _poppins,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: selected ? accent : ClayColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// Roda gulir jam dan menit seperti di iPhone, format 24 jam.
class _TimeWheel extends StatelessWidget {
  const _TimeWheel({super.key, required this.minutes, required this.onChanged});

  final int minutes;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SizedBox(
        height: 180,
        child: CupertinoTheme(
          data: const CupertinoThemeData(
            brightness: Brightness.light,
            textTheme: CupertinoTextThemeData(
              dateTimePickerTextStyle: TextStyle(
                fontSize: 22,
                color: ClayColors.ink,
              ),
            ),
          ),
          child: Localizations.override(
            context: context,
            delegates: const [_TwoDigitHours.delegate],
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.time,
              use24hFormat: true,
              initialDateTime: DateTime(
                2000,
                1,
                1,
                minutes ~/ 60,
                minutes % 60,
              ),
              onDateTimeChanged: onChanged,
            ),
          ),
        ),
      ),
    );
  }
}

/// Jam di roda ditulis dua angka ("00", "07") seperti menitnya, sama
/// seperti roda 24 jam di iPhone. Bawaan Flutter menulis "0", "7".
class _TwoDigitHours extends DefaultCupertinoLocalizations {
  const _TwoDigitHours();

  static const delegate = _TwoDigitHoursDelegate();

  @override
  String datePickerHour(int hour) => hour.toString().padLeft(2, '0');
}

class _TwoDigitHoursDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const _TwoDigitHoursDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      SynchronousFuture(const _TwoDigitHours());

  @override
  bool shouldReload(_TwoDigitHoursDelegate old) => false;
}
