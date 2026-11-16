import 'package:PiliPlus/utils/extension/scroll_controller_ext.dart';
import 'package:flutter/widgets.dart'
    show MediaQuery, Offset, RenderBox, ScrollController, State, StatefulWidget,
        WidgetsBinding, WidgetsBindingObserver;

/// iOS 点击状态栏回到顶部。
///
/// 只有当前可见的 tab 会响应：TabBarView 用的是 PageView，
/// 被隐藏的页面会整体偏移到屏幕外，这里用 RenderBox 的水平位置判断，
/// 避免隐藏 tab 一起滚到顶部、丢失浏览位置。
mixin StatusBarToTopMixin<T extends StatefulWidget> on State<T>
    implements WidgetsBindingObserver {
  ScrollController get statusBarController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void handleStatusBarTap() {
    if (!mounted) return;
    if (!_visibleInViewport()) return;
    statusBarController.animToTop();
  }

  bool _visibleInViewport() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) {
      return false;
    }
    final dx = box.localToGlobal(Offset.zero).dx;
    final width = MediaQuery.sizeOf(context).width;
    return dx + box.size.width > 0 && dx < width;
  }
}
