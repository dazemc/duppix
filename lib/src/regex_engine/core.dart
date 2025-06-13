/// Custom regex engine that implements Oniguruma features not available in Dart's RegExp
library regex_engine;

import 'dart:collection';

/// Extension for List<T> to add safe first/last access
extension ListExtensions<T> on List<T> {
  T? get lastOrNull => isEmpty ? null : last;
  T? get firstOrNull => isEmpty ? null : first;
}

/// Abstract syntax tree node for regex patterns
abstract class RegexNode {
  const RegexNode();

  /// Execute this node against the input string starting at position
  /// Returns a list of possible match results (for backtracking)
  List<MatchResult> execute(String input, int position, MatchContext context);

  /// Estimate if this node can match at the given position (optimization)
  bool canMatch(String input, int position);

  /// Get the minimum and maximum length this node can match
  (int min, int max) getLengthBounds();
}

/// Result of a match attempt
class MatchResult {
  final int endPosition;
  final Map<String, CaptureGroup> namedCaptures;
  final List<CaptureGroup?> numberedCaptures;
  final bool isSuccess;

  const MatchResult({
    required this.endPosition,
    required this.namedCaptures,
    required this.numberedCaptures,
    required this.isSuccess,
  });

  static const failed = MatchResult(
    endPosition: -1,
    namedCaptures: {},
    numberedCaptures: [],
    isSuccess: false,
  );
}

/// Captured group information
class CaptureGroup {
  final int start;
  final int end;
  final String text;

  const CaptureGroup(this.start, this.end, this.text);
}

/// Context for matching operations
class MatchContext {
  final Map<String, RegexNode> namedGroups = {};
  final List<RegexNode> numberedGroups = [];
  final Queue<BacktrackPoint> backtrackStack = Queue(); // Fixed: Use Queue instead of Stack
  final Map<String, List<CaptureGroup>> allNamedCaptures = {};
  final List<List<CaptureGroup>> allNumberedCaptures = [];

  int recursionDepth = 0;
  bool hasMatched = false;

  void pushBacktrack(BacktrackPoint point) {
    backtrackStack.addLast(point); // Fixed: Use addLast
  }

  BacktrackPoint? popBacktrack() {
    return backtrackStack.isEmpty ? null : backtrackStack.removeLast();
  }

  void addNamedCapture(String name, CaptureGroup capture) {
    allNamedCaptures.putIfAbsent(name, () => []).add(capture);
  }

  void addNumberedCapture(int number, CaptureGroup capture) {
    while (allNumberedCaptures.length <= number) {
      allNumberedCaptures.add([]);
    }
    allNumberedCaptures[number].add(capture);
  }
}

/// Point for backtracking
class BacktrackPoint {
  final int position;
  final RegexNode node;
  final Map<String, dynamic> state;

  const BacktrackPoint(this.position, this.node, this.state);
}

/// Literal character match - Fixed to handle multi-character literals
class LiteralNode extends RegexNode {
  final String literal;
  final bool caseSensitive;

  const LiteralNode(this.literal, {this.caseSensitive = true});

  @override
  List<MatchResult> execute(String input, int position, MatchContext context) {
    if (position + literal.length > input.length) return [MatchResult.failed];

    final inputSubstring = input.substring(position, position + literal.length);
    final matches = caseSensitive
        ? inputSubstring == literal
        : inputSubstring.toLowerCase() == literal.toLowerCase();

    if (matches) {
      return [MatchResult(
        endPosition: position + literal.length,
        namedCaptures: {},
        numberedCaptures: [],
        isSuccess: true,
      )];
    }

    return [MatchResult.failed];
  }

  @override
  bool canMatch(String input, int position) {
    if (position + literal.length > input.length) return false;
    final inputSubstring = input.substring(position, position + literal.length);
    return caseSensitive
        ? inputSubstring == literal
        : inputSubstring.toLowerCase() == literal.toLowerCase();
  }

  @override
  (int, int) getLengthBounds() => (literal.length, literal.length);
}

/// Character class match [abc], [^abc], [a-z], etc.
class CharacterClassNode extends RegexNode {
  final Set<int> allowedCodePoints;
  final bool negated;

  const CharacterClassNode(this.allowedCodePoints, {this.negated = false});

  factory CharacterClassNode.fromRanges(List<(int, int)> ranges, {bool negated = false}) {
    final codePoints = <int>{};
    for (final (start, end) in ranges) {
      for (int i = start; i <= end; i++) {
        codePoints.add(i);
      }
    }
    return CharacterClassNode(codePoints, negated: negated);
  }

  @override
  List<MatchResult> execute(String input, int position, MatchContext context) {
    if (position >= input.length) return [MatchResult.failed];

    final codePoint = input.codeUnitAt(position);
    final matches = allowedCodePoints.contains(codePoint);
    final shouldMatch = negated ? !matches : matches;

    if (shouldMatch) {
      return [MatchResult(
        endPosition: position + 1,
        namedCaptures: {},
        numberedCaptures: [],
        isSuccess: true,
      )];
    }

    return [MatchResult.failed];
  }

  @override
  bool canMatch(String input, int position) {
    if (position >= input.length) return false;
    final codePoint = input.codeUnitAt(position);
    final matches = allowedCodePoints.contains(codePoint);
    return negated ? !matches : matches;
  }

  @override
  (int, int) getLengthBounds() => (1, 1);
}

/// Sequence of regex nodes
class SequenceNode extends RegexNode {
  final List<RegexNode> nodes;

  const SequenceNode(this.nodes);

  @override
  List<MatchResult> execute(String input, int position, MatchContext context) {
    final results = <MatchResult>[];

    void backtrack(int nodeIndex, int currentPos, Map<String, CaptureGroup> captures, List<CaptureGroup?> numbered) {
      if (nodeIndex >= nodes.length) {
        results.add(MatchResult(
          endPosition: currentPos,
          namedCaptures: Map.from(captures),
          numberedCaptures: List.from(numbered),
          isSuccess: true,
        ));
        return;
      }

      final node = nodes[nodeIndex];
      final nodeResults = node.execute(input, currentPos, context);

      for (final result in nodeResults) {
        if (result.isSuccess) {
          final newCaptures = Map<String, CaptureGroup>.from(captures)..addAll(result.namedCaptures);
          final newNumbered = List<CaptureGroup?>.from(numbered);

          // Merge numbered captures
          for (int i = 0; i < result.numberedCaptures.length; i++) {
            while (newNumbered.length <= i) newNumbered.add(null);
            if (result.numberedCaptures[i] != null) {
              newNumbered[i] = result.numberedCaptures[i];
            }
          }

          backtrack(nodeIndex + 1, result.endPosition, newCaptures, newNumbered);
        }
      }
    }

    backtrack(0, position, {}, []);
    return results.isEmpty ? [MatchResult.failed] : results;
  }

  @override
  bool canMatch(String input, int position) {
    return nodes.isEmpty || nodes.first.canMatch(input, position);
  }

  @override
  (int, int) getLengthBounds() {
    int minTotal = 0;
    int maxTotal = 0;

    for (final node in nodes) {
      final (min, max) = node.getLengthBounds();
      minTotal += min;

      // Fixed: Handle infinite bounds properly
      if (maxTotal == double.maxFinite.toInt() || max == double.maxFinite.toInt()) {
        maxTotal = double.maxFinite.toInt();
      } else {
        maxTotal += max;
      }
    }

    return (minTotal, maxTotal);
  }
}

/// Alternation (OR) - pattern1|pattern2
class AlternationNode extends RegexNode {
  final List<RegexNode> alternatives;

  const AlternationNode(this.alternatives);

  @override
  List<MatchResult> execute(String input, int position, MatchContext context) {
    final results = <MatchResult>[];

    for (final alternative in alternatives) {
      final altResults = alternative.execute(input, position, context);
      results.addAll(altResults.where((r) => r.isSuccess));
    }

    return results.isEmpty ? [MatchResult.failed] : results;
  }

  @override
  bool canMatch(String input, int position) {
    return alternatives.any((alt) => alt.canMatch(input, position));
  }

  @override
  (int, int) getLengthBounds() {
    if (alternatives.isEmpty) return (0, 0);

    int minOverall = alternatives.first.getLengthBounds().$1;
    int maxOverall = alternatives.first.getLengthBounds().$2;

    for (int i = 1; i < alternatives.length; i++) {
      final (min, max) = alternatives[i].getLengthBounds();
      minOverall = minOverall < min ? minOverall : min;
      maxOverall = maxOverall > max ? maxOverall : max;
    }

    return (minOverall, maxOverall);
  }
}