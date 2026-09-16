import 'package:flutter/material.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:real_liquid_glass/real_liquid_glass.dart';

/// 液态玻璃（iOS 26 Liquid Glass）适配的统一入口。
///
/// iOS 26+ 上交给苹果原生的 `UIGlassEffect`：真正的折光液态玻璃，并且自动
/// 跟随系统的透明度滑块、降低透明度与增强对比度；iOS 26 以下是系统模糊；
/// 其它平台由 real_liquid_glass 自己画一层磨砂。所有玻璃表面都从这里出，
/// 是为了只有一处开关、形状统一，也方便随时整体退回原来的 Material 外观。
abstract final class KazumiGlass {
  /// 底部玻璃标签栏的高度（不含底部安全区）。
  ///
  /// 栏体浮在内容之上，所以滚动内容要让出这个高度 + 安全区，见
  /// [bottomInset]。
  static const double bottomBarHeight = 64;

  /// 是否启用液态玻璃，可在「设置 - 界面设置」里关闭。
  static bool get enabled =>
      GStorage.getSetting(SettingsKeys.enableLiquidGlass);

  /// 页面为了让开浮动的玻璃标签栏，需要额外留出的底部内边距。
  ///
  /// 关闭液态玻璃时返回 0，页面恢复原来的间距。
  static double bottomInset(BuildContext context) {
    if (!enabled) {
      return 0;
    }
    return bottomBarHeight + MediaQuery.paddingOf(context).bottom;
  }

  /// 通栏顶栏用的方角形状。
  static const LiquidGlassShape headerShape =
      LiquidGlassShape.roundedRectangle(0);

  /// 通栏顶栏的玻璃表面，贴在 AppBar 的 `flexibleSpace` 里。
  ///
  /// 关闭液态玻璃时返回 null，由 AppBar 自己画原来的背景色。
  static Widget? header({Key? key}) {
    if (!enabled) {
      return null;
    }
    return LiquidGlassContainer(
      key: key,
      style: LiquidGlassStyle.regular,
      shape: headerShape,
    );
  }
}
