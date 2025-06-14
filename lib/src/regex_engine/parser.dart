// File: src/regex_engine/parser.dart

import 'core.dart';
import 'quantifiers.dart';
import 'captures.dart';

// Create custom exception classes here to avoid import conflicts
class RegexParseException implements Exception {
  final String message;
  final String? pattern;
  final int? position;
  final String? suggestion;

  const RegexParseException(this.message, {this.pattern, this.position, this.suggestion});

  factory RegexParseException.invalidPattern(String message, String pattern, {int? position}) {
    return RegexParseException('Invalid regex pattern: $message', pattern: pattern, position: position);
  }

  factory RegexParseException.unsupportedFeature(String feature, String pattern, {int? position, String? suggestion}) {
    return RegexParseException('Unsupported regex feature: $feature${suggestion != null ? '. $suggestion' : ''}',
        pattern: pattern, position: position, suggestion: suggestion);
  }

  factory RegexParseException.compilation(String message, String pattern, {int? position}) {
    return RegexParseException('Regex compilation error: $message', pattern: pattern, position: position);
  }
}

// Create custom options class here to avoid import conflicts
class RegexParserOptions {
  final bool ignoreCase;
  final bool multiline;
  final bool singleline;
  final bool extended;

  const RegexParserOptions({
    this.ignoreCase = false,
    this.multiline = false,
    this.singleline = false,
    this.extended = false,
  });
}

/// Parser for converting regex pattern strings into abstract syntax trees.
///
/// Handles the full Oniguruma syntax including advanced features like
/// possessive quantifiers, atomic groups, named backreferences, etc.
class RegexParser {
  final String pattern;
  final RegexParserOptions options;

  int _position = 0;
  int _groupCounter = 0;
  final Map<String, int> _namedGroups = {};
  final List<RegexNode> _numberedGroups = [];

  /// Whether this pattern can use the fallback RegExp engine
  bool canUseFallback = true;

  RegexParser(this.pattern, this.options);

  /// Parses the pattern and returns the root AST node.
  RegexNode parse() {
    _position = 0;
    _groupCounter = 0;
    _namedGroups.clear();
    _numberedGroups.clear();
    canUseFallback = true;

    try {
      final result = _parseAlternation();

      if (_position < pattern.length) {
        throw RegexParseException.invalidPattern(
          'Unexpected character at position $_position',
          pattern,
          position: _position,
        );
      }

      return result;
    } catch (e) {
      if (e is RegexParseException) rethrow;
      throw RegexParseException.compilation(
        e.toString(),
        pattern,
        position: _position,
      );
    }
  }

  /// Parses alternation (|) - lowest precedence
  RegexNode _parseAlternation() {
    final alternatives = <RegexNode>[];
    alternatives.add(_parseSequence());

    while (_position < pattern.length && _peek() == '|') {
      _advance(); // consume '|'
      alternatives.add(_parseSequence());
    }

    return alternatives.length == 1
        ? alternatives.first
        : AlternationNode(alternatives);
  }

  /// Parses sequence of regex elements
  RegexNode _parseSequence() {
    final nodes = <RegexNode>[];

    while (_position < pattern.length && _peek() != '|' && _peek() != ')') {
      nodes.add(_parseQuantified());
    }

    return nodes.length == 1
        ? nodes.first
        : SequenceNode(nodes);
  }

  /// Parses an element with quantifiers
  RegexNode _parseQuantified() {
    final element = _parseAtom();

    if (_position >= pattern.length) return element;

    final char = _peek();

    switch (char) {
      case '*':
        _advance();
        return _parseQuantifierSuffix(QuantifierNode.star(element));

      case '+':
        _advance();
        return _parseQuantifierSuffix(QuantifierNode.plus(element));

      case '?':
        _advance();
        return _parseQuantifierSuffix(QuantifierNode.question(element));

      case '{':
        return _parseCustomQuantifier(element);

      default:
        return element;
    }
  }

  /// Parses quantifier suffixes like ?, +, ++, ?+
  RegexNode _parseQuantifierSuffix(QuantifierNode quantifier) {
    if (_position >= pattern.length) return quantifier;

    final char = _peek();

    if (char == '?') {
      // Lazy quantifier
      _advance();
      canUseFallback = false; // Dart RegExp has limited lazy support
      return QuantifierNode(
        quantifier.child,
        quantifier.min,
        quantifier.max,
        type: QuantifierType.lazy,
      );
    } else if (char == '+') {
      // Possessive quantifier (Oniguruma-specific)
      _advance();
      canUseFallback = false;
      return QuantifierNode(
        quantifier.child,
        quantifier.min,
        quantifier.max,
        type: QuantifierType.possessive,
      );
    }

    return quantifier;
  }

  /// Parses custom quantifiers like {n}, {n,}, {n,m}
  RegexNode _parseCustomQuantifier(RegexNode element) {
    _advance(); // consume '{'

    // Parse minimum
    final minStr = _parseNumber();
    if (minStr.isEmpty) {
      throw RegexParseException.invalidPattern(
        'Invalid quantifier: expected number after {',
        pattern,
        position: _position,
      );
    }

    final min = int.parse(minStr);
    int max = min;

    if (_position < pattern.length && _peek() == ',') {
      _advance(); // consume ','

      if (_position < pattern.length && _peek() != '}') {
        final maxStr = _parseNumber();
        if (maxStr.isNotEmpty) {
          max = int.parse(maxStr);
        } else {
          max = -1; // infinite
        }
      } else {
        max = -1; // infinite
      }
    }

    if (_position >= pattern.length || _peek() != '}') {
      throw RegexParseException.invalidPattern(
        'Invalid quantifier: expected }',
        pattern,
        position: _position,
      );
    }

    _advance(); // consume '}'

    final quantifier = QuantifierNode(element, min, max);
    return _parseQuantifierSuffix(quantifier);
  }

  /// Parses atomic elements
  RegexNode _parseAtom() {
    if (_position >= pattern.length) {
      throw RegexParseException.invalidPattern(
        'Unexpected end of pattern',
        pattern,
        position: _position,
      );
    }

    final char = _peek();

    switch (char) {
      case '(':
        return _parseGroup();

      case '[':
        return _parseCharacterClass();

      case '.':
        _advance();
        return _parseDot();

      case '^':
        _advance();
        return _parseStartAnchor();

      case r'$':
        _advance();
        return _parseEndAnchor();

      case r'\':
        return _parseEscape();

      default:
        _advance();
        return LiteralNode(char, caseSensitive: !options.ignoreCase);
    }
  }

  /// Parses group constructs (...), (?:...), (?<n>...), etc.
  RegexNode _parseGroup() {
    _advance(); // consume '('

    if (_position < pattern.length && _peek() == '?') {
      _advance(); // consume '?'
      return _parseSpecialGroup();
    }

    // Regular capturing group
    final groupNumber = ++_groupCounter;
    final content = _parseAlternation();

    if (_position >= pattern.length || _peek() != ')') {
      throw RegexParseException.invalidPattern(
        'Unclosed group',
        pattern,
        position: _position,
      );
    }

    _advance(); // consume ')'

    final group = CaptureGroupNode(content, groupNumber: groupNumber);
    _numberedGroups.add(group);
    return group;
  }

  /// Parses special group constructs starting with (?
  RegexNode _parseSpecialGroup() {
    if (_position >= pattern.length) {
      throw RegexParseException.invalidPattern(
        'Invalid group syntax',
        pattern,
        position: _position,
      );
    }

    final char = _peek();

    switch (char) {
      case ':':
      // Non-capturing group (?:...)
        _advance();
        final content = _parseAlternation();
        _expectChar(')');
        return NonCapturingGroupNode(content);

      case '<':
      // Named group (?<n>...)
        return _parseNamedGroup();

      case '=':
      // Positive lookahead (?=...)
        _advance();
        canUseFallback = false;
        final content = _parseAlternation();
        _expectChar(')');
        return LookaheadNode(content, positive: true);

      case '!':
      // Negative lookahead (?!...)
        _advance();
        canUseFallback = false;
        final content = _parseAlternation();
        _expectChar(')');
        return LookaheadNode(content, positive: false);

      case '>':
      // Atomic group (?>...)
        _advance();
        canUseFallback = false;
        final content = _parseAlternation();
        _expectChar(')');
        return AtomicGroupNode(content);

      case '(':
      // Conditional (?()...)
        return _parseConditional();

      default:
      // Fixed: Use proper digit checking
        if (_isDigit(char)) {
          // Subroutine call (?1), (?0)
          return _parseSubroutineCall();
        } else if (char == 'R') {
          // Recursive call (?R)
          _advance();
          _expectChar(')');
          canUseFallback = false;
          return const SubroutineCallNode(isRecursive: true);
        } else {
          throw RegexParseException.invalidPattern(
            'Unknown group syntax: (?$char',
            pattern,
            position: _position - 1,
          );
        }
    }
  }

  /// Parses named groups (?<n>...)
  RegexNode _parseNamedGroup() {
    _advance(); // consume '<'

    final nameStart = _position;
    while (_position < pattern.length && _peek() != '>') {
      _advance();
    }

    if (_position >= pattern.length) {
      throw RegexParseException.invalidPattern(
        'Unclosed named group',
        pattern,
        position: nameStart,
      );
    }

    final name = pattern.substring(nameStart, _position);
    _advance(); // consume '>'

    if (name.isEmpty) {
      throw RegexParseException.invalidPattern(
        'Empty group name',
        pattern,
        position: nameStart,
      );
    }

    final groupNumber = ++_groupCounter;
    _namedGroups[name] = groupNumber;

    final content = _parseAlternation();
    _expectChar(')');

    final group = CaptureGroupNode(content, groupNumber: groupNumber, groupName: name);
    _numberedGroups.add(group);
    return group;
  }

  /// Parses subroutine calls (?1), (?&n)
  RegexNode _parseSubroutineCall() {
    if (_peek() == '&') {
      // Named subroutine (?&n)
      _advance(); // consume '&'
      final nameStart = _position;

      while (_position < pattern.length && _peek() != ')') {
        _advance();
      }

      final name = pattern.substring(nameStart, _position);
      _expectChar(')');

      canUseFallback = false;
      return SubroutineCallNode(groupName: name);
    } else {
      // Numbered subroutine (?1)
      final numStr = _parseNumber();
      final num = int.tryParse(numStr);

      if (num == null) {
        throw RegexParseException.invalidPattern(
          'Invalid subroutine number',
          pattern,
          position: _position,
        );
      }

      _expectChar(')');

      canUseFallback = false;
      return SubroutineCallNode(groupNumber: num, isRecursive: num == 0);
    }
  }

  /// Parses conditional patterns (?()...)
  RegexNode _parseConditional() {
    throw RegexParseException.unsupportedFeature(
      'Conditional patterns',
      pattern,
      position: _position,
      suggestion: 'Use alternation (|) instead',
    );
  }

  /// Parses character classes [abc], [^abc], [a-z]
  RegexNode _parseCharacterClass() {
    _advance(); // consume '['

    bool negated = false;
    if (_position < pattern.length && _peek() == '^') {
      negated = true;
      _advance();
    }

    final codePoints = <int>{};

    while (_position < pattern.length && _peek() != ']') {
      final char = _advance();

      if (char == '\\') {
        // Escaped character
        final escaped = _parseClassEscape();
        codePoints.add(escaped);
      } else if (_position < pattern.length &&
          _peek() == '-' &&
          _position + 1 < pattern.length &&
          pattern[_position + 1] != ']') {
        // Character range
        _advance(); // consume '-'
        final endChar = _advance();

        final startCode = char.codeUnitAt(0);
        final endCode = endChar.codeUnitAt(0);

        for (int i = startCode; i <= endCode; i++) {
          codePoints.add(i);
        }
      } else {
        codePoints.add(char.codeUnitAt(0));
      }
    }

    if (_position >= pattern.length) {
      throw RegexParseException.invalidPattern(
        'Unclosed character class',
        pattern,
        position: _position,
      );
    }

    _advance(); // consume ']'

    return CharacterClassNode(codePoints, negated: negated);
  }

  /// Parses escape sequences
  RegexNode _parseEscape() {
    _advance(); // consume '\'

    if (_position >= pattern.length) {
      throw RegexParseException.invalidPattern(
        'Incomplete escape sequence',
        pattern,
        position: _position,
      );
    }

    final char = _advance();

    switch (char) {
      case 'k':
      // Named backreference \k<n>
        return _parseNamedBackreference();

      case '1':
      case '2':
      case '3':
      case '4':
      case '5':
      case '6':
      case '7':
      case '8':
      case '9':
      // Numbered backreference
        final num = int.parse(char);
        canUseFallback = false; // Dart has limited backreference support
        return BackreferenceNode(groupNumber: num, caseSensitive: !options.ignoreCase);

      case 'd':
        return CharacterClassNode.fromRanges([(48, 57)]); // [0-9]

      case 'D':
        return CharacterClassNode.fromRanges([(48, 57)], negated: true); // [^0-9]

      case 's':
        return CharacterClassNode({32, 9, 10, 11, 12, 13}); // whitespace

      case 'S':
        return CharacterClassNode({32, 9, 10, 11, 12, 13}, negated: true);

      case 'w':
        return CharacterClassNode.fromRanges([(48, 57), (65, 90), (97, 122), (95, 95)]); // [a-zA-Z0-9_]

      case 'W':
        return CharacterClassNode.fromRanges([(48, 57), (65, 90), (97, 122), (95, 95)], negated: true);

      case 'n':
        return LiteralNode('\n', caseSensitive: !options.ignoreCase);

      case 't':
        return LiteralNode('\t', caseSensitive: !options.ignoreCase);

      case 'r':
        return LiteralNode('\r', caseSensitive: !options.ignoreCase);

      default:
        return LiteralNode(char, caseSensitive: !options.ignoreCase);
    }
  }

  /// Parses named backreferences \k<n>
  RegexNode _parseNamedBackreference() {
    if (_position >= pattern.length || _peek() != '<') {
      throw RegexParseException.invalidPattern(
        'Invalid named backreference syntax',
        pattern,
        position: _position,
      );
    }

    _advance(); // consume '<'
    final nameStart = _position;

    while (_position < pattern.length && _peek() != '>') {
      _advance();
    }

    if (_position >= pattern.length) {
      throw RegexParseException.invalidPattern(
        'Unclosed named backreference',
        pattern,
        position: nameStart,
      );
    }

    final name = pattern.substring(nameStart, _position);
    _advance(); // consume '>'

    canUseFallback = false;
    return BackreferenceNode(groupName: name, caseSensitive: !options.ignoreCase);
  }

  /// Parses escape sequences within character classes
  int _parseClassEscape() {
    if (_position >= pattern.length) {
      throw RegexParseException.invalidPattern(
        'Incomplete escape in character class',
        pattern,
        position: _position,
      );
    }

    final char = _advance();

    switch (char) {
      case 'n':
        return 10; // newline
      case 't':
        return 9;  // tab
      case 'r':
        return 13; // carriage return
      default:
        return char.codeUnitAt(0);
    }
  }

  /// Parses dot (.) metacharacter
  RegexNode _parseDot() {
    if (options.singleline) {
      // Dot matches everything including newlines
      return CharacterClassNode.fromRanges([(0, 1114111)]);
    } else {
      // Dot matches everything except newlines
      return CharacterClassNode({10}, negated: true);
    }
  }

  /// Parses start anchor (^)
  RegexNode _parseStartAnchor() {
    canUseFallback = true; // Dart's RegExp supports this
    return const StartAnchorNode();
  }

  RegexNode _parseEndAnchor() {
    canUseFallback = true; // Dart's RegExp supports this
    return const EndAnchorNode();
  }


  /// Helper methods
  String _peek() {
    return _position < pattern.length ? pattern[_position] : '';
  }

  String _advance() {
    return _position < pattern.length ? pattern[_position++] : '';
  }

  void _expectChar(String expected) {
    if (_position >= pattern.length || _peek() != expected) {
      throw RegexParseException.invalidPattern(
        'Expected \'$expected\'',
        pattern,
        position: _position,
      );
    }
    _advance();
  }

  String _parseNumber() {
    final start = _position;

    while (_position < pattern.length && _isDigit(_peek())) {
      _advance();
    }

    return pattern.substring(start, _position);
  }

  /// Helper method to check if character is a digit
  bool _isDigit(String char) {
    if (char.isEmpty) return false;
    final code = char.codeUnitAt(0);
    return code >= 48 && code <= 57; // '0' to '9'
  }
}