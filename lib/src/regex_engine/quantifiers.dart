import 'core.dart';

/// Types of quantifier behavior
enum QuantifierType {
  greedy,    // * + ? {n,m}
  lazy,      // *? +? ?? {n,m}?
  possessive // *+ ++ ?+ {n,m}+ (no backtracking)
}

/// Quantifier node - handles *, +, ?, {n,m} and their variants
class QuantifierNode extends RegexNode {
  final RegexNode child;
  final int min;
  final int max; // -1 for infinite
  final QuantifierType type;

  const QuantifierNode(
      this.child,
      this.min,
      this.max,
      {this.type = QuantifierType.greedy}
      );

  // Factory constructors for common quantifiers
  factory QuantifierNode.star(RegexNode child, {QuantifierType type = QuantifierType.greedy}) {
    return QuantifierNode(child, 0, -1, type: type);
  }

  factory QuantifierNode.plus(RegexNode child, {QuantifierType type = QuantifierType.greedy}) {
    return QuantifierNode(child, 1, -1, type: type);
  }

  factory QuantifierNode.question(RegexNode child, {QuantifierType type = QuantifierType.greedy}) {
    return QuantifierNode(child, 0, 1, type: type);
  }

  @override
  List<MatchResult> execute(String input, int position, MatchContext context) {
    switch (type) {
      case QuantifierType.greedy:
        return _executeGreedy(input, position, context);
      case QuantifierType.lazy:
        return _executeLazy(input, position, context);
      case QuantifierType.possessive:
        return _executePossessive(input, position, context);
    }
  }

  List<MatchResult> _executeGreedy(String input, int position, MatchContext context) {
    final results = <MatchResult>[];

    // Try to match as many times as possible, then backtrack
    void tryMatch(int currentPos, int matchCount, Map<String, CaptureGroup> captures, List<CaptureGroup?> numbered) {
      // If we've reached the minimum, this is a valid result
      if (matchCount >= min) {
        results.add(MatchResult(
          endPosition: currentPos,
          namedCaptures: Map.from(captures),
          numberedCaptures: List.from(numbered),
          isSuccess: true,
        ));
      }

      // Try to match one more time if we haven't reached the maximum
      if ((max == -1 || matchCount < max) && currentPos < input.length) {
        final childResults = child.execute(input, currentPos, context);

        for (final result in childResults) {
          if (result.isSuccess && result.endPosition > currentPos) {
            // Merge captures
            final newCaptures = Map<String, CaptureGroup>.from(captures)..addAll(result.namedCaptures);
            final newNumbered = _mergeNumberedCaptures(numbered, result.numberedCaptures);

            tryMatch(result.endPosition, matchCount + 1, newCaptures, newNumbered);
          }
        }
      }
    }

    tryMatch(position, 0, {}, []);

    // Sort results by end position (greedy - prefer longer matches)
    results.sort((a, b) => b.endPosition.compareTo(a.endPosition));

    return results.isEmpty ? [MatchResult.failed] : results;
  }

  List<MatchResult> _executeLazy(String input, int position, MatchContext context) {
    final results = <MatchResult>[];

    // Try to match as few times as possible, then try more
    void tryMatch(int currentPos, int matchCount, Map<String, CaptureGroup> captures, List<CaptureGroup?> numbered) {
      // If we've reached the minimum, this is a valid result
      if (matchCount >= min) {
        results.add(MatchResult(
          endPosition: currentPos,
          namedCaptures: Map.from(captures),
          numberedCaptures: List.from(numbered),
          isSuccess: true,
        ));
      }

      // Try to match one more time if we haven't reached the maximum
      if ((max == -1 || matchCount < max) && currentPos < input.length) {
        final childResults = child.execute(input, currentPos, context);

        for (final result in childResults) {
          if (result.isSuccess && result.endPosition > currentPos) {
            final newCaptures = Map<String, CaptureGroup>.from(captures)..addAll(result.namedCaptures);
            final newNumbered = _mergeNumberedCaptures(numbered, result.numberedCaptures);

            tryMatch(result.endPosition, matchCount + 1, newCaptures, newNumbered);
          }
        }
      }
    }

    tryMatch(position, 0, {}, []);

    // Sort results by end position (lazy - prefer shorter matches)
    results.sort((a, b) => a.endPosition.compareTo(b.endPosition));

    return results.isEmpty ? [MatchResult.failed] : results;
  }

  List<MatchResult> _executePossessive(String input, int position, MatchContext context) {
    // Possessive quantifiers match as much as possible and never backtrack
    int currentPos = position;
    int matchCount = 0;
    Map<String, CaptureGroup> allCaptures = {};
    List<CaptureGroup?> allNumbered = [];

    // Match as many times as possible
    while ((max == -1 || matchCount < max) && currentPos < input.length) {
      final childResults = child.execute(input, currentPos, context);

      // Take the first successful match (possessive - no backtracking)
      final successResult = childResults.where((r) => r.isSuccess && r.endPosition > currentPos).firstOrNull;

      if (successResult == null) break;

      allCaptures.addAll(successResult.namedCaptures);
      allNumbered = _mergeNumberedCaptures(allNumbered, successResult.numberedCaptures);
      currentPos = successResult.endPosition;
      matchCount++;
    }

    // Check if we matched at least the minimum required
    if (matchCount >= min) {
      return [MatchResult(
        endPosition: currentPos,
        namedCaptures: allCaptures,
        numberedCaptures: allNumbered,
        isSuccess: true,
      )];
    }

    return [MatchResult.failed];
  }

  List<CaptureGroup?> _mergeNumberedCaptures(List<CaptureGroup?> existing, List<CaptureGroup?> newCaptures) {
    final result = List<CaptureGroup?>.from(existing);

    for (int i = 0; i < newCaptures.length; i++) {
      while (result.length <= i) result.add(null);
      if (newCaptures[i] != null) {
        result[i] = newCaptures[i];
      }
    }

    return result;
  }

  @override
  bool canMatch(String input, int position) {
    // If minimum is 0, we can always match (even empty match)
    if (min == 0) return true;

    // Otherwise, check if child can match
    return child.canMatch(input, position);
  }

  @override
  (int, int) getLengthBounds() {
    final (childMin, childMax) = child.getLengthBounds();

    final minLength = min * childMin;
    final maxLength = max == -1 ? double.maxFinite.toInt() : max * childMax;

    return (minLength, maxLength);
  }
}

/// Atomic group (?>...) - prevents backtracking within the group
class AtomicGroupNode extends RegexNode {
  final RegexNode child;

  const AtomicGroupNode(this.child);

  @override
  List<MatchResult> execute(String input, int position, MatchContext context) {
    final childResults = child.execute(input, position, context);

    // Take only the first successful result (atomic - no backtracking)
    final firstSuccess = childResults.where((r) => r.isSuccess).firstOrNull;

    return firstSuccess != null ? [firstSuccess] : [MatchResult.failed];
  }

  @override
  bool canMatch(String input, int position) {
    return child.canMatch(input, position);
  }

  @override
  (int, int) getLengthBounds() {
    return child.getLengthBounds();
  }
}

/// Lookahead assertion (?=...) or (?!...)
class LookaheadNode extends RegexNode {
  final RegexNode child;
  final bool positive;

  const LookaheadNode(this.child, {this.positive = true});

  @override
  List<MatchResult> execute(String input, int position, MatchContext context) {
    final childResults = child.execute(input, position, context);
    final hasMatch = childResults.any((r) => r.isSuccess);

    final shouldMatch = positive ? hasMatch : !hasMatch;

    if (shouldMatch) {
      return [MatchResult(
        endPosition: position, // Lookahead doesn't consume characters
        namedCaptures: {},
        numberedCaptures: [],
        isSuccess: true,
      )];
    }

    return [MatchResult.failed];
  }

  @override
  bool canMatch(String input, int position) {
    final childResults = child.execute(input, position, MatchContext());
    final hasMatch = childResults.any((r) => r.isSuccess);
    return positive ? hasMatch : !hasMatch;
  }

  @override
  (int, int) getLengthBounds() => (0, 0); // Lookahead consumes no characters
}

/// Lookbehind assertion (?<=...) or (?<!...)
class LookbehindNode extends RegexNode {
  final RegexNode child;
  final bool positive;
  final int maxLookbehind;

  const LookbehindNode(this.child, {this.positive = true, this.maxLookbehind = 100});

  @override
  List<MatchResult> execute(String input, int position, MatchContext context) {
    // Try different positions before the current position
    final (minLen, maxLen) = child.getLengthBounds();
    final startCheck = (position - maxLen).clamp(0, position);
    final endCheck = (position - minLen).clamp(0, position);

    bool hasMatch = false;

    for (int checkPos = startCheck; checkPos <= endCheck; checkPos++) {
      final childResults = child.execute(input, checkPos, context);

      for (final result in childResults) {
        if (result.isSuccess && result.endPosition == position) {
          hasMatch = true;
          break;
        }
      }

      if (hasMatch) break;
    }

    final shouldMatch = positive ? hasMatch : !hasMatch;

    if (shouldMatch) {
      return [MatchResult(
        endPosition: position, // Lookbehind doesn't consume characters
        namedCaptures: {},
        numberedCaptures: [],
        isSuccess: true,
      )];
    }

    return [MatchResult.failed];
  }

  @override
  bool canMatch(String input, int position) {
    final (minLen, maxLen) = child.getLengthBounds();
    final startCheck = (position - maxLen).clamp(0, position);
    final endCheck = (position - minLen).clamp(0, position);

    for (int checkPos = startCheck; checkPos <= endCheck; checkPos++) {
      final childResults = child.execute(input, checkPos, MatchContext());

      for (final result in childResults) {
        if (result.isSuccess && result.endPosition == position) {
          return positive;
        }
      }
    }

    return !positive;
  }

  @override
  (int, int) getLengthBounds() => (0, 0); // Lookbehind consumes no characters
}