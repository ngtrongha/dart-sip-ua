import 'dart:js_interop';

import 'package:sip_ua/src/sip_ua_helper.dart';
import 'package:web/web.dart' as web;

import '../logger.dart';

typedef OnMessageCallback = void Function(dynamic msg);
typedef OnCloseCallback = void Function(int? code, String? reason);
typedef OnOpenCallback = void Function();

class SIPUAWebSocketImpl {
  SIPUAWebSocketImpl(this._url, this.messageDelay);

  final String _url;
  web.WebSocket? _socket;
  OnOpenCallback? onOpen;
  OnMessageCallback? onMessage;
  OnCloseCallback? onClose;
  final int messageDelay;

  void connect(
      {Iterable<String>? protocols,
      required WebSocketSettings webSocketSettings}) async {
    logger.i('connect $_url, ${webSocketSettings.extraHeaders}, $protocols');
    try {
      _socket = web.WebSocket(_url, 'sip');

      _socket!.addEventListener(
          'open',
          ((web.Event e) {
            onOpen?.call();
          }).toJS);

      _socket!.addEventListener(
          'message',
          ((web.MessageEvent e) async {
            final JSAny? data = e.data;
            if (data == null) {
              return;
            }

            // Text frame
            if (data is JSString) {
              onMessage?.call(data.toDart);
              return;
            }

            // Blob frame
            if (data.instanceOfString('Blob')) {
              final JSString textJs = await (data as web.Blob).text().toDart;
              final String text = textJs.toDart;
              onMessage?.call(text);
              return;
            }

            // Fallback: pass-through
            onMessage?.call(data);
          }).toJS);

      _socket!.addEventListener(
          'close',
          ((web.CloseEvent e) {
            onClose?.call(e.code, e.reason);
          }).toJS);
    } catch (e) {
      onClose?.call(0, e.toString());
    }
  }

  void send(dynamic data) {
    if (_socket != null && _socket!.readyState == web.WebSocket.OPEN) {
      _socket!.send(data);
      logger.d('send: \n\n$data');
    } else {
      logger.e('WebSocket not connected, message $data not sent');
    }
  }

  bool isConnecting() {
    return _socket != null && _socket!.readyState == web.WebSocket.CONNECTING;
  }

  void close() {
    _socket!.close();
  }
}
