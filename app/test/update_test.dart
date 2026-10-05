import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/update.dart';

void main() {
  test('versions compare by number, not by text', () {
    expect(isNewer('2.4.10', '2.4.9'), isTrue);
    expect(isNewer('v2.5.0', '2.4.2'), isTrue);
    expect(isNewer('2.4.2', '2.4.2'), isFalse);
    expect(isNewer('2.4.1', '2.4.2'), isFalse);
  });

  test('the release picks the APK for this phone', () {
    final json = {
      'tag_name': 'v2.5.0',
      'body': '- **Corretto**: la `sveglia`.',
      'assets': [
        {'name': 'Taime-2.5.0-arm32.apk', 'browser_download_url': 'https://x/32', 'size': 20},
        {'name': 'Taime-2.5.0-arm64.apk', 'browser_download_url': 'https://x/64', 'size': 23},
      ],
    };
    final r = releaseFrom(json, 'arm64')!;
    expect(r.version, '2.5.0');
    expect(r.url, 'https://x/64');
    expect(r.size, 23);
    expect(r.notes, '- Corretto: la sveglia.');
    expect(releaseFrom(json, 'arm32')!.url, 'https://x/32');
    expect(releaseFrom({...json, 'assets': []}, 'arm64'), isNull);
  });
}
