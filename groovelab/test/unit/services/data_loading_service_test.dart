import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:groovelab/services/data_loading_service.dart';

void main() {
  group('DataLoadingService', () {
    test('provider creates instance', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final service = container.read(dataLoadingServiceProvider);
      expect(service, isA<DataLoadingService>());
    });
  });
}
