import 'package:flutter/material.dart';
import 'package:kazumi/bean/liquid_glass/soft_progressive_blur.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:real_liquid_glass/real_liquid_glass.dart';

/// 液态玻璃（iOS 26 Liquid Glass）适配的统一入口。
///
/// iOS 26+ 上交给苹果原生的 `UIGlassEffect`：真正的折光液态玻璃，并且自动
/// 跟随系统的透明度滑块、降低透明度与增强对比度；iOS 26 以下是系统模糊；
/// 其它平台由 real_liquid_glass 自己画一层磨砂。所有玻璃表面都从这里出，
/// 是为了只有一处开关、形状统一，也方便随时整体退回原来的 Material 外观。
abstract final class KazumiGlass {
  /// 底部玻璃标签栏的高度。
  ///
  /// iOS 上这是原生 `UITabBar` 的高度，栏体一直铺到屏幕底部并自己处理底部
  /// 安全区，所以这里包含安全区高度。
  static const double bottomBarHeight = 85;

  /// 圆形按钮 / 浮动按钮的形状。
  static const LiquidGlassShape circleShape = LiquidGlassShape.capsule();

  /// 分组控件（放送星期、追番分类这类标签）的胶囊形状。
  static const LiquidGlassShape pillShape =
      LiquidGlassShape.roundedRectangle(22);

  /// 菜单、面板用的圆角形状。
  static const LiquidGlassShape panelShape =
      LiquidGlassShape.roundedRectangle(16);

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
    // 栏体本身已经盖住底部安全区，这里再留一点余量，免得最后一行贴着玻璃。
    return bottomBarHeight + 8;
  }

  /// 顶栏的软渐进模糊（iOS 26 的 `scrollEdgeEffectStyle(.soft)`）。
  ///
  /// 关掉液态玻璃时返回 null，由 AppBar 自己画原来的背景色。
  static Widget? softHeader(BuildContext context, {double height = 104}) {
    if (!enabled) {
      return null;
    }
    return SoftProgressiveBlur(
      height: height,
      tint: Theme.of(context).colorScheme.surface,
    );
  }

  /// 一块玻璃表面，[child] 画在玻璃之上。
  ///
  /// 关闭液态玻璃时原样返回 [child]，由调用方自己决定原来的外观。
  static Widget glassSurface({
    required Widget child,
    LiquidGlassShape shape = circleShape,
  }) {
    if (!enabled) {
      return child;
    }
    return LiquidGlassContainer(
      shape: shape,
      style: LiquidGlassStyle.regular,
      child: child,
    );
  }

  /// 顶栏按钮的玻璃底。
  ///
  /// 只做装饰：`interactive` 保持 false，触摸照旧落到里面的按钮上。
  static Widget buttonGlass({required Widget child}) {
    if (!enabled) {
      return child;
    }
    return LiquidGlassContainer(
      shape: circleShape,
      style: LiquidGlassStyle.regular,
      child: child,
    );
  }

  /// 圆形玻璃按钮：图标固定居中在玻璃正中，点按区就是整块玻璃。
  ///
  /// 顶栏的返回键用它，避免出现「符号没在玻璃中间」的情况。
  static Widget iconButton({
    required BuildContext context,
    required Widget icon,
    required VoidCallback? onPressed,
    String? tooltip,
    double size = 44,
  }) {
    if (!enabled) {
      return IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: icon,
      );
    }
    final Widget button = LiquidGlassContainer(
      shape: circleShape,
      style: LiquidGlassStyle.regular,
      width: size,
      height: size,
      interactive: true,
      onTap: onPressed,
      child: Center(child: icon),
    );
    if (tooltip == null) {
      return button;
    }
    return Tooltip(message: tooltip, child: button);
  }

  /// 浮在玻璃标签栏之上的浮动按钮。
  ///
  /// 顺手把 Material FAB 的表面变透明、去掉阴影并改成胶囊（圆形按钮就是圆，
  /// 扩展按钮就是药丸），让玻璃透出来；点按与涟漪还是 FAB 自己的。
  static Widget floatingButton({
    required BuildContext context,
    required Widget child,
    bool aboveTabBar = true,
  }) {
    if (!enabled) {
      return child;
    }
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Widget themed = Theme(
      data: Theme.of(context).copyWith(
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.transparent,
          foregroundColor: scheme.primary,
          elevation: 0,
          focusElevation: 0,
          hoverElevation: 0,
          highlightElevation: 0,
          shape: const StadiumBorder(),
        ),
      ),
      child: child,
    );
    return Padding(
      padding: EdgeInsets.only(
        bottom: aboveTabBar ? bottomInset(context) : 0,
      ),
      child: glassSurface(child: themed),
    );
  }
}
