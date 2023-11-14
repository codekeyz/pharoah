// ignore_for_file: constant_identifier_names

import 'dart:async';

import '../http/request.dart';
import 'handler.dart';
import 'route.dart';

const ANY_PATH = '*';

const BASE_PATH = '/';

abstract interface class RoutePathDefinitionContract<T> {
  T get(String path, RequestHandlerFunc handler);

  T post(String path, RequestHandlerFunc handler);

  T put(String path, RequestHandlerFunc handler);

  T delete(String path, RequestHandlerFunc handler);

  T use(MiddlewareFunc reqResNext, [Route? route]);
}

mixin RouterMixin<T extends RouteHandler<dynamic>> on RouteHandler
    implements RoutePathDefinitionContract<T> {
  RouteGroup _group = RouteGroup.path(BASE_PATH);

  List<Route> get routes => _group.handlers.map((e) => e.route).toList();

  @override
  Route get route => Route(_group.prefix, [HTTPMethod.ALL]);

  @override
  T prefix(String prefix) {
    _group = _group.withPrefix(prefix);
    return this as T;
  }

  @override
  Future<HandlerResult> handle(ReqRes reqRes) async {
    final h = _group.findHandlers(reqRes.req);
    if (h.isEmpty) {
      return (
        canNext: true,
        reqRes: (req: reqRes.req, res: reqRes.res.notFound())
      );
    }

    final handlerFncs = List<RouteHandler>.from(h);

    ReqRes result = reqRes;
    while (handlerFncs.isNotEmpty) {
      final handler = handlerFncs.removeAt(0);
      final data = await handler.handle(reqRes);
      result = data.reqRes;

      final breakOut = data.canNext == false || result.res.ended;
      if (breakOut) return (canNext: true, reqRes: result);
    }

    return (canNext: true, reqRes: result);
  }

  @override
  T get(String path, RequestHandlerFunc handler) {
    _group.add(RequestHandler(
        handler, Route(path, [HTTPMethod.GET, HTTPMethod.HEAD])));
    return this as T;
  }

  @override
  T post(String path, RequestHandlerFunc handler) {
    _group.add(RequestHandler(handler, Route(path, [HTTPMethod.POST])));
    return this as T;
  }

  @override
  T put(String path, RequestHandlerFunc handler) {
    _group.add(RequestHandler(handler, Route(path, [HTTPMethod.PUT])));
    return this as T;
  }

  @override
  T delete(String path, RequestHandlerFunc handler) {
    _group.add(RequestHandler(handler, Route(path, [HTTPMethod.DELETE])));
    return this as T;
  }

  @override
  T use(MiddlewareFunc reqResNext, [Route? route]) {
    _group.add(Middleware(reqResNext, route ?? Route.any()));
    return this as T;
  }

  bool hasNoRequestHandlers(List<RouteHandler> handlers) =>
      !handlers.any((e) => e is RequestHandler);
}

class PharoahRouter extends RouteHandler<dynamic>
    with RouterMixin<PharoahRouter> {
  @override
  bool get internal => false;

  @override
  HandlerFunc get handler => (req, res) => (req: req, res: res);
}
