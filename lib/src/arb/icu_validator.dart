/// Abstract base class for all ICU syntax nodes.
abstract class IcuNode {
  /// Const constructor for subclass initialization.
  const IcuNode();

  /// Accepts a [visitor] to traverse the ICU syntax tree node.
  void accept(IcuVisitor visitor);
}

/// Represents a literal text segment in an ICU message.
class LiteralNode extends IcuNode {
  /// The literal text content.
  final String text;

  /// Creates a literal segment node.
  const LiteralNode(this.text);

  @override
  void accept(IcuVisitor visitor) => visitor.visitLiteral(this);

  @override
  String toString() => 'LiteralNode("$text")';
}

/// Represents a simple variable placeholder in an ICU message, e.g. `{name}` or `{price, number, currency}`.
class PlaceholderNode extends IcuNode {
  /// The variable name or formatting parameter string.
  final String name;

  /// Creates a placeholder node.
  const PlaceholderNode(this.name);

  @override
  void accept(IcuVisitor visitor) => visitor.visitPlaceholder(this);

  @override
  String toString() => 'PlaceholderNode("$name")';
}

/// Represents an ICU Plural expression, e.g. `{count, plural, =0{Zero} other{Other}}`.
class PluralNode extends IcuNode {
  /// The variable name used to select the plural form.
  final String name;

  /// The categories map mapping plural cases (e.g., '=0', 'one', 'other') to their respective ICU nodes list.
  final Map<String, List<IcuNode>> categories;

  /// Creates a plural node with the target variable and its categories.
  const PluralNode(this.name, this.categories);

  @override
  void accept(IcuVisitor visitor) => visitor.visitPlural(this);

  @override
  String toString() => 'PluralNode("$name", $categories)';
}

/// Represents an ICU Select expression, e.g. `{gender, select, male{He} female{She} other{They}}`.
class SelectNode extends IcuNode {
  /// The variable name used to choose the select case.
  final String name;

  /// The categories map mapping select cases (e.g., 'male', 'female', 'other') to their respective ICU nodes list.
  final Map<String, List<IcuNode>> categories;

  /// Creates a select node with the target variable and its categories.
  const SelectNode(this.name, this.categories);

  @override
  void accept(IcuVisitor visitor) => visitor.visitSelect(this);

  @override
  String toString() => 'SelectNode("$name", $categories)';
}

/// Visitor interface to traverse the ICU AST.
abstract class IcuVisitor {
  /// Visits a literal text segment node.
  void visitLiteral(LiteralNode node);

  /// Visits a simple variable placeholder node.
  void visitPlaceholder(PlaceholderNode node);

  /// Visits an ICU Plural expression node.
  void visitPlural(PluralNode node);

  /// Visits an ICU Select expression node.
  void visitSelect(SelectNode node);
}

/// Recursive descent parser for the ICU message format.
class IcuParser {
  /// The raw input string containing the ICU message template.
  final String input;
  int _pos = 0;

  /// Creates an [IcuParser] with the given raw [input] message string.
  IcuParser(this.input);

  /// Parses the input string and returns a list of top-level AST nodes.
  List<IcuNode> parse() {
    final nodes = _parseNodes();
    if (_pos < input.length) {
      throw FormatException(
        'Unexpected character at position $_pos: "${input[_pos]}"',
      );
    }
    return nodes;
  }

  List<IcuNode> _parseNodes() {
    final nodes = <IcuNode>[];
    final sb = StringBuffer();

    while (_pos < input.length) {
      final char = input[_pos];
      if (char == '{') {
        if (sb.isNotEmpty) {
          nodes.add(LiteralNode(sb.toString()));
          sb.clear();
        }
        nodes.add(_parseBraceExpression());
      } else if (char == '}') {
        break; // Let parent brace parser handle closing brace
      } else {
        sb.write(char);
        _pos++;
      }
    }

    if (sb.isNotEmpty) {
      nodes.add(LiteralNode(sb.toString()));
    }
    return nodes;
  }

  IcuNode _parseBraceExpression() {
    _match('{');
    _skipWhitespace();

    final varName = _readIdentifier();
    _skipWhitespace();

    if (_pos < input.length && input[_pos] == ',') {
      _match(',');
      _skipWhitespace();
      final type = _readIdentifier();
      _skipWhitespace();

      if (type == 'plural' || type == 'select') {
        _match(',');
        _skipWhitespace();
        final categories = <String, List<IcuNode>>{};

        while (_pos < input.length && input[_pos] != '}') {
          final categoryName = _readCategoryName();
          _skipWhitespace();
          _match('{');
          final categoryNodes = _parseNodes();
          _match('}');
          _skipWhitespace();
          categories[categoryName] = categoryNodes;
        }

        _match('}');
        if (type == 'plural') {
          return PluralNode(varName, categories);
        } else {
          return SelectNode(varName, categories);
        }
      } else {
        // Handle format options like {price, number, currency} as a single placeholder
        final sb = StringBuffer(varName);
        sb.write(', ');
        sb.write(type);
        while (_pos < input.length && input[_pos] != '}') {
          sb.write(input[_pos]);
          _pos++;
        }
        _match('}');
        return PlaceholderNode(sb.toString());
      }
    } else {
      _match('}');
      return PlaceholderNode(varName);
    }
  }

  void _match(String expected) {
    if (_pos >= input.length || input[_pos] != expected) {
      throw FormatException(
        'Expected "$expected" at position $_pos, but found "${_pos >= input.length ? "EOF" : input[_pos]}" in "$input"',
      );
    }
    _pos++;
  }

  void _skipWhitespace() {
    while (_pos < input.length && _isWhitespace(input[_pos])) {
      _pos++;
    }
  }

  bool _isWhitespace(String char) {
    return char == ' ' || char == '\t' || char == '\n' || char == '\r';
  }

  String _readIdentifier() {
    final start = _pos;
    while (_pos < input.length &&
        input[_pos] != ',' &&
        input[_pos] != '}' &&
        input[_pos] != '{' &&
        !_isWhitespace(input[_pos])) {
      _pos++;
    }
    if (_pos == start) {
      throw FormatException('Expected identifier at position $start');
    }
    return input.substring(start, _pos);
  }

  String _readCategoryName() {
    final start = _pos;
    while (_pos < input.length &&
        input[_pos] != '{' &&
        !_isWhitespace(input[_pos])) {
      _pos++;
    }
    if (_pos == start) {
      throw FormatException('Expected category name at position $start');
    }
    return input.substring(start, _pos);
  }
}

/// Represents the result of an ICU validation check.
class ValidationResult {
  /// Whether the validation check was successful.
  final bool isValid;

  /// The error message if validation failed, or null if successful.
  final String? error;

  /// Creates a valid [ValidationResult].
  const ValidationResult.valid() : isValid = true, error = null;

  /// Creates an invalid [ValidationResult] with the given [error] message.
  const ValidationResult.invalid(this.error) : isValid = false;

  @override
  String toString() => isValid ? 'Valid' : 'Invalid: $error';
}

/// Validates translation strings against source ICU templates.
class IcuValidator {
  /// Maps languages to their required CLDR plural categories (excluding explicit categories like =0, =1).
  static const Map<String, List<String>> _cldrPluralCategories = {
    'pl': ['one', 'few', 'many', 'other'],
    'ru': ['one', 'few', 'many', 'other'],
    'uk': ['one', 'few', 'many', 'other'],
    'ar': ['zero', 'one', 'two', 'few', 'many', 'other'],
  };

  /// Validates a single target translation string against its source.
  ///
  /// Compares placeholders and complex ICU expressions (plurals/selects) to ensure
  /// they structurally match the [source] ICU message and adhere to the [targetLanguage]
  /// rules.
  static ValidationResult validate({
    required String key,
    required String source,
    required String target,
    required String targetLanguage,
  }) {
    List<IcuNode> sourceNodes;
    try {
      sourceNodes = IcuParser(source).parse();
    } catch (e) {
      return ValidationResult.invalid(
        'Source key "$key" has invalid ICU syntax: $e',
      );
    }

    List<IcuNode> targetNodes;
    try {
      targetNodes = IcuParser(target).parse();
    } catch (e) {
      return ValidationResult.invalid(
        'Target translation for "$key" has invalid ICU syntax: $e',
      );
    }

    // 1. Verify placeholders match exactly (no missing, no extra)
    final sourceVars = _getVariables(sourceNodes);
    final targetVars = _getVariables(targetNodes);

    final missingVars = sourceVars.difference(targetVars);
    if (missingVars.isNotEmpty) {
      return ValidationResult.invalid(
        'Missing placeholder variables: ${missingVars.map((v) => "{$v}").join(", ")}',
      );
    }

    final extraVars = targetVars.difference(sourceVars);
    if (extraVars.isNotEmpty) {
      return ValidationResult.invalid(
        'Unexpected placeholder variables: ${extraVars.map((v) => "{$v}").join(", ")}',
      );
    }

    // 2. Validate structural preservation of complex expressions (plurals/selects)
    final sourceComplex = _getComplexExpressions(sourceNodes);
    final targetComplex = _getComplexExpressions(targetNodes);

    if (sourceComplex.length != targetComplex.length) {
      return ValidationResult.invalid(
        'Structural mismatch: source has ${sourceComplex.length} plural/select expressions, target has ${targetComplex.length}',
      );
    }

    for (int i = 0; i < sourceComplex.length; i++) {
      final sExpr = sourceComplex[i];
      final tExpr = targetComplex[i];

      if (sExpr.type != tExpr.type) {
        return ValidationResult.invalid(
          'Structural mismatch at expression $i: source is "${sExpr.type}", target is "${tExpr.type}"',
        );
      }

      if (sExpr.varName != tExpr.varName) {
        return ValidationResult.invalid(
          'Variable mismatch at expression $i: source variable is "${sExpr.varName}", target variable is "${tExpr.varName}"',
        );
      }

      // Check mandatory 'other' category
      if (!tExpr.categories.contains('other')) {
        return ValidationResult.invalid(
          'Missing mandatory "other" category in target expression for "${sExpr.varName}"',
        );
      }

      // Enforce target-language CLDR plural rules
      if (sExpr.type == 'plural') {
        final requiredCldr = _cldrPluralCategories[targetLanguage];
        if (requiredCldr != null) {
          final missingCldr = requiredCldr.toSet().difference(tExpr.categories);
          if (missingCldr.isNotEmpty) {
            return ValidationResult.invalid(
              'Missing required CLDR plural categories for language "$targetLanguage": ${missingCldr.join(", ")}',
            );
          }
        }
      }
    }

    return const ValidationResult.valid();
  }

  /// Recursively extracts all variable names from the ICU AST.
  static Set<String> _getVariables(List<IcuNode> nodes) {
    final vars = <String>{};
    void collect(IcuNode node) {
      if (node is PlaceholderNode) {
        final name = node.name.split(',')[0].trim();
        vars.add(name);
      } else if (node is PluralNode) {
        vars.add(node.name);
        for (final catNodes in node.categories.values) {
          catNodes.forEach(collect);
        }
      } else if (node is SelectNode) {
        vars.add(node.name);
        for (final catNodes in node.categories.values) {
          catNodes.forEach(collect);
        }
      }
    }

    nodes.forEach(collect);
    return vars;
  }

  /// Recursively extracts information about all plural and select expressions.
  static List<_ComplexExprInfo> _getComplexExpressions(List<IcuNode> nodes) {
    final list = <_ComplexExprInfo>[];
    void collect(IcuNode node) {
      if (node is PluralNode) {
        list.add(
          _ComplexExprInfo('plural', node.name, node.categories.keys.toSet()),
        );
        for (final catNodes in node.categories.values) {
          catNodes.forEach(collect);
        }
      } else if (node is SelectNode) {
        list.add(
          _ComplexExprInfo('select', node.name, node.categories.keys.toSet()),
        );
        for (final catNodes in node.categories.values) {
          catNodes.forEach(collect);
        }
      }
    }

    nodes.forEach(collect);
    return list;
  }
}

class _ComplexExprInfo {
  final String type; // 'plural' or 'select'
  final String varName;
  final Set<String> categories;
  const _ComplexExprInfo(this.type, this.varName, this.categories);
}
