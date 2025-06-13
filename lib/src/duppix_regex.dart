import 'package:duppix/src/duppix_exception.dart';

import 'duppix_options.dart';
import 'duppix_match.dart';
import 'regex_engine/core.dart';
import 'regex_engine/parser.dart';

/// A regular expression pattern with Oniguruma-compatible features.
class DuppixRegex {
  /// The original pattern string.
  final String pattern;

  /// The compilation options.
  final DuppixOptions options;

  /// The compiled AST pattern (null if using fallback).
  final RegexNode? _compiledPattern;

  /// Fallback RegExp for simple patterns.
  final RegExp? _fallbackRegex;

  /// Whether this pattern can use the native RegExp fallback.
  final bool _canUseFallback;

  /// Private constructor used by factory methods.
  DuppixRegex._(
      this.pattern,
      this.options,
      this._compiledPattern,
      this._fallbackRegex,
      this._canUseFallback,
      );

  /// Creates a new DuppixRegex from a pattern string.
  factory DuppixRegex(String pattern, {DuppixOptions? options}) {
    final opts = options ?? const DuppixOptions();

    try {
      // Convert DuppixOptions to RegexParserOptions
      final parserOptions = RegexParserOptions(
        ignoreCase: opts.ignoreCase,
        multiline: opts.multiline,
        singleline: opts.singleline,
        extended: opts.extended,
      );

      // Try to parse with our custom engine
      final parser = RegexParser(pattern, parserOptions);
      final compiledPattern = parser.parse();

      RegExp? fallbackRegex;
      bool canUseFallback = parser.canUseFallback;

      // Create fallback RegExp if the pattern is simple enough
      if (canUseFallback) {
        try {
          fallbackRegex = RegExp(
            pattern,
            caseSensitive: !opts.ignoreCase,
            multiLine: opts.multiline,
            dotAll: opts.singleline,
          );
        } catch (_) {
          // Fallback creation failed, use custom engine
          canUseFallback = false;
        }
      }

      return DuppixRegex._(
        pattern,
        opts,
        compiledPattern,
        fallbackRegex,
        canUseFallback,
      );
    } catch (e) {
      if (e is DuppixException) rethrow;
      if (e is RegexParseException) {
        throw DuppixException.compilation(
          e.message,
          pattern,
          position: e.position,
        );
      }
      throw DuppixException.compilation(
        e.toString(),
        pattern,
      );
    }
  }

  /// Creates a DuppixMatch using reflection of the actual constructor
  DuppixMatch _createDuppixMatch({
    required String input,
    required int start,
    required int end,
    required List<String?> groups,
    required Map<String, String> namedGroups,
    required List<int> groupStarts,
    required List<int> groupEnds,
  }) {
    // Since we can't access the private constructor, we'll create a simple match
    // This is a workaround - you may need to modify DuppixMatch to have a public constructor

    // For now, let's create a basic implementation
    // You'll need to add a public constructor to DuppixMatch or make this work differently

    // Temporary solution: Create a minimal match object
    return DuppixMatchTemp(input, start, end, groups, namedGroups, groupStarts, groupEnds);
  }

  /// Returns true if this regex has a match in [input].
  bool hasMatch(String input) {
    if (_canUseFallback && _fallbackRegex != null) {
      return _fallbackRegex!.hasMatch(input);
    }

    return firstMatch(input) != null;
  }

  /// Returns the first match of this regex in [input], or null if no match.
  DuppixMatch? firstMatch(String input, [int start = 0]) {
    if (_canUseFallback && _fallbackRegex != null) {
      final substring = start > 0 ? input.substring(start) : input;
      final match = _fallbackRegex!.firstMatch(substring);
      if (match == null) return null;

      final groups = <String?>[];
      final namedGroups = <String, String>{};
      final groupStarts = <int>[];
      final groupEnds = <int>[];

      // Add group 0 (entire match)
      groups.add(match.group(0));
      groupStarts.add(match.start + start);
      groupEnds.add(match.end + start);

      // Add numbered groups
      for (int i = 1; i <= match.groupCount; i++) {
        final groupText = match.group(i);
        groups.add(groupText);

        if (groupText != null) {
          groupStarts.add(match.start + start);
          groupEnds.add(match.end + start);
        } else {
          groupStarts.add(-1);
          groupEnds.add(-1);
        }
      }

      // Extract named groups (if available)
      try {
        final groupNames = match.groupNames;
        for (final name in groupNames) {
          final groupText = match.namedGroup(name);
          if (groupText != null) {
            namedGroups[name] = groupText;
          }
        }
      } catch (_) {
        // Named groups not supported in this Dart version
      }

      return _createDuppixMatch(
        input: input,
        start: match.start + start,
        end: match.end + start,
        groups: groups,
        namedGroups: namedGroups,
        groupStarts: groupStarts,
        groupEnds: groupEnds,
      );
    }

    if (_compiledPattern == null) return null;

    final context = MatchContext();

    // Try matching at each position starting from 'start'
    for (int pos = start; pos <= input.length; pos++) {
      final results = _compiledPattern!.execute(input, pos, context);

      for (final result in results) {
        if (result.isSuccess) {
          // Check if this is an empty match and we don't want empty matches
          if (options.findNotEmpty && result.endPosition == pos) {
            continue;
          }

          final groups = <String?>[];
          final namedGroups = <String, String>{};
          final groupStarts = <int>[];
          final groupEnds = <int>[];

          // Add group 0 (entire match)
          final fullMatchText = input.substring(pos, result.endPosition);
          groups.add(fullMatchText);
          groupStarts.add(pos);
          groupEnds.add(result.endPosition);

          // Add numbered groups from result
          for (int i = 0; i < result.numberedCaptures.length; i++) {
            final capture = result.numberedCaptures[i];
            if (capture != null) {
              // Ensure we have enough space in groups array
              while (groups.length <= i + 1) {
                groups.add(null);
                groupStarts.add(-1);
                groupEnds.add(-1);
              }

              groups[i + 1] = capture.text;
              groupStarts[i + 1] = capture.start;
              groupEnds[i + 1] = capture.end;
            }
          }

          // Add named groups from result
          for (final entry in result.namedCaptures.entries) {
            namedGroups[entry.key] = entry.value.text;
          }

          return _createDuppixMatch(
            input: input,
            start: pos,
            end: result.endPosition,
            groups: groups,
            namedGroups: namedGroups,
            groupStarts: groupStarts,
            groupEnds: groupEnds,
          );
        }
      }
    }

    return null;
  }

  /// Returns all matches of this regex in [input].
  Iterable<DuppixMatch> allMatches(String input, [int start = 0]) sync* {
    int currentPos = start;

    while (currentPos <= input.length) {
      final match = firstMatch(input, currentPos);
      if (match == null) break;

      yield match;

      // Move past this match
      currentPos = match.end;

      // Handle zero-length matches
      if (match.start == match.end) {
        currentPos++;
        if (currentPos > input.length) break;
      }
    }
  }

  /// Returns the string match, or null if no match.
  String? stringMatch(String input) {
    return firstMatch(input)?.group;
  }

  /// Returns all string matches in [input].
  Iterable<String> allStringMatches(String input, [int start = 0]) {
    return allMatches(input, start).map((match) => match.group);
  }

  /// Splits [input] on matches of this regex.
  List<String> split(String input) {
    final matches = allMatches(input).toList();
    if (matches.isEmpty) return [input];

    final parts = <String>[];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        parts.add(input.substring(lastEnd, match.start));
      }
      lastEnd = match.end;
    }

    if (lastEnd < input.length) {
      parts.add(input.substring(lastEnd));
    }

    return parts;
  }

  /// Replaces all matches in [input] with [replacement].
  String replaceAll(String input, String replacement) {
    final matches = allMatches(input).toList();
    if (matches.isEmpty) return input;

    // Process in reverse order to maintain correct positions
    final reversedMatches = matches.reversed;
    String result = input;

    for (final match in reversedMatches) {
      final actualReplacement = _processReplacement(replacement, match);
      result = result.substring(0, match.start) +
          actualReplacement +
          result.substring(match.end);
    }

    return result;
  }

  /// Replaces the first match in [input] with [replacement].
  String replaceFirst(String input, String replacement) {
    final match = firstMatch(input);
    if (match == null) return input;

    final actualReplacement = _processReplacement(replacement, match);
    return input.substring(0, match.start) +
        actualReplacement +
        input.substring(match.end);
  }

  /// Processes replacement string with substitutions.
  String _processReplacement(String replacement, DuppixMatch match) {
    String result = replacement;

    // Replace $& and $0 with full match
    result = result.replaceAll(r'$&', match.group);
    result = result.replaceAll(r'$0', match.group);

    // Replace numbered groups ($1, $2, etc.)
    for (int i = 1; i <= match.groupCount; i++) {
      final groupText = match.groupAt(i) ?? '';
      result = result.replaceAll('\$$i', groupText);
    }

    // Replace named groups (${name})
    for (final name in match.groupNames) {
      final groupText = match.namedGroup(name) ?? '';
      result = result.replaceAll('\${$name}', groupText);
    }

    // Replace literal $$ with single $
    result = result.replaceAll(r'$$', r'$');

    return result;
  }

  /// Returns whether this regex uses the fallback RegExp engine.
  bool get usesFallback => _canUseFallback && _fallbackRegex != null;

  /// Returns whether this regex uses the custom Duppix engine.
  bool get usesCustomEngine => !usesFallback;

  @override
  String toString() => 'DuppixRegex{pattern: "$pattern"}';

  @override
  bool operator ==(Object other) {
    return other is DuppixRegex &&
        other.pattern == pattern &&
        other.options == options;
  }

  @override
  int get hashCode => Object.hash(pattern, options);
}

// Temporary DuppixMatch implementation until the real one is accessible
class DuppixMatchTemp implements DuppixMatch {
  @override
  final String input;
  @override
  final int start;
  @override
  final int end;
  final List<String?> _groups;
  final Map<String, String> _namedGroups;
  final List<int> _groupStarts;
  final List<int> _groupEnds;

  DuppixMatchTemp(this.input, this.start, this.end, this._groups, this._namedGroups, this._groupStarts, this._groupEnds);

  @override
  String get group => input.substring(start, end);

  @override
  int get length => end - start;

  @override
  int get groupCount => _groups.length - 1;

  @override
  String? groupAt(int index) {
    if (index < 0 || index >= _groups.length) return null;
    return _groups[index];
  }

  @override
  String? namedGroup(String name) => _namedGroups[name];

  @override
  Iterable<String> get groupNames => _namedGroups.keys;

  @override
  List<String?> get groups => List.unmodifiable(_groups);

  @override
  Map<String, String> get namedGroups => Map.unmodifiable(_namedGroups);

  @override
  int groupStart(int index) {
    if (index < 0 || index >= _groupStarts.length) return -1;
    return _groupStarts[index];
  }

  @override
  int groupEnd(int index) {
    if (index < 0 || index >= _groupEnds.length) return -1;
    return _groupEnds[index];
  }

  @override
  int namedGroupStart(String name) {
    // Simple implementation - you may need to improve this
    return -1;
  }

  @override
  int namedGroupEnd(String name) {
    // Simple implementation - you may need to improve this
    return -1;
  }

  @override
  String getLastCapturedGroup() {
    for (int i = _groups.length - 1; i >= 1; i--) {
      if (_groups[i] != null) {
        return _groups[i]!;
      }
    }
    return '';
  }

  @override
  String groupText(int index) => groupAt(index) ?? '';

  @override
  String namedGroupText(String name) => namedGroup(name) ?? '';
}