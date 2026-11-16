import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models/common/rcmd_source.dart';
import 'package:PiliPlus/pages/common/common_controller.dart'
    show RefreshImplMixin;
import 'package:PiliPlus/pages/common/common_list_controller.dart';
import 'package:PiliPlus/utils/extension/scroll_controller_ext.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:get/get.dart' show RxBool;

class RcmdController extends CommonListController with RefreshImplMixin {
  late bool enableSaveLastData = Pref.enableSaveLastData;

  /// 启动后前 N 批推荐内容置空，可在设置页开关
  late bool enablePrelaunchBlankRcmd = Pref.enablePrelaunchBlankRcmd;

  /// 当前是否处于置空阶段。渲染层据此遮蔽卡片内容，
  /// 数据本身不做任何修改，因此阶段结束后前几批会一起恢复。
  late final RxBool blankPhase = RxBool(enablePrelaunchBlankRcmd);

  /// 本次进程内还要置空几批；冷启动时类加载重置
  static int _blankRemain = 2;

  /// 设置页切换开关时重置计数与状态
  void resetBlankState() {
    _blankRemain = 2;
    blankPhase.value = enablePrelaunchBlankRcmd;
  }

  /// 可在设置页切换后立即生效，无需重启
  RcmdSource rcmdSource = Pref.rcmdSource;

  int? lastRefreshAt;
  late bool savedRcmdTip = Pref.savedRcmdTip;

  @override
  bool get isEnd => false;

  @override
  void onInit() {
    super.onInit();
    page = 0;
    queryData();
  }

  @override
  Future<LoadingState> customGetData() {
    return switch (rcmdSource) {
      RcmdSource.app => VideoHttp.rcmdVideoListApp(freshIdx: page),
      // 桌面端：与官方 Windows 客户端一致，每次请求 30 条
      RcmdSource.desktop => VideoHttp.rcmdVideoList(
        freshIdx: page,
        ps: 30,
        desktop: true,
      ),
      RcmdSource.web => VideoHttp.rcmdVideoList(freshIdx: page, ps: 20),
    };
  }

  @override
  bool handleError(String? errMsg) {
    return enableSaveLastData;
  }

  @override
  void handleListResponse(List dataList) {
    if (enableSaveLastData && page == 0) {
      if (loadingState.value case Success(:final response)) {
        if (response != null && response.isNotEmpty) {
          if (savedRcmdTip) {
            lastRefreshAt = dataList.length;
          }
          if (response.length > 200) {
            dataList.addAll(response.take(50));
          } else {
            dataList.addAll(response);
          }
        }
      }
    }
    _updateBlankPhase();
  }

  /// 只翻转标志，不改数据。
  /// 第 1、2 批：blankPhase=true，全部卡片遮蔽；
  /// 第 3 批：blankPhase=false，连前面几批一起恢复正常。
  void _updateBlankPhase() {
    if (!enablePrelaunchBlankRcmd) {
      blankPhase.value = false;
      return;
    }
    if (_blankRemain > 0) {
      _blankRemain--;
      blankPhase.value = true;
    } else {
      blankPhase.value = false;
    }
  }

  @override
  Future<void> onRefresh() {
    page = 0;
    isEnd = false;
    return queryData();
  }

  void toTopAndRefresh() {
    scrollController.jumpToTop();
    showRefresh();
  }
}
