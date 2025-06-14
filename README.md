# 🔥 Duppix - Advanced Regex Engine for Dart

[![Pub Package](https://img.shields.io/pub/v/duppix.svg)](https://pub.dev/packages/duppix)
[![Dart SDK Version](https://badgen.net/pub/sdk-version/duppix)](https://pub.dev/packages/duppix)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Duppix** is a comprehensive regex library that brings **Oniguruma-compatible advanced features** to Dart, including possessive quantifiers, atomic groups, named backreferences, recursive patterns, and much more.

## ✨ Why Duppix?

Dart's built-in `RegExp` is powerful but lacks many advanced features that other regex engines provide. Duppix fills this gap by implementing a **hybrid approach**:

- 🚀 **Fast fallback**: Simple patterns use Dart's optimized `RegExp`
- 🎯 **Advanced features**: Complex patterns use our custom engine
- 🔄 **Full compatibility**: Drop-in replacement for `RegExp`
- 📚 **Oniguruma compatible**: Supports the same syntax as Ruby, PHP PCRE, and more

## 🆚 Feature Comparison

| Feature | Dart RegExp | Duppix | Example |
|---------|-------------|---------|---------|
| Basic patterns | ✅ | ✅ | `\d+`, `[a-z]*` |
| Named groups | ✅ | ✅ | `(?<name>\w+)` |
| Backreferences | ⚠️ Limited | ✅ | `\1`, `\k<name>` |
| Possessive quantifiers | ❌ | ✅ | `\d++`, `.*+` |
| Atomic groups | ❌ | ✅ | `(?>...)` |
| Recursive patterns | ❌ | ✅ | `(?R)`, `(?0)` |
| Subroutine calls | ❌ | ✅ | `(?1)`, `(?&name)` |
| Conditional patterns | ❌ | ✅ | `(?(1)yes\|no)` |
| Variable lookbehind | ❌ | ✅ | `(?<=\w{2,4})` |
| Script runs | ❌ | ✅ | `(?script_run:...)` |

## 🚀 Quick Start

Add Duppix to your `pubspec.yaml`:

```yaml
dependencies:
  duppix: ^1.0.0
```

### Basic Usage

```dart
import 'package:duppix/duppix.dart';

void main() {
  // Works just like RegExp for simple patterns
  final basic = DuppixRegex(r'\d+');
  print(basic.firstMatch('Hello 123')?.group); // "123"
  
  // But supports advanced features too!
  final advanced = DuppixRegex(r'(?<word>\w+)\s+\k<word>');
  final match = advanced.firstMatch('hello hello world');
  print(match?.namedGroup('word')); // "hello"
}
```

## 🎯 Advanced Features

### Named Backreferences
```dart
// Match repeated words
final regex = DuppixRegex(r'(?<word>\w+)\s+\k<word>');
final match = regex.firstMatch('hello hello world');
print(match?.namedGroup('word')); // "hello"

// Case-insensitive backreferences  
final regex2 = DuppixRegex(r'(?<tag>\w+).*?</\k<tag>>', 
                          options: DUPPIX_OPTION_IGNORECASE);
```

### Possessive Quantifiers (No Backtracking)
```dart
// Atomic matching - no backtracking
final greedy = DuppixRegex(r'.*abc');     // Can backtrack
final possessive = DuppixRegex(r'.*+abc'); // Cannot backtrack

// Useful for performance optimization
final efficient = DuppixRegex(r'\d++[a-z]'); // Faster than \d+[a-z]
```

### Atomic Groups
```dart
// Prevent backtracking within groups
final atomic = DuppixRegex(r'(?>.*?)end');
final match = atomic.firstMatch('start middle end');
```

### Recursive Patterns
```dart
// Match balanced parentheses
final balanced = DuppixRegex(r'\((?:[^()]|(?R))*\)');
final match = balanced.firstMatch('(a(b(c)d)e)');
print(match?.group); // "(a(b(c)d)e)"

// Match nested structures
final nested = DuppixRegex(r'<(\w+)>(?:[^<>]|(?R))*</\1>');
```

### Subroutine Calls
```dart
// Define reusable patterns
final regex = DuppixRegex(r'(?<digit>\d)(?<letter>[a-z])(?&digit)(?&letter)');
final match = regex.firstMatch('1a1a');

// Numbered subroutine calls
final numbered = DuppixRegex(r'(\d{2})-(?1)-(?1)'); // Match XX-XX-XX format
```

### Conditional Patterns
```dart
// Match based on conditions
final conditional = DuppixRegex(r'(?(<tag>)yes|no)'); 
// Matches "yes" if named group "tag" was captured, "no" otherwise
```

### Advanced Character Classes
```dart
// Script runs - ensure single Unicode script
final scriptRun = DuppixRegex(r'(?script_run:\w+)');

// Character class operations
final intersection = DuppixRegex(r'[a-z&&[^aeiou]]'); // Consonants only
```

## 🛠️ Options & Configuration

```dart
// Configure regex behavior
final options = DuppixOptions(
  ignoreCase: true,
  multiline: true,
  singleline: false,
  unicode: true,
  findLongest: false,
  debug: false,
);

final regex = DuppixRegex(r'pattern', options: options);

// Or use flags (Oniguruma compatible)
final flagged = DuppixRegex(r'pattern', 
                          options: DUPPIX_OPTION_IGNORECASE | DUPPIX_OPTION_MULTILINE);
```

## 🔄 Migration from RegExp

Duppix is designed as a **drop-in replacement** for `RegExp`:

```dart
// Before (RegExp)
final oldRegex = RegExp(r'\d+');
final oldMatch = oldRegex.firstMatch('123');

// After (Duppix) - same API
final newRegex = DuppixRegex(r'\d+');
final newMatch = newRegex.firstMatch('123');

// All the same methods work
print(newRegex.hasMatch('123'));
print(newRegex.allMatches('1 2 3').length);
print(newRegex.replaceAll('a1b2c', 'X'));
```

## 📊 Performance

Duppix uses a **smart hybrid approach**:

- **Simple patterns** → Dart's optimized `RegExp` (fastest)
- **Advanced patterns** → Custom engine (feature-rich)
- **Automatic detection** → No manual configuration needed

```dart
// This uses fast RegExp fallback
final simple = DuppixRegex(r'\d+');

// This uses custom engine (detected automatically)  
final advanced = DuppixRegex(r'\d++'); // Possessive quantifier
```

## 🧪 Testing

Run the comprehensive test suite:

```bash
dart test
```

Tests cover:
- ✅ All basic RegExp functionality
- ✅ Advanced Oniguruma features
- ✅ Performance edge cases
- ✅ Unicode support
- ✅ Error handling
- ✅ Legacy compatibility

## 📚 Examples

### Email Validation with Named Groups
```dart
final emailRegex = DuppixRegex(
  r'(?<local>[a-zA-Z0-9._%+-]+)@(?<domain>[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})'
);
final match = emailRegex.firstMatch('user@example.com');
print('Local: ${match?.namedGroup('local')}');   // "user"
print('Domain: ${match?.namedGroup('domain')}'); // "example.com"
```

### URL Path Extraction with Subroutines
```dart
final urlRegex = DuppixRegex(
  r'(?<protocol>https?)://(?<domain>(?&subdomain)\.)*(?<tld>\w+)(?<path>/.*)?'
  r'(?<subdomain>\w+)'
);
```

### Balanced Brackets Parser
```dart
final brackets = DuppixRegex(r'\{(?:[^{}]|(?R))*\}');
final json = '{"key": {"nested": "value"}}';
print(brackets.firstMatch(json)?.group); // Full JSON object
```

### HTML Tag Matching with Backreferences
```dart
final htmlTag = DuppixRegex(r'<(?<tag>\w+)>.*?</\k<tag>>');
final html = '<div>Content</div>';
print(htmlTag.firstMatch(html)?.namedGroup('tag')); // "div"
```

## 🔧 Implementation Status

### ✅ Completed Features
- Core regex engine architecture
- Pattern parser with full Oniguruma syntax
- Hybrid fallback system
- Basic quantifiers (*, +, ?, {n,m})
- Character classes and ranges
- Named and numbered capture groups
- Possessive quantifiers (*+, ++, ?+)
- Atomic groups ((?>...))
- Lookahead/lookbehind assertions
- Backreferences (\1, \k<name>)
- Subroutine calls ((?1), (?&name))
- Recursive patterns ((?R))
- Conditional patterns framework
- Comprehensive error handling
- Full RegExp API compatibility

### 🚧 In Progress
- Unicode property support (\p{Letter}, \p{Script=Latin})
- Anchor improvements (^, $, \b, \B)
- Performance optimizations
- Additional Oniguruma features

### 📋 Roadmap
- Variable-length lookbehind optimization
- More Unicode features
- JIT compilation for hot patterns
- WASM acceleration
- Additional language support

## 🤝 Contributing

We welcome contributions! Areas where help is needed:

1. **Unicode Properties** - Implement \p{...} classes
2. **Performance** - Optimize hot paths
3. **Documentation** - More examples and guides
4. **Testing** - Edge cases and real-world patterns
5. **Features** - Additional Oniguruma compatibility

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

- **Oniguruma** - The inspiration and syntax reference
- **Ruby** - For pioneering advanced regex features
- **PCRE** - For performance insights
- **Dart Team** - For the excellent base RegExp implementation

---

**Made with ❤️ for the Dart community**