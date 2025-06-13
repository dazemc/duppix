import 'core.dart';

/// Capture group (...) or (?<name>...)
class CaptureGroupNode extends RegexNode {
  final RegexNode child;
  final int? groupNumber;
  final String? groupName;

  const CaptureGroupNode(this.child, {this.groupNumber, this.groupName});

  @override
  List<MatchResult> execute(String input, int position, MatchContext context) {
    final childResults = child.execute(input, position, context);
    final results = <MatchResult>[];

    for (final result in childResults) {
      if (result.isSuccess) {
        final captureText = input.substring(position, result.endPosition);
        final capture = CaptureGroup(position, result.endPosition, captureText);

        final newNamedCaptures = Map<String, CaptureGroup>.from(result.namedCaptures);
        final newNumberedCaptures = List<CaptureGroup?>.from(result.numberedCaptures);

        // Add named capture if this group has a name
        if (groupName != null) {
          newNamedCaptures[groupName!] = capture;
          context.addNamedCapture(groupName!, capture);
        }

        // Add numbered capture if this group has a number
        if (groupNumber != null) {
          while (newNumberedCaptures.length <= groupNumber!) {
            newNumberedCaptures.add(null);
          }
          newNumberedCaptures[groupNumber!] = capture;
          context.addNumberedCapture(groupNumber!, capture);
        }

        results.add(MatchResult(
          endPosition: result.endPosition,
          namedCaptures: newNamedCaptures,
          numberedCaptures: newNumberedCaptures,
          isSuccess: true,
        ));
      }
    }

    return results.isEmpty ? [MatchResult.failed] : results;
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

/// Non-capturing group (?:...)
class NonCapturingGroupNode extends RegexNode {
  final RegexNode child;

  const NonCapturingGroupNode(this.child);

  @override
  List<MatchResult> execute(String input, int position, MatchContext context) {
    return child.execute(input, position, context);
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

/// Backreference \1, \2, etc. or \k<name>
class BackreferenceNode extends RegexNode {
  final int? groupNumber;
  final String? groupName;
  final bool caseSensitive;

  const BackreferenceNode({
    this.groupNumber,
    this.groupName,
    this.caseSensitive = true,
  }) : assert(groupNumber != null || groupName != null);

  @override
  List<MatchResult> execute(String input, int position, MatchContext context) {
    String? capturedText;

    // Get the captured text from the appropriate group
    if (groupName != null) {
      final captures = context.allNamedCaptures[groupName!];
      capturedText = captures?.lastOrNull?.text;
    } else if (groupNumber != null) {
      if (groupNumber! < context.allNumberedCaptures.length) {
        final captures = context.allNumberedCaptures[groupNumber!];
        capturedText = captures.lastOrNull?.text;
      }
    }

    // If no capture exists yet, this backreference fails
    if (capturedText == null) {
      return [MatchResult.failed];
    }

    // Check if the input at current position matches the captured text
    if (position + capturedText.length > input.length) {
      return [MatchResult.failed];
    }

    final inputSubstring = input.substring(position, position + capturedText.length);
    final matches = caseSensitive
        ? inputSubstring == capturedText
        : inputSubstring.toLowerCase() == capturedText.toLowerCase();

    if (matches) {
      return [MatchResult(
        endPosition: position + capturedText.length,
        namedCaptures: {},
        numberedCaptures: [],
        isSuccess: true,
      )];
    }

    return [MatchResult.failed];
  }

  @override
  bool canMatch(String input, int position) {
    // We can't know for sure without the context, so return true optimistically
    return true;
  }

  @override
  (int, int) getLengthBounds() {
    // Backreferences can match variable lengths depending on what was captured
    return (0, double.maxFinite.toInt());
  }
}

/// Conditional pattern (?(condition)yes|no)
class ConditionalNode extends RegexNode {
  final ConditionalCondition condition;
  final RegexNode yesPattern;
  final RegexNode? noPattern;

  const ConditionalNode(this.condition, this.yesPattern, [this.noPattern]);

  @override
  List<MatchResult> execute(String input, int position, MatchContext context) {
    final conditionMet = condition.evaluate(input, position, context);

    final patternToUse = conditionMet ? yesPattern : noPattern;

    if (patternToUse == null) {
      // No pattern for this condition, return empty match
      return [MatchResult(
        endPosition: position,
        namedCaptures: {},
        numberedCaptures: [],
        isSuccess: true,
      )];
    }

    return patternToUse.execute(input, position, context);
  }

  @override
  bool canMatch(String input, int position) {
    final conditionMet = condition.evaluate(input, position, MatchContext());
    final patternToUse = conditionMet ? yesPattern : noPattern;
    return patternToUse?.canMatch(input, position) ?? true;
  }

  @override
  (int, int) getLengthBounds() {
    final yesBounds = yesPattern.getLengthBounds();
    final noBounds = noPattern?.getLengthBounds() ?? (0, 0);

    final minLength = yesBounds.$1 < noBounds.$1 ? yesBounds.$1 : noBounds.$1;
    final maxLength = yesBounds.$2 > noBounds.$2 ? yesBounds.$2 : noBounds.$2;

    return (minLength, maxLength);
  }
}

/// Base class for conditional conditions
abstract class ConditionalCondition {
  bool evaluate(String input, int position, MatchContext context);
}

/// Condition based on whether a group was captured
class GroupCapturedCondition extends ConditionalCondition {
  final int? groupNumber;
  final String? groupName;

  GroupCapturedCondition({this.groupNumber, this.groupName})
      : assert(groupNumber != null || groupName != null);

  @override
  bool evaluate(String input, int position, MatchContext context) {
    if (groupName != null) {
      return context.allNamedCaptures[groupName!]?.isNotEmpty ?? false;
    } else if (groupNumber != null) {
      return groupNumber! < context.allNumberedCaptures.length &&
          context.allNumberedCaptures[groupNumber!].isNotEmpty;
    }
    return false;
  }
}

/// Condition based on a lookahead/lookbehind assertion
class AssertionCondition extends ConditionalCondition {
  final RegexNode assertion;

  AssertionCondition(this.assertion);

  @override
  bool evaluate(String input, int position, MatchContext context) {
    final results = assertion.execute(input, position, context);
    return results.any((r) => r.isSuccess);
  }
}

/// Subroutine call (?1), (?&n), (?R)
class SubroutineCallNode extends RegexNode {
  final int? groupNumber;
  final String? groupName;
  final bool isRecursive; // (?R) or (?0)

  const SubroutineCallNode({
    this.groupNumber,
    this.groupName,
    this.isRecursive = false,
  });

  @override
  List<MatchResult> execute(String input, int position, MatchContext context) {
    // Prevent infinite recursion
    if (context.recursionDepth > 100) {
      return [MatchResult.failed];
    }

    RegexNode? targetNode;

    if (isRecursive) {
      // Recursive call to the entire pattern - we need the root pattern
      // This would be set up during pattern compilation
      targetNode = context.namedGroups['__root__'];
    } else if (groupName != null) {
      targetNode = context.namedGroups[groupName!];
    } else if (groupNumber != null && groupNumber! < context.numberedGroups.length) {
      targetNode = context.numberedGroups[groupNumber!];
    }

    if (targetNode == null) {
      return [MatchResult.failed];
    }

    context.recursionDepth++;
    final results = targetNode.execute(input, position, context);
    context.recursionDepth--;

    return results;
  }

  @override
  bool canMatch(String input, int position) {
    // Optimistically assume subroutine calls can match
    return true;
  }

  @override
  (int, int) getLengthBounds() {
    // Subroutine calls can match variable lengths
    return (0, double.maxFinite.toInt());
  }
}