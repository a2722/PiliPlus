import 'dart:convert' show jsonDecode;
import 'dart:io' show Platform;

import 'package:PiliPlus/http/browser_ua.dart';
import 'package:PiliPlus/main.dart';
import 'package:PiliPlus/plugin/linux_webview.dart';
import 'package:PiliPlus/utils/login_debug.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// 极验 v4（gcaptcha4）验证码弹窗。
///
/// B 站自 2026-11 起 /x/safecenter/captcha/pre 返回 recaptcha_type=geetest4，
/// gee_gt 即 v4 的 captchaId；旧的 v3 fullpage 加载器已无法加载该配置。
class GeetestWebviewDialog extends StatefulWidget {
  const GeetestWebviewDialog(this.gt, this.challenge, {super.key});

  final String gt;
  final String challenge;

  @override
  State<GeetestWebviewDialog> createState() => _GeetestWebviewDialogState();

  static Future<Map<String, dynamic>?> geetest(String gt, String challenge) {
    return showDialog<Map<String, dynamic>>(
      context: Get.context!,
      builder: (context) => GeetestWebviewDialog(gt, challenge),
    );
  }
}

class _GeetestWebviewDialogState extends State<GeetestWebviewDialog> {
  static const _gt4JsUri = 'https://static.geetest.com/v4/gt4.js';

  static String _buildHtml(String gt) {
    final bridge = Platform.isLinux
        ? 'R=(n,o)=>window.PiliPlus.postMessage(n+":"+JSON.stringify(o))'
        : 'R=(n,o)=>window.flutter_inappwebview?.callHandler(n,o)';
    return '<!DOCTYPE html><html><head>'
        '<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">'
        '</head>'
        '<style>'
        'html,body{margin:0;padding:0;background:transparent;overflow:hidden}'
        '#cap{width:100%;min-height:320px;display:flex;align-items:center;justify-content:center}'
        '#E{position:fixed;inset:0;display:flex;align-items:center;justify-content:center;'
        'color:#e63946;font-size:14px;padding:16px;text-align:center}'
        '</style>'
        '<body><div id="cap"></div><div id="E"></div><script>'
        '$bridge;'
        'window.onerror=function(m,s,l,c,e){'
        'R("jserror",String(m)+" @ "+l+":"+c);return false;};'
        'function boot(){'
        '  R("log","gt4.js loaded, captchaId=$gt");'
        '  if(typeof initGeetest4!=="function"){'
        '    document.getElementById("E").textContent="验证码脚本加载失败";'
        '    R("jserror","initGeetest4 missing");return;'
        '  }'
        '  initGeetest4({'
        '    captchaId:"$gt",'
        '    product:"bind",'
        '    protocol:"https://",'
        '    language:"zho",'
        '    hideBar:[]'
        '  },function(c){'
        '    c.appendTo("#cap");'
        '    c.onSuccess(function(){'
        '      try{ R("success", c.getValidate()) }catch(e){ R("error", String(e)) }'
        '    });'
        '    c.onError(function(e){ R("error", JSON.stringify(e||{})) });'
        '    c.onClose(function(){ R("close",{}) });'
        '    c.showCaptcha();'
        '  });'
        '}'
        '</script>'
        '<script src="$_gt4JsUri" onload="boot()" '
        'onerror="document.getElementById(\'E\').textContent=\'验证码脚本加载失败\'"></script>'
        '</body></html>';
  }

  @override
  Widget build(BuildContext context) {
    final html = _buildHtml(widget.gt);
    loginLog('geetest.open', <String, dynamic>{
      'gt': widget.gt,
      'challenge': maskValue(widget.challenge),
    });

    if (Platform.isLinux) {
      return AlertDialog(
        title: const Text('验证码'),
        content: SizedBox(
          width: 320,
          height: 420,
          child: LinuxWebview(
            initialHtml: html,
            userAgent: BrowserUa.mob,
            incognito: true,
            onWebMessageReceived: (msg) {
              final msgStr = msg.toString();
              if (msgStr.startsWith("success:")) {
                final dataStr = msgStr.substring("success:".length);
                try {
                  final data = jsonDecode(dataStr);
                  loginLog('geetest.success', data);
                  Get.back(result: data);
                } catch (e) {
                  loginLog('geetest.decodeError', '$e / $dataStr');
                  debugPrint('geetest decode error: $e');
                }
              } else if (msgStr.startsWith("error:")) {
                loginLog('geetest.error', msgStr);
                debugPrint('geetest error: $msgStr');
              } else if (msgStr.startsWith("jserror:")) {
                loginLog('geetest.jsError', msgStr);
              } else if (msgStr.startsWith("log:")) {
                loginLog('geetest.js', msgStr);
              } else if (msgStr.startsWith('close:')) {
                Get.back();
              }
            },
          ),
        ),
      );
    }

    return Stack(
      children: [
        InAppWebView(
          webViewEnvironment: webViewEnvironment,
          initialSettings: InAppWebViewSettings(
            clearCache: true,
            javaScriptEnabled: true,
            forceDark: ForceDark.AUTO,
            useHybridComposition: true,
            algorithmicDarkeningAllowed: true,
            useShouldOverrideUrlLoading: true,
            userAgent: BrowserUa.mob,
            mixedContentMode: .MIXED_CONTENT_ALWAYS_ALLOW,

            incognito: true,
            allowFileAccess: false,
            allowsLinkPreview: false,
            allowContentAccess: false,
            useOnDownloadStart: false,
            geolocationEnabled: false,
            thirdPartyCookiesEnabled: false,
            enterpriseAuthenticationAppLinkPolicyEnabled: false,
            saveFormData: false,
            safeBrowsingEnabled: false,
            isFraudulentWebsiteWarningEnabled: false,
            domStorageEnabled: true,
            databaseEnabled: false,
            cacheEnabled: false,
            cacheMode: .LOAD_NO_CACHE,

            horizontalScrollBarEnabled: false,
            verticalScrollBarEnabled: false,
            overScrollMode: .NEVER,

            pageZoom: Platform.isIOS ? 2 : 1,
          ),
          initialData: InAppWebViewInitialData(data: html),
          onWebViewCreated: (ctr) {
            ctr
              ..addJavaScriptHandler(
                handlerName: 'success',
                callback: (args) {
                  if (args.isNotEmpty) {
                    if (args[0] case Map<String, dynamic> data) {
                      loginLog('geetest.success', data);
                      Get.back(result: data);
                      return;
                    }
                  }
                  loginLog('geetest.invalidResult', args);
                  debugPrint('geetest invalid result: $args');
                },
              )
              ..addJavaScriptHandler(
                handlerName: 'error',
                callback: (args) {
                  loginLog('geetest.error', args);
                  debugPrint('geetest error: $args');
                },
              )
              ..addJavaScriptHandler(
                handlerName: 'jserror',
                callback: (args) {
                  loginLog('geetest.jsError', args);
                },
              )
              ..addJavaScriptHandler(
                handlerName: 'log',
                callback: (args) {
                  loginLog('geetest.js', args);
                },
              )
              ..addJavaScriptHandler(
                handlerName: 'close',
                callback: (args) => Get.back(),
              ),
        Positioned(
          left: 8,
          top: 8,
          child: IconButton(
            icon: const Icon(Icons.close),
            onPressed: Get.back,
            tooltip: '关闭',
          ),
        ),
      ],
    );
  }
}
