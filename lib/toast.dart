import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ToastContext {
  BuildContext? context;
  MethodChannel? _channel;

  static final ToastContext _instance = ToastContext._internal();

  /// Prmary Constructor for FToast
  factory ToastContext() {
    return _instance;
  }

  /// Take users Context and saves to avariable
  ToastContext init(BuildContext context) {
    _instance.context = context;
    return _instance;
  }

  ToastContext._internal();
}

class Toast {
  static const int lengthShort = 1;
  static const int lengthLong = 3;
  static const int bottom = 0;
  static const int center = 1;
  static const int top = 2;
  static void show(String msg,
      {int? duration = 1,
      int? gravity = 0,
      Color backgroundColor = const Color(0xAA000000),
      textStyle = const TextStyle(fontSize: 15, color: Colors.white),
      TextDirection? textDirection,
      TextAlign? textAlign,
      double backgroundRadius = 20,
      bool? rootNavigator,
      Border? border,
      bool webShowClose = false,
      Color webTexColor = const Color(0xFFffffff)}) {
    if (ToastContext().context == null) {
      throw Exception(
          'Context is null, please call ToastContext.init(context) first');
    }
    if (kIsWeb == true) {
      if (ToastContext()._channel == null) {
        ToastContext()._channel = const MethodChannel('appdev/FlutterToast');
      }
      String toastGravity = "bottom";
      if (gravity == Toast.top) {
        toastGravity = "top";
      } else if (gravity == Toast.center) {
        toastGravity = "center";
      } else {
        toastGravity = "bottom";
      }

      final Map<String, dynamic> params = <String, dynamic>{
        'msg': msg,
        'duration': (duration ?? 1) * 1000,
        'gravity': toastGravity,
        'bgcolor': backgroundColor.toString(),
        'textcolor':
            '${(webTexColor.a.toInt() << 24 | webTexColor.r.toInt() << 16 | webTexColor.g.toInt() << 8 | webTexColor.b.toInt()).toRadixString(16).padLeft(8, '0')}',
        'webShowClose': webShowClose,
      };
      ToastContext()._channel?.invokeMethod("showToast", params);
    } else {
      ToastView.dismiss();
      ToastView.createView(
          msg,
          ToastContext().context!,
          duration,
          gravity,
          backgroundColor,
          textStyle,
          textDirection,
          textAlign,
          backgroundRadius,
          border,
          rootNavigator);
    }
  }
}


class ToastView {
  static final ToastView _singleton = ToastView._internal();
  static OverlayState? overlayState;
  static OverlayEntry? _overlayEntry;
  static bool _isVisible = false;

  // 新增佇列相關變數
  static final Queue<_ToastItem> _toastQueue = Queue<_ToastItem>();
  static bool _isProcessing = false;

  factory ToastView() {
    return _singleton;
  }

  ToastView._internal();

  static void createView(
      String msg,
      BuildContext context,
      int? duration,
      int? gravity,
      Color background,
      TextStyle textStyle,
      TextDirection? textDirection,
      TextAlign? textAlign,
      double backgroundRadius,
      Border? border,
      bool? rootNavigator) {

    // 將 Toast 加入佇列
    _toastQueue.add(_ToastItem(
      msg: msg,
      context: context,
      duration: duration,
      gravity: gravity,
      background: background,
      textStyle: textStyle,
      textDirection: textDirection,
      textAlign: textAlign,
      backgroundRadius: backgroundRadius,
      border: border,
      rootNavigator: rootNavigator,
    ));

    // 如果沒有正在處理的 Toast，開始處理佇列
    if (!_isProcessing) {
      _processToastQueue();
    }
  }

  static Future<void> _processToastQueue() async {
    if (_toastQueue.isEmpty) {
      _isProcessing = false;
      return;
    }

    _isProcessing = true;
    while (_toastQueue.isNotEmpty) {
      final item = _toastQueue.removeFirst();
      await _showToast(item);
    }

    _isProcessing = false;
  }

  static Future<void> _showToast(_ToastItem item) async {
    overlayState = Overlay.of(item.context, rootOverlay: item.rootNavigator ?? false);

    _overlayEntry = OverlayEntry(
      builder: (BuildContext context) => ToastWidget(
          widget: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: Container(
                alignment: Alignment.center,
                width: MediaQuery.of(context).size.width,
                child: Container(
                  decoration: BoxDecoration(
                    color: item.background,
                    borderRadius: BorderRadius.circular(item.backgroundRadius),
                    border: item.border,
                  ),
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Text(
                    item.msg,
                    softWrap: true,
                    style: item.textStyle,
                    textAlign: item.textAlign,
                    textDirection: item.textDirection,
                  ),
                )),
          ),
          gravity: item.gravity),
    );

    _isVisible = true;
    overlayState!.insert(_overlayEntry!);

    // 等待顯示時間
    await Future.delayed(Duration(seconds: item.duration ?? Toast.lengthShort));

    dismiss();
  }

  static dismiss() async {
    if (!_isVisible) {
      return;
    }
    _isVisible = false;
    _overlayEntry?.remove();
  }
}

// Toast 項目類別
class _ToastItem {
  final String msg;
  final BuildContext context;
  final int? duration;
  final int? gravity;
  final Color background;
  final TextStyle textStyle;
  final TextDirection? textDirection;
  final TextAlign? textAlign;
  final double backgroundRadius;
  final Border? border;
  final bool? rootNavigator;

  _ToastItem({
    required this.msg,
    required this.context,
    this.duration,
    this.gravity,
    required this.background,
    required this.textStyle,
    this.textDirection,
    this.textAlign,
    required this.backgroundRadius,
    this.border,
    this.rootNavigator,
  });
}

class ToastWidget extends StatelessWidget {
  const ToastWidget({
    Key? key,
    required this.widget,
    required this.gravity,
  }) : super(key: key);

  final Widget widget;
  final int? gravity;

  @override
  Widget build(BuildContext context) {
    return Positioned(
        top: gravity == 2 ? MediaQuery.of(context).viewInsets.top + 50 : null,
        bottom:
            gravity == 0 ? MediaQuery.of(context).viewInsets.bottom + 50 : null,
        child: IgnorePointer(
          child: Material(
            color: Colors.transparent,
            child: widget,
          ),
        ));
  }
}
