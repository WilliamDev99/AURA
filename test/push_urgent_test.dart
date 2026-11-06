import 'package:aura/core/services/push_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Saat AURA sedang terbuka, aplikasi sendiri yang memunculkan notifikasi.
/// Bunyinya harus sama dengan keputusan server.
void main() {
  test('server bilang mendesak: kanal Darurat', () {
    expect(
      PushService.isUrgent({'riskLevel': 'critical', 'urgent': 'true'}),
      isTrue,
    );
  });

  test('kata kasar berat: HARD tapi bukan Darurat', () {
    expect(
      PushService.isUrgent({'riskLevel': 'critical', 'urgent': 'false'}),
      isFalse,
    );
  });

  test('server versi lama tanpa "urgent": mengikuti level', () {
    expect(PushService.isUrgent({'riskLevel': 'critical'}), isTrue);
    expect(PushService.isUrgent({'riskLevel': 'high'}), isFalse);
  });
}
