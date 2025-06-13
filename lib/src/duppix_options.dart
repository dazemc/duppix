/// Options for controlling Duppix regex behavior.
///
/// Provides fine-grained control over regex compilation and matching behavior,
/// including compatibility with Oniguruma option flags.
class DuppixOptions {
  /// Ignore case when matching.
  final bool ignoreCase;

  /// Enable multiline mode (^ and $ match line boundaries).
  final bool multiline;

  /// Enable single line mode (. matches newlines).
  final bool singleline;

  /// Enable extended mode (ignore whitespace and comments in pattern).
  final bool extended;

  /// Find the longest match instead of the first match.
  final bool findLongest;

  /// Don't match empty strings.
  final bool findNotEmpty;

  /// Enable Unicode mode for character classes and properties.
  final bool unicode;

  /// Enable debug mode for pattern compilation and matching.
  final bool debug;

  const DuppixOptions({
    this.ignoreCase = false,
    this.multiline = false,
    this.singleline = false,
    this.extended = false,
    this.findLongest = false,
    this.findNotEmpty = false,
    this.unicode = true,
    this.debug = false,
  });

  /// Creates options from integer flags (Oniguruma compatibility).
  factory DuppixOptions.fromFlags(int flags) {
    return DuppixOptions(
      ignoreCase: (flags & 1) != 0,        // DUPPIX_OPTION_IGNORECASE
      multiline: (flags & 2) != 0,         // DUPPIX_OPTION_MULTILINE
      singleline: (flags & 4) != 0,        // DUPPIX_OPTION_SINGLELINE
      extended: (flags & 8) != 0,          // DUPPIX_OPTION_EXTEND
      findLongest: (flags & 16) != 0,      // DUPPIX_OPTION_FIND_LONGEST
      findNotEmpty: (flags & 32) != 0,     // DUPPIX_OPTION_FIND_NOT_EMPTY
      unicode: true,                       // Always enabled
      debug: false,                        // Not exposed via flags
    );
  }

  /// Converts options to integer flags (Oniguruma compatibility).
  int toFlags() {
    int flags = 0;
    if (ignoreCase) flags |= 1;
    if (multiline) flags |= 2;
    if (singleline) flags |= 4;
    if (extended) flags |= 8;
    if (findLongest) flags |= 16;
    if (findNotEmpty) flags |= 32;
    return flags;
  }

  /// Creates a copy of these options with modified values.
  DuppixOptions copyWith({
    bool? ignoreCase,
    bool? multiline,
    bool? singleline,
    bool? extended,
    bool? findLongest,
    bool? findNotEmpty,
    bool? unicode,
    bool? debug,
  }) {
    return DuppixOptions(
      ignoreCase: ignoreCase ?? this.ignoreCase,
      multiline: multiline ?? this.multiline,
      singleline: singleline ?? this.singleline,
      extended: extended ?? this.extended,
      findLongest: findLongest ?? this.findLongest,
      findNotEmpty: findNotEmpty ?? this.findNotEmpty,
      unicode: unicode ?? this.unicode,
      debug: debug ?? this.debug,
    );
  }

  @override
  String toString() {
    final parts = <String>[];
    if (ignoreCase) parts.add('i');
    if (multiline) parts.add('m');
    if (singleline) parts.add('s');
    if (extended) parts.add('x');
    if (findLongest) parts.add('l');
    if (findNotEmpty) parts.add('n');
    if (unicode) parts.add('u');
    if (debug) parts.add('d');
    return parts.isEmpty ? 'none' : parts.join('');
  }

  @override
  bool operator ==(Object other) {
    return other is DuppixOptions &&
        other.ignoreCase == ignoreCase &&
        other.multiline == multiline &&
        other.singleline == singleline &&
        other.extended == extended &&
        other.findLongest == findLongest &&
        other.findNotEmpty == findNotEmpty &&
        other.unicode == unicode &&
        other.debug == debug;
  }

  @override
  int get hashCode => Object.hash(
    ignoreCase,
    multiline,
    singleline,
    extended,
    findLongest,
    findNotEmpty,
    unicode,
    debug,
  );
}