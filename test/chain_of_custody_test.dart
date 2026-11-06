import 'package:aura/domain/models/evidence_item.dart';
import 'package:aura/domain/services/chain_of_custody.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const custody = ChainOfCustody();
  final base = DateTime(2026, 3, 14, 9, 30);

  EvidenceItem seal(String payload, EvidenceItem? previous, int minuteOffset) {
    return custody.seal(
      id: 'ev-$minuteOffset',
      familyId: 'fam-1',
      childId: 'child-1',
      kind: EvidenceKind.messageTranscript,
      capturedAt: base.add(Duration(minutes: minuteOffset)),
      recordedAt: base.add(Duration(minutes: minuteOffset, seconds: 1)),
      description: 'Bukti ke-$minuteOffset',
      payload: payload,
      previous: previous,
    );
  }

  List<EvidenceItem> buildChain(List<String> payloads) {
    final items = <EvidenceItem>[];
    EvidenceItem? previous;
    for (var i = 0; i < payloads.length; i++) {
      final item = seal(payloads[i], previous, i);
      items.add(item);
      previous = item;
    }
    return items;
  }

  test('rantai kosong dianggap utuh', () {
    final result = custody.verify(const []);
    expect(result.isIntact, isTrue);
    expect(result.checked, 0);
  });

  test('rantai yang dibangun berurutan terverifikasi utuh', () {
    final chain = buildChain(['pesan satu', 'pesan dua', 'pesan tiga']);
    final result = custody.verify(chain);

    expect(result.isIntact, isTrue);
    expect(result.checked, 3);
    expect(chain.first.previousHash, ChainOfCustody.genesis);
    expect(chain[1].previousHash, chain[0].chainHash);
  });

  test('isi bukti yang diubah setelah disegel terdeteksi', () {
    final chain = buildChain(['pesan asli', 'pesan dua']);
    final tampered = EvidenceItem(
      id: chain[0].id,
      familyId: chain[0].familyId,
      childId: chain[0].childId,
      kind: chain[0].kind,
      capturedAt: chain[0].capturedAt,
      recordedAt: chain[0].recordedAt,
      description: chain[0].description,
      contentHash: chain[0].contentHash,
      chainHash: chain[0].chainHash,
      sequence: chain[0].sequence,
      previousHash: chain[0].previousHash,
      payload: 'pesan sudah diubah',
    );

    final result = custody.verify([tampered, chain[1]]);
    expect(result.isIntact, isFalse);
    expect(result.brokenAt, 1);
    expect(result.reason, contains('berubah'));
  });

  test('bukti yang dihapus di tengah memutus urutan', () {
    final chain = buildChain(['satu', 'dua', 'tiga']);
    final result = custody.verify([chain[0], chain[2]]);

    expect(result.isIntact, isFalse);
    expect(result.brokenAt, 3);
    expect(result.reason, contains('dihapus atau disisipkan'));
  });

  test('entri yang dipindahkan ke rantai lain tidak tersambung', () {
    final chainA = buildChain(['a1', 'a2']);
    final chainB = buildChain(['b1', 'b2']);
    final result = custody.verify([chainA[0], chainB[1]]);

    expect(result.isIntact, isFalse);
    expect(result.brokenAt, 2);
  });

  test('stempel waktu ikut mengunci hash rantai', () {
    final item = seal('isi sama', null, 0);
    final recomputedWithOtherTime = custody.linkHash(
      previousHash: ChainOfCustody.genesis,
      contentHash: item.contentHash,
      recordedAt: item.recordedAt.add(const Duration(seconds: 1)),
      sequence: item.sequence,
    );

    expect(recomputedWithOtherTime, isNot(item.chainHash));
  });

  test('isi yang sama menghasilkan hash isi yang sama', () {
    expect(custody.hashContent('halo'), custody.hashContent('halo'));
    expect(custody.hashContent('halo'), isNot(custody.hashContent('halo ')));
    expect(custody.hashContent('halo').length, 64);
  });

  group('galat zona waktu versi lama', () {
    // Versi lama mengirim waktu lokal tanpa zona ke Supabase, yang
    // menyimpannya seolah UTC. Di Makassar (WITA, UTC+8) waktu tersimpan
    // bergeser +8 jam dari waktu yang dipakai saat menyegel.
    EvidenceItem storedWithShift(
      EvidenceItem item,
      Duration shift, {
      String? payload,
      String? chainHash,
    }) => EvidenceItem(
      id: item.id,
      familyId: item.familyId,
      childId: item.childId,
      kind: item.kind,
      capturedAt: item.capturedAt.add(shift),
      recordedAt: item.recordedAt.add(shift),
      description: item.description,
      contentHash: item.contentHash,
      chainHash: chainHash ?? item.chainHash,
      sequence: item.sequence,
      previousHash: item.previousHash,
      payload: payload ?? item.payload,
    );

    test('waktu bergeser tetapi isi utuh: utuh, dengan catatan jujur', () {
      const wita = Duration(hours: 8);
      final chain = buildChain([
        'satu',
        'dua',
        'tiga',
      ]).map((e) => storedWithShift(e, wita)).toList();

      final result = custody.verify(chain);

      expect(result.isIntact, isTrue);
      expect(result.timeShifts, {1: wita, 2: wita, 3: wita});
      expect(result.reason, contains('#1-#3'));
      expect(result.reason, contains('+8 jam'));
    });

    test(
      'bukti lama yang bergeser dan bukti baru yang benar bisa bersambung',
      () {
        final old = buildChain(['satu', 'dua']);
        final fixed = seal('tiga', old.last, 2);
        final chain = [
          ...old.map((e) => storedWithShift(e, const Duration(hours: 8))),
          fixed,
        ];

        final result = custody.verify(chain);

        expect(result.isIntact, isTrue);
        expect(result.timeShifts.keys, [1, 2]);
      },
    );

    test('pergeseran waktu tidak bisa menutupi isi yang diubah', () {
      final chain = buildChain(['satu', 'dua']);
      final tampered = [
        storedWithShift(chain[0], const Duration(hours: 8), payload: 'palsu'),
        storedWithShift(chain[1], const Duration(hours: 8)),
      ];

      final result = custody.verify(tampered);

      expect(result.isIntact, isFalse);
      expect(result.brokenAt, 1);
    });

    test('stempel palsu tetap terdeteksi walau waktunya dicoba digeser', () {
      final chain = buildChain(['satu']);
      final forged = storedWithShift(
        chain.single,
        const Duration(hours: 8),
        chainHash: 'f' * 64,
      );

      expect(custody.verify([forged]).isIntact, isFalse);
    });

    test('bukti baru disimpan dengan zona waktu UTC', () {
      final item = seal('satu', null, 0);
      final map = item.toMap();
      expect(map['recordedAt'], endsWith('Z'));
      expect(map['capturedAt'], endsWith('Z'));
      expect(
        DateTime.parse(
          map['recordedAt'] as String,
        ).isAtSameMomentAs(item.recordedAt),
        isTrue,
      );
    });
  });
}
