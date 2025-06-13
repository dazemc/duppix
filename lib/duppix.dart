/// Duppix - A comprehensive regex library with Oniguruma-compatible features
///
/// Duppix provides advanced regular expression functionality including features
/// not available in Dart's built-in RegExp, such as:
/// - Named backreferences (\k<name>)
/// - Possessive quantifiers (*+, ++, ?+)
/// - Atomic groups ((?>...))
/// - Conditional patterns ((?(condition)yes|no))
/// - Recursive patterns ((?R), (?0))
/// - Subroutine calls ((?1), (?&name))
/// - Extended Unicode property support
/// - Variable-length lookbehind
///
/// Example usage:
/// ```dart
/// import 'package:duppix/duppix.dart';
///
/// // Create a regex with named capture groups
/// final regex = DuppixRegex(r'(?<word>\w+)');
/// final match = regex.firstMatch('hello world');
/// print(match?.namedGroup('word')); // 'hello'
///
/// // Use possessive quantifiers (no backtracking)
/// final possessive = DuppixRegex(r'\d++\w');
///
/// // Use atomic groups
/// final atomic = DuppixRegex(r'(?>.*?)end');
/// ```
library duppix;

export 'src/duppix_regex.dart';
export 'src/duppix_match.dart';
export 'src/duppix_exception.dart';
export 'src/duppix_options.dart';

// Export regex engine components for advanced users
export 'src/regex_engine/core.dart' show RegexNode, MatchResult, CaptureGroup;
export 'src/regex_engine/quantifiers.dart' show QuantifierType;

/// Gets the version of the Duppix library.
String getDuppixVersion() => '1.0.0';

/// Options for controlling Duppix regex behavior
const int DUPPIX_OPTION_NONE = 0;
const int DUPPIX_OPTION_IGNORECASE = 1;
const int DUPPIX_OPTION_MULTILINE = 2;
const int DUPPIX_OPTION_SINGLELINE = 4;
const int DUPPIX_OPTION_EXTEND = 8;
const int DUPPIX_OPTION_FIND_LONGEST = 16;
const int DUPPIX_OPTION_FIND_NOT_EMPTY = 32;

// Legacy Oniguruma compatibility constants
const int ONIG_OPTION_NONE = DUPPIX_OPTION_NONE;
const int ONIG_OPTION_IGNORECASE = DUPPIX_OPTION_IGNORECASE;
const int ONIG_OPTION_MULTILINE = DUPPIX_OPTION_MULTILINE;
const int ONIG_OPTION_SINGLELINE = DUPPIX_OPTION_SINGLELINE;
const int ONIG_OPTION_EXTEND = DUPPIX_OPTION_EXTEND;
const int ONIG_OPTION_FIND_LONGEST = DUPPIX_OPTION_FIND_LONGEST;
const int ONIG_OPTION_FIND_NOT_EMPTY = DUPPIX_OPTION_FIND_NOT_EMPTY;
