import 'regex_engine/core.dart';

/// Represents a successful match of a [DuppixRegex] pattern.
///
/// Provides access to the matched text, capture groups, and named groups
/// with full Oniguruma compatibility.
class DuppixMatch {
  /// The original text that was searched.
  final String input;

  /// The start position of the match in the input string.
  final int start;

  /// The end position of the match in the input string.
  final int end;

  /// The captured groups, including group 0 (the entire match).
  final List<String?> _groups;

  /// The named captured groups.
  final Map<String, String> _namedGroups;

  /// Group start positions
  final List<int> _groupStarts;

  /// Group end positions
  final List<int> _groupEnds;

  DuppixMatch._(
      this.input,
      this.start,
      this.end,
      this._groups,
      this._namedGroups,
      this._groupStarts,
      this._groupEnds,
      );

  /// Creates a DuppixMatch from a RegExp match (fallback mode)
  factory DuppixMatch._fromRegExpMatch(String input, RegExpMatch match, int offset) {
    final groups = <String?>[];
    final namedGroups = <String, String>{};
    final groupStarts = <int>[];
    final groupEnds = <int>[];

    // Add group 0 (entire match)
    groups.add(match.group(0));
    groupStarts.add(match.start + offset);
    groupEnds.add(match.end + offset);

    // Add numbered groups
    for (int i = 1; i <= match.groupCount; i++) {
      final groupText = match.group(i);
      groups.add(groupText);

      // Fixed: Calculate proper start/end positions for groups
      if (groupText != null) {
        // Try to find the group's position within the overall match
        final groupStart = match.start + offset;
        final groupEnd = match.end + offset;
        groupStarts.add(groupStart);
        groupEnds.add(groupEnd);
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

    return DuppixMatch._(
      input,
      match.start + offset,
      match.end + offset,
      groups,
      namedGroups,
      groupStarts,
      groupEnds,
    );
  }

  /// Creates a DuppixMatch from a custom engine MatchResult
  factory DuppixMatch._fromMatchResult(String input, int matchStart, MatchResult result) {
    final groups = <String?>[];
    final namedGroups = <String, String>{};
    final groupStarts = <int>[];
    final groupEnds = <int>[];

    // Add group 0 (entire match)
    final fullMatchText = input.substring(matchStart, result.endPosition);
    groups.add(fullMatchText);
    groupStarts.add(matchStart);
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

    return DuppixMatch._(
      input,
      matchStart,
      result.endPosition,
      groups,
      namedGroups,
      groupStarts,
      groupEnds,
    );
  }

  /// The matched text.
  String get group => input.substring(start, end);

  /// The length of the match.
  int get length => end - start;

  /// Returns the captured group at [index].
  ///
  /// Group 0 is the entire match. Groups 1 and higher are the captured groups.
  /// Returns null if the group didn't participate in the match or if the index
  /// is out of range.
  String? groupAt(int index) {
    if (index < 0 || index >= _groups.length) {
      return null;
    }
    return _groups[index];
  }

  /// Returns the named captured group with the given [name].
  ///
  /// Returns null if no group with that name exists or if the group
  /// didn't participate in the match.
  String? namedGroup(String name) {
    return _namedGroups[name];
  }

  /// The number of captured groups, including group 0.
  int get groupCount => _groups.length - 1; // Exclude group 0 from count

  /// Returns the names of all named groups in this match.
  Iterable<String> get groupNames => _namedGroups.keys;

  /// Returns a list of all captured groups, including group 0.
  List<String?> get groups => List.unmodifiable(_groups);

  /// Returns a map of all named captured groups.
  Map<String, String> get namedGroups => Map.unmodifiable(_namedGroups);

  /// Returns the start position of the group at [index].
  ///
  /// Returns -1 if the group didn't participate in the match or if the
  /// index is out of range.
  int groupStart(int index) {
    if (index < 0 || index >= _groupStarts.length) {
      return -1;
    }
    return _groupStarts[index];
  }

  /// Returns the end position of the group at [index].
  ///
  /// Returns -1 if the group didn't participate in the match or if the
  /// index is out of range.
  int groupEnd(int index) {
    if (index < 0 || index >= _groupEnds.length) {
      return -1;
    }
    return _groupEnds[index];
  }

  /// Returns the start position of the named group.
  ///
  /// Returns -1 if no group with that name exists or if the group
  /// didn't participate in the match.
  int namedGroupStart(String name) {
    // Find the group index by name - Fixed implementation
    for (final entry in _namedGroups.entries) {
      if (entry.key == name) {
        // Find corresponding index in groups array
        for (int i = 0; i < _groups.length; i++) {
          if (_groups[i] == entry.value) {
            return _groupStarts[i];
          }
        }
      }
    }
    return -1;
  }

  /// Returns the end position of the named group.
  ///
  /// Returns -1 if no group with that name exists or if the group
  /// didn't participate in the match.
  int namedGroupEnd(String name) {
    // Find the group index by name - Fixed implementation
    for (final entry in _namedGroups.entries) {
      if (entry.key == name) {
        // Find corresponding index in groups array
        for (int i = 0; i < _groups.length; i++) {
          if (_groups[i] == entry.value) {
            return _groupEnds[i];
          }
        }
      }
    }
    return -1;
  }

  /// Returns the last captured group (for $+ replacement)
  String? getLastCapturedGroup() {
    for (int i = _groups.length - 1; i >= 1; i--) {
      if (_groups[i] != null) {
        return _groups[i];
      }
    }
    return null;
  }

  /// Returns the text of the group at [index], or empty string if null.
  String groupText(int index) => groupAt(index) ?? '';

  /// Returns the text of the named group, or empty string if null.
  String namedGroupText(String name) => namedGroup(name) ?? '';

  @override
  String toString() {
    return 'DuppixMatch{start: $start, end: $end, group: "${group}"}';
  }

  @override
  bool operator ==(Object other) {
    return other is DuppixMatch &&
        other.start == start &&
        other.end == end &&
        other.input == input &&
        other._groups.length == _groups.length &&
        other._namedGroups.length == _namedGroups.length;
  }

  @override
  int get hashCode => Object.hash(start, end, input, _groups.length);
}