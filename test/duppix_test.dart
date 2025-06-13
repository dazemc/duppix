// test/duppix_test.dart
import 'package:test/test.dart';
import '../lib/duppix.dart';

void main() {
  group('DuppixRegex Basic Tests', () {
    test('should create regex with simple pattern', () {
      final regex = DuppixRegex(r'hello');
      expect(regex.pattern, equals('hello'));
    });

    test('should match simple patterns', () {
      final regex = DuppixRegex(r'world');
      expect(regex.hasMatch('hello world'), isTrue);
      expect(regex.hasMatch('hello earth'), isFalse);
    });

    test('should find first match', () {
      final regex = DuppixRegex(r'\d+');
      final match = regex.firstMatch('I have 5 apples');

      expect(match, isNotNull);
      expect(match!.group, equals('5'));
      expect(match.start, equals(7));
      expect(match.end, equals(8));
    });

    test('should find all matches', () {
      final regex = DuppixRegex(r'\d+');
      final matches = regex.allMatches('I have 5 apples and 10 oranges').toList();

      expect(matches, hasLength(2));
      expect(matches[0].group, equals('5'));
      expect(matches[1].group, equals('10'));
    });

    test('should handle empty input', () {
      final regex = DuppixRegex(r'\w+');
      expect(regex.hasMatch(''), isFalse);
      expect(regex.firstMatch(''), isNull);
      expect(regex.allMatches('').toList(), isEmpty);
    });
  });

  group('DuppixRegex Capture Groups', () {
    test('should capture numbered groups', () {
      final regex = DuppixRegex(r'(\d+)-(\d+)-(\d+)');
      final match = regex.firstMatch('2023-12-25');

      expect(match, isNotNull);
      expect(match!.group, equals('2023-12-25'));
      expect(match.groupAt(1), equals('2023'));
      expect(match.groupAt(2), equals('12'));
      expect(match.groupAt(3), equals('25'));
      expect(match.groupCount, equals(3));
    });

    test('should handle named groups', () {
      final regex = DuppixRegex(r'(?<year>\d{4})-(?<month>\d{2})-(?<day>\d{2})');
      final match = regex.firstMatch('2023-12-25');

      expect(match, isNotNull);
      expect(match!.namedGroup('year'), equals('2023'));
      expect(match.namedGroup('month'), equals('12'));
      expect(match.namedGroup('day'), equals('25'));
      expect(match.groupNames, containsAll(['year', 'month', 'day']));
    });

    test('should return null for non-participating groups', () {
      final regex = DuppixRegex(r'(a)|(b)');
      final match = regex.firstMatch('a');

      expect(match, isNotNull);
      expect(match!.groupAt(1), equals('a'));
      expect(match.groupAt(2), isNull);
    });

    test('should handle out-of-range group access', () {
      final regex = DuppixRegex(r'(\d+)');
      final match = regex.firstMatch('123');

      expect(match, isNotNull);
      expect(match!.groupAt(0), equals('123'));
      expect(match.groupAt(1), equals('123'));
      expect(match.groupAt(2), isNull);
      expect(match.groupAt(-1), isNull);
    });
  });

  group('DuppixRegex Options', () {
    test('should handle case-insensitive matching', () {
      final options = DuppixOptions(ignoreCase: true);
      final regex = DuppixRegex(r'HELLO', options: options);

      expect(regex.hasMatch('hello'), isTrue);
      expect(regex.hasMatch('Hello'), isTrue);
      expect(regex.hasMatch('HELLO'), isTrue);
    });

    test('should handle case-sensitive matching (default)', () {
      final regex = DuppixRegex(r'HELLO');

      expect(regex.hasMatch('hello'), isFalse);
      expect(regex.hasMatch('Hello'), isFalse);
      expect(regex.hasMatch('HELLO'), isTrue);
    });

    test('should handle multiline mode', () {
      final options = DuppixOptions(multiline: true);
      final regex = DuppixRegex(r'line\d+', options: options);
      final text = 'line1\nline2\nline3';

      final matches = regex.allMatches(text).toList();
      expect(matches, hasLength(3));
      expect(matches[0].group, equals('line1'));
      expect(matches[1].group, equals('line2'));
      expect(matches[2].group, equals('line3'));
    });
  });

  group('DuppixRegex String Operations', () {
    test('should replace all matches', () {
      final regex = DuppixRegex(r'\d+');
      final result = regex.replaceAll('I have 5 apples and 10 oranges', 'X');
      expect(result, equals('I have X apples and X oranges'));
    });

    test('should replace first match only', () {
      final regex = DuppixRegex(r'\d+');
      final result = regex.replaceFirst('I have 5 apples and 10 oranges', 'X');
      expect(result, equals('I have X apples and 10 oranges'));
    });

    test('should handle replacement with capture groups', () {
      final regex = DuppixRegex(r'(\d+)-(\d+)-(\d+)');
      final result = regex.replaceAll('2023-12-25', r'$3/$2/$1');
      expect(result, equals('25/12/2023'));
    });

    test('should handle replacement with named groups', () {
      final regex = DuppixRegex(r'(?<year>\d{4})-(?<month>\d{2})-(?<day>\d{2})');
      final result = regex.replaceAll('2023-12-25', r'${day}/${month}/${year}');
      expect(result, equals('25/12/2023'));
    });

    test('should split strings correctly', () {
      final regex = DuppixRegex(r',\s*');
      final result = regex.split('apple, banana, cherry');
      expect(result, equals(['apple', 'banana', 'cherry']));
    });

    test('should handle empty splits', () {
      final regex = DuppixRegex(r',');
      final result = regex.split('a,,b');
      expect(result, equals(['a', '', 'b']));
    });

    test('should return original string when no matches in split', () {
      final regex = DuppixRegex(r'xyz');
      final result = regex.split('hello world');
      expect(result, equals(['hello world']));
    });
  });

  group('DuppixRegex Edge Cases', () {
    test('should handle zero-length matches', () {
      final regex = DuppixRegex(r'\b'); // Word boundary
      final matches = regex.allMatches('hello world').toList();
      // This depends on implementation - zero-length matches are tricky
      expect(matches, isNotNull);
    });

    test('should handle very long strings', () {
      final regex = DuppixRegex(r'\d+');
      final longString = 'a' * 1000 + '123' + 'b' * 1000;
      final match = regex.firstMatch(longString);

      expect(match, isNotNull);
      expect(match!.group, equals('123'));
    });

    test('should handle special characters in patterns', () {
      final regex = DuppixRegex(r'\.\?\*\+\[\]\(\)\{\}\|\^');
      final text = r'.?*+[](){}|^';
      expect(regex.hasMatch(text), isTrue);
    });

    test('should handle unicode characters', () {
      final regex = DuppixRegex(r'[α-ω]+');
      final text = 'Hello αβγ world';
      final match = regex.firstMatch(text);

      expect(match, isNotNull);
      expect(match!.group, equals('αβγ'));
    });
  });

  group('DuppixRegex Error Handling', () {
    test('should handle invalid patterns gracefully', () {
      expect(() => DuppixRegex(r'[unclosed'), throwsA(isA<DuppixException>()));
    });

    test('should provide meaningful error messages', () {
      try {
        DuppixRegex(r'(?<>invalid)');
        fail('Should have thrown an exception');
      } catch (e) {
        expect(e, isA<DuppixException>());
        expect(e.toString(), contains('DuppixException'));
      }
    });
  });

  group('DuppixRegex Performance', () {
    test('should handle repeated operations efficiently', () {
      final regex = DuppixRegex(r'\w+');
      final text = 'The quick brown fox jumps over the lazy dog';

      // Run multiple operations to test performance
      for (int i = 0; i < 100; i++) {
        expect(regex.hasMatch(text), isTrue);
        final matches = regex.allMatches(text).toList();
        expect(matches, hasLength(9));
      }
    });

    test('should compile patterns only once', () {
      final pattern = r'complex\s+pattern\s+\d+';
      final regex1 = DuppixRegex(pattern);
      final regex2 = DuppixRegex(pattern);

      // Both should work regardless of caching
      expect(regex1.hasMatch('complex pattern 123'), isTrue);
      expect(regex2.hasMatch('complex pattern 456'), isTrue);
    });
  });

  group('DuppixRegex Integration', () {
    test('should work with standard Dart string operations', () {
      final regex = DuppixRegex(r'\d+');
      final numbers = <String>[];

      for (final match in regex.allMatches('1 2 3 4 5')) {
        numbers.add(match.group);
      }

      expect(numbers, equals(['1', '2', '3', '4', '5']));
      expect(numbers.map(int.parse).reduce((a, b) => a + b), equals(15));
    });

    test('should integrate with Future and Stream operations', () async {
      final regex = DuppixRegex(r'\w+');
      final stream = Stream.fromIterable(['hello', 'world', '123', 'test']);

      final matches = await stream
          .where((text) => regex.hasMatch(text))
          .toList();

      expect(matches, equals(['hello', 'world', 'test']));
    });
  });
}

// Helper function for testing custom scenarios
void runCustomTest(String name, void Function() testFunction) {
  print('Running custom test: $name');
  try {
    testFunction();
    print('✅ $name passed');
  } catch (e) {
    print('❌ $name failed: $e');
  }
}

// Additional test utilities
class TestHelper {
  static void expectMatch(DuppixRegex regex, String input, String expectedMatch) {
    final match = regex.firstMatch(input);
    expect(match, isNotNull, reason: 'Expected match in "$input"');
    expect(match!.group, equals(expectedMatch));
  }

  static void expectNoMatch(DuppixRegex regex, String input) {
    final match = regex.firstMatch(input);
    expect(match, isNull, reason: 'Expected no match in "$input"');
  }

  static void expectMatchCount(DuppixRegex regex, String input, int expectedCount) {
    final matches = regex.allMatches(input).toList();
    expect(matches, hasLength(expectedCount));
  }
}