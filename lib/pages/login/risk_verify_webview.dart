import 'dart:async' show Timer;

import 'package:PiliPlus/http/browser_ua.dart';
import 'package:PiliPlus/main.dart';
import 'package:PiliPlus/utils/login_debug.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// 密码登录被风控拦截（`data.status == 1` + `scene=secLogin`）时打开的身份验证页。
///
/// 这里直接加载服务端给的那个 h5 地址，用户在页面内完成验证（短信/二次确认）后，
/// 页面会给 `bilibili.com` 种上 SESSDATA 等 cookie；本页轮询 cookie，
/// 拿到 SESSDATA + DedeUserID 就带着整组 cookie 返回，交给 cookie 登录收尾。
const Set<String> _wantedCookies = <String>{
  'SESSDATA',
  'bili_jct',
  'DedeUserID',
  'DedeUserID__ckMd5',
  'sid',
};

class RiskVerifyWebview extends StatefulWidget {
  const RiskVerifyWebview({super.key, required this.url});

  final String url;

  static Future<Map<String, String>?> open(String url) {
    return Get.to<Map<String, String>>(() => RiskVerifyWebview(url: url));
  }

  @override
  State<RiskVerifyWebview> createState() => _RiskVerifyWebviewState();
}

class _RiskVerifyWebviewState extends State<RiskVerifyWebview> {
  Timer? _timer;
  bool _checking = false;
  bool _finished = false;
  InAppWebViewController? _webViewController;

  @override
  void initState() {
    super.initState();
    loginLog('riskVerify.open', <String, dynamic>{'url': widget.url});
    _timer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _checkCookies(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkCookies({bool manual = false}) async {
    if (_checking || _finished) return;
    _checking = true;
    try {
      final Map<String, String> found = <String, String>{};
      for (final String host in const <String>[
        'https://passport.bilibili.com',
        'https://www.bilibili.com',
      ]) {
        final List<Cookie> cookies = await CookieManager.instance().getCookies(
          url: WebUri(host),
          webViewController: _webViewController,
        );
        for (final Cookie cookie in cookies) {
          if (_wantedCookies.contains(cookie.name) && cookie.value.isNotEmpty) {
            found[cookie.name] = cookie.value;
          }
        }
      }
      loginLog('riskVerify.cookies', <String, dynamic>{
        'names': found.keys.toList(),
        'hasSessData': found.containsKey('SESSDATA'),
        'manual': manual,
      });
      if (found['SESSDATA'] != null && found['DedeUserID'] != null) {
        _finished = true;
        _timer?.cancel();
        if (mounted) Get.back(result: found);
        return;
      }
      if (manual) {
        SmartDialog.showToast('还没检测到登录状态，请先在页面内完成验证');
      }
    } catch (e, s) {
      loginLog('riskVerify.cookieCheckError', '$e\n$s');
      if (manual) SmartDialog.showToast('检测失败：$e');
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('安全验证'),
        actions: [
          TextButton(
            onPressed: () => _checkCookies(manual: true),
            child: const Text('完成'),
          ),
        ],
      ),
      body: InAppWebView(
        webViewEnvironment: webViewEnvironment,
        initialUrlRequest: URLRequest(url: WebUri(widget.url)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          domStorageEnabled: true,
          thirdPartyCookiesEnabled: true,
          sharedCookiesEnabled: true,
          mediaPlaybackRequiresUserGesture: false,
          useShouldOverrideUrlLoading: true,
          cacheEnabled: true,
          userAgent: BrowserUa.mob,
        ),
        onWebViewCreated: (controller) {
          _webViewController = controller;
        },
        onLoadStop: (controller, url) {
          _webViewController = controller;
          loginLog('riskVerify.loadStop', <String, dynamic>{
            'url': url?.toString(),
          });
          _checkCookies();
        },
        onUpdateVisitedHistory: (controller, url, isReload) {
          loginLog('riskVerify.history', <String, dynamic>{
            'url': url?.toString(),
            'isReload': isReload,
          });
        },
      ),
    );
  }
}
