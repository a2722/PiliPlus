import 'dart:async';
import 'dart:convert' show jsonEncode;
import 'dart:io' show File, FileMode;

import 'package:PiliPlus/services/logger.dart' show logger;
import 'package:catcher_2/catcher_2.dart' show Catcher2;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:path_provider/path_provider.dart'
    show getApplicationDocumentsDirectory;

/// 登录 / 验证码流程的诊断日志。
///
/// 完全不依赖 `Pref.enableLog` / Catcher2：
/// - 内存环形缓冲 + 追加写入 Documents/login_debug.log
/// - 可一键复制到剪贴板，直接粘出来
/// - 顺带 logger.w 打控制台；Catcher2 已初始化时再多写一份到系统日志
///
/// 约定：密码、账号、手机号等只记录形状，其余字段（sign / buvid /
/// lot_number / tmp_token 等）保留原值，方便复现风控与验证码问题。
const int loginLogMaxLength = 4000;
const int _maxEntries = 500;
const int _maxFileBytes = 512 * 1024;

final List<String> _entries = <String>[];
File? _logFile;
bool _resolving = false;
Future<void> _writeQueue = Future<void>.value();

void loginLog(String event, [Object? detail]) {
  final String text = '$event${detail == null ? '' : ' ${_encode(detail)}'}';
  final String body = text.length > loginLogMaxLength
      ? '${text.substring(0, loginLogMaxLength)}...[truncated ${text.length}]'
      : text;
  final String line = '${DateTime.now().toIso8601String()} [login] $body';

  _entries.add(line);
  if (_entries.length > _maxEntries) {
    _entries.removeRange(0, _entries.length - _maxEntries);
  }
  logger.w(line);
  // Catcher2 未初始化（Pref.enableLog=false）时是空操作，不会抛异常。
  Catcher2.reportCheckedError(line, null);
  _writeQueue = _writeQueue.then((_) => _write(line));
}

/// 当前会话已录到的全部日志（供剪贴板 / 页面展示）。
String loginLogDump() {
  if (_entries.isEmpty) return '(login log empty)';
  return _entries.join('\n');
}

/// 复制到剪贴板，成功返回 true。
Future<bool> copyLoginLog() async {
  try {
    await Clipboard.setData(ClipboardData(text: loginLogDump()));
    return true;
  } catch (_) {
    return false;
  }
}

/// 日志文件名，位于 App 的 Documents 目录。
String get loginLogFileName => 'login_debug.log';

Future<void> _write(String line) async {
  try {
    final File? file = await _resolveFile();
    if (file == null) return;
    try {
      if (await file.length() > _maxFileBytes) {
        await file.writeAsString('', flush: true);
      }
    } catch (_) {}
    await file.writeAsString('$line\n', mode: FileMode.append, flush: true);
  } catch (_) {
    // 日志失败绝不影响登录流程
  }
}

Future<File?> _resolveFile() async {
  final File? cached = _logFile;
  if (cached != null) return cached;
  if (_resolving) return null;
  _resolving = true;
  try {
    final dir = await getApplicationDocumentsDirectory();
    return _logFile = File('${dir.path}/$loginLogFileName');
  } catch (_) {
    return null;
  } finally {
    _resolving = false;
  }
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
