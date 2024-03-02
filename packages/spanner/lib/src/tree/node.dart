import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';

import 'tree.dart';
import '../route/action.dart';
import '../parametric/definition.dart';
import '../parametric/utils.dart';

abstract class Node with EquatableMixin, HandlerStore {
  final Map<String, Node> _children = {};

  Map<String, Node> get children => UnmodifiableMapView(_children);

  String get name;

  bool terminal = false;

  Map<String, dynamic> params = {};

  bool hasChild(String char) => children.containsKey(char);

  Node getChild(String char) => children[char]!;

  bool get hasChildren => children.isNotEmpty;

  ParametricNode? _paramNodecache;
  ParametricNode? get paramNode {
    if (_paramNodecache != null) return _paramNodecache;
    final node = children.values.firstWhereOrNull((e) => e is ParametricNode);
    if (node == null) return null;
    return _paramNodecache = (node as ParametricNode);
  }

  WildcardNode? _wildcardNodeCache;
  WildcardNode? get wildcardNode {
    if (_wildcardNodeCache != null) return _wildcardNodeCache;
    final node = children.values.firstWhereOrNull((e) => e is WildcardNode);
    if (node == null) return null;
    return _wildcardNodeCache = (node as WildcardNode);
  }

  Node addChildAndReturn(String key, Node node) {
    return _children[key] = node;
  }
}

class StaticNode extends Node {
  final String _name;

  StaticNode(this._name);

  @override
  String get name => _name;

  @override
  List<Object?> get props => [name, children];
}

class ParametricNode extends Node {
  static final String key = '<:>';

  @override
  void addMiddleware<T>(IndexedValue<T> handler) {
    throw ArgumentError('Parametric Node cannot have middlewares');
  }

  @override
  void addRoute<T>(HTTPMethod method, IndexedValue<T> handler) {
    throw ArgumentError('Parametric Node cannot have routes');
  }

  @override
  Node addChildAndReturn(String key, Node node) {
    if (node is WildcardNode) {
      throw ArgumentError('Parametric Node cannot have wildcard');
    }
    return super.addChildAndReturn(key, node);
  }

  final List<ParameterDefinition> _definitions = [];

  List<ParameterDefinition> get definitions =>
      UnmodifiableListView(_definitions);

  ParametricNode(ParameterDefinition defn) {
    _definitions.add(defn);
  }

  bool get hasTerminal => _definitions.any((e) => e.terminal);

  void addNewDefinition(ParameterDefinition defn) {
    final existing =
        _definitions.firstWhereOrNull((e) => e.isExactExceptName(defn));

    if (existing != null) {
      if (existing.name != defn.name) {
        throw ArgumentError(
          'Route has inconsistent naming in parameter definition\n${[
            ' - ${existing.templateStr}',
            ' - ${defn.templateStr}',
          ].join('\n')}',
        );
      }

      if (existing.terminal && defn.terminal) {
        throw ArgumentError(
          'Route already exists.${[
            ' - ${existing.templateStr}',
            ' - ${defn.templateStr}',
          ].join('\n')}',
        );
      }

      return;
    }

    _definitions
      ..add(defn)
      ..sortByProps();
  }

  @override
  String get name => ParametricNode.key;

  @override
  List<Object?> get props => [name, _definitions, children];

  ParameterDefinition? findMatchingDefinition(
    HTTPMethod method,
    String part, {
    bool terminal = false,
  }) {
    return definitions.firstWhereOrNull(
      (e) {
        final supportsMethod = e.methods.isEmpty || e.hasMethod(method);
        if (terminal != e.terminal || !supportsMethod) return false;
        return e.matches(part);
      },
    );
  }
}

class WildcardNode extends StaticNode {
  static final String key = '*';

  WildcardNode() : super(WildcardNode.key);

  @override
  List<Object?> get props => [name];

  @override
  bool get terminal => true;

  @override
  IndexedValue? getHandler(HTTPMethod method) {
    return super.getHandler(method) ?? super.getHandler(HTTPMethod.ALL);
  }

  @override
  Node addChildAndReturn(key, node) {
    throw ArgumentError('Wildcard cannot have a child');
  }
}
