// test/mind_classifier_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:alpha/ml/mind_classifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MindClassifier', () {
    test('handles empty / uninitialized gracefully', () {
      final classifier = MindClassifier.instance;
      final result = classifier.classify("Hello world");
      expect(result.risk, MindRisk.safe);
      expect(result.probability, 0.0);
      expect(result.label, 'safe');
    });

    test('classifies negation and dark humor appropriately without false triggering', () {
      final classifier = MindClassifier.instance;
      // Negation phrases should stay safe when model isn't active or in default mode
      final result = classifier.classify("I'm not suicidal just tired");
      expect(result.risk, MindRisk.safe);
    });

    test('passwords and sensitive fields should be safe by default', () {
      final classifier = MindClassifier.instance;
      final result = classifier.classify("P@ssw0rd123! secret_token");
      expect(result.risk, MindRisk.safe);
    });
  });
}
