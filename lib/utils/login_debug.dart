import 'dart:convert' show jsonEncode;

import 'package:PiliPlus/services/logger.dart' show logger;
import 'package:catcher_2/catcher_2.dart' show Catcher2;

/// 登录 / 验证码流程的诊断日志。
///
/// 双通道：
/// - `logger.w` 打到控制台（连着调试器时最直观）；
/// - `Catcher2.reportCheckedError` 落盘到 `.pili_logs.json`，release 包里也能
///   在「设置 → 日志」看到并一键复制，侧载安装、没有调试器时靠它留现场。
///
/// 约定：密码、账号、手机号等只记录形状，其余字段（sign / buvid /
/// lot_number / tmp_token 等）保留原值，方便复现风控与验证码问题。
const int loginLogMaxLength = 4000;

void loginLog(String event, [Object? detail]) {
  final String text = '[login] $event${detail == null ? '' : ' ${_encode(detail)}'}';
  final String message = text.length > loginLogMaxLength
      ? '${text.substring(0, loginLogMaxLength)}...[truncated ${text.length}]'
      : text;
  logger.w(message);
  // Catcher2 未初始化（Pref.enableLog=false）时是空操作，不会抛异常。
  Catcher2.reportCheckedError(message, null);
}

String _encode(Object? value) {
  if (value == null) return 'null';
  try {
    return jsonEncode(value, toEncodable: (Object? o) => o.toString());
  } catch (_) {
    return value.toString();
  }
}

/// 把敏感值压成“能看出长度和首尾、但不可还原”的形状。
String maskValue(Object? value) {
  final String text = value?.toString() ?? '';
  if (text.isEmpty) return '(empty)';
  if (text.length <= 6) return '****(${text.length})';
  return '${text.substring(0, 3)}****'
      '${text.substring(text.length - 2)}(${text.length})';
}

/// 请求参数脱敏：密码 / 账号 / 手机号 / cookie 只留形状，其余原样保留。
Map<String, dynamic> maskLoginParams(Map<String, dynamic> params) {
  final Map<String, dynamic> masked = <String, dynamic>{};
  params.forEach((String key, dynamic value) {
    final String lower = key.toLowerCase();
    final bool secret =
        lower.contains('password') ||
        lower == 'username' ||
        lower == 'tel' ||
        lower == 'cid' ||
        lower.contains('cookie');
    masked[key] = secret ? maskValue(value) : value;
  });
  return masked;
}
