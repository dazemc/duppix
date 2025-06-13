// example/main.dart
import '../lib/duppix.dart';

void main() {
  print('🚀 Duppix Regex Library Examples\n');

  // Example 1: Basic Pattern Matching
  basicPatternMatching();

  // Example 2: Named Capture Groups
  namedCaptureGroups();

  // Example 3: Advanced Features
  advancedFeatures();

  // Example 4: String Operations
  stringOperations();

  print('\n✅ All examples completed!');
}

void basicPatternMatching() {
  print('📋 Example 1: Basic Pattern Matching');
  print('=' * 40);

  try {
    // Simple word matching
    final wordRegex = DuppixRegex(r'\w+');
    final text = 'Hello world 123';

    print('Pattern: ${wordRegex.pattern}');
    print('Text: "$text"');

    // Test hasMatch
    print('Has match: ${wordRegex.hasMatch(text)}');

    // Get first match
    final firstMatch = wordRegex.firstMatch(text);
    if (firstMatch != null) {
      print('First match: "${firstMatch.group}" at position ${firstMatch.start}-${firstMatch.end}');
    }

    // Get all matches
    final allMatches = wordRegex.allMatches(text).toList();
    print('All matches: ${allMatches.map((m) => '"${m.group}"').join(', ')}');

    // Test with numbered groups
    final numberRegex = DuppixRegex(r'(\d+)');
    final numberMatch = numberRegex.firstMatch(text);
    if (numberMatch != null) {
      print('Number found: "${numberMatch.groupAt(1)}" (group 1)');
    }

  } catch (e) {
    print('❌ Error in basic pattern matching: $e');
  }

  print('');
}

void namedCaptureGroups() {
  print('📋 Example 2: Named Capture Groups');
  print('=' * 40);

  try {
    // Email pattern with named groups
    final emailRegex = DuppixRegex(r'(?<username>\w+)@(?<domain>\w+\.\w+)');
    final email = 'john@example.com';

    print('Pattern: ${emailRegex.pattern}');
    print('Email: "$email"');

    final match = emailRegex.firstMatch(email);
    if (match != null) {
      print('Full match: "${match.group}"');
      print('Username: "${match.namedGroup('username')}"');
      print('Domain: "${match.namedGroup('domain')}"');
      print('Group names: ${match.groupNames.join(', ')}');
    } else {
      print('No match found');
    }

  } catch (e) {
    print('❌ Error in named capture groups: $e');
  }

  print('');
}

void advancedFeatures() {
  print('📋 Example 3: Advanced Features');
  print('=' * 40);

  try {
    // Test case-insensitive matching
    final options = DuppixOptions(ignoreCase: true);
    final caseInsensitiveRegex = DuppixRegex(r'HELLO', options: options);
    final text = 'hello world';

    print('Pattern: ${caseInsensitiveRegex.pattern} (case-insensitive)');
    print('Text: "$text"');
    print('Matches: ${caseInsensitiveRegex.hasMatch(text)}');

    // Test multiline mode
    final multilineOptions = DuppixOptions(multiline: true);
    final multilineRegex = DuppixRegex(r'line\d+', options: multilineOptions);
    final multilineText = 'line1\nline2\nline3';

    print('\nMultiline pattern: ${multilineRegex.pattern}');
    print('Text: "$multilineText"');
    final multilineMatches = multilineRegex.allMatches(multilineText).toList();
    print('Matches: ${multilineMatches.map((m) => '"${m.group}"').join(', ')}');

    // Test engine type
    print('\nEngine info:');
    print('Uses fallback: ${caseInsensitiveRegex.usesFallback}');
    print('Uses custom engine: ${caseInsensitiveRegex.usesCustomEngine}');

  } catch (e) {
    print('❌ Error in advanced features: $e');
  }

  print('');
}

void stringOperations() {
  print('📋 Example 4: String Operations');
  print('=' * 40);

  try {
    final regex = DuppixRegex(r'\d+');
    final text = 'I have 5 apples and 10 oranges';

    print('Pattern: ${regex.pattern}');
    print('Original: "$text"');

    // Replace operations
    final replacedAll = regex.replaceAll(text, 'X');
    print('Replace all numbers with X: "$replacedAll"');

    final replacedFirst = regex.replaceFirst(text, 'NUMBER');
    print('Replace first number: "$replacedFirst"');

    // Split operation
    final splitText = 'apple,banana,cherry';
    final commaRegex = DuppixRegex(r',');
    final parts = commaRegex.split(splitText);
    print('\nSplit "$splitText" by comma: ${parts.map((p) => '"$p"').join(', ')}');

    // String matches
    final stringMatches = regex.allStringMatches(text).toList();
    print('All number strings: ${stringMatches.map((s) => '"$s"').join(', ')}');

  } catch (e) {
    print('❌ Error in string operations: $e');
  }

  print('');
}

// Helper function to demonstrate error handling
void demonstrateErrorHandling() {
  print('📋 Error Handling Demo');
  print('=' * 40);

  try {
    // This should work fine
    final validRegex = DuppixRegex(r'test');
    print('✅ Valid regex created: ${validRegex.pattern}');

    // This might cause issues depending on implementation
    final complexRegex = DuppixRegex(r'(?<name>\w+)\s+(?=\d+)');
    print('✅ Complex regex created: ${complexRegex.pattern}');

  } catch (e) {
    print('❌ Caught exception: $e');
    if (e is DuppixException) {
      print('   Error type: Duppix-specific error');
    } else {
      print('   Error type: General error');
    }
  }
}