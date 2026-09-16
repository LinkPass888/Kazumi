import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// 顶栏按钮的统一尺寸。
  ///
  /// 左右两侧（返回键与功能按钮）用同一个尺寸，[barButtonGap] 是按钮之间的
  /// 间距，[barEdgeInset] 是离屏幕边缘的距离。
  static const double barButtonSize = 40;
  static const double barButtonGap = 6;
  static const double barEdgeInset = 10;

  /// 顶栏按钮占位宽度：按钮 + 两侧留白。
  static const double barLeadingWidth = barButtonSize + barEdgeInset * 2;

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

  /// 一颗可点的小玻璃按钮（放送星期、追番分类这类标签）。
  ///
  /// 选中填充画在玻璃**内部**，尺寸和玻璃完全一致；点按反馈交给原生玻璃
  /// 自己的高光，不用 Material 的水波纹 —— 后者按标签区域画，会比玻璃大一圈。
  static Widget glassButton({
    required BuildContext context,
    required Widget child,
    required VoidCallback? onTap,
    bool selected = false,
    EdgeInsetsGeometry padding =
        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    // 触摸交给 Flutter 的 InkWell：平台视图只当背景（interactive: false），
    // 这样一定点得到；按下时是圆角高亮，不是 Material 的水波纹。
    final Widget tappable = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        splashFactory: NoSplash.splashFactory,
        highlightColor: scheme.primary.withValues(alpha: 0.16),
        child: Padding(padding: padding, child: child),
      ),
    );
    final Widget filled = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        shape: const StadiumBorder(),
        color: selected
            ? scheme.primary.withValues(alpha: 0.30)
            : Colors.transparent,
      ),
      child: tappable,
    );
    if (!enabled) {
      return filled;
    }
    return LiquidGlassContainer(
      shape: circleShape,
      style: LiquidGlassStyle.regular,
      // 装饰用，不拦触摸
      interactive: false,
      child: filled,
    );
  }

  /// 玻璃面板里的一个可点条目。
  ///
  /// 不额外铺玻璃（苹果不建议玻璃叠玻璃，实测也会点不动），整块菜单还是一块
  /// 大玻璃；条目只负责按下时的圆角高亮。
  static Widget menuItem({
    required BuildContext context,
    required Widget child,
    required VoidCallback? onTap,
    bool selected = false,
    EdgeInsetsGeometry padding =
        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    double radius = 12,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(radius)),
          ),
          splashFactory: NoSplash.splashFactory,
          highlightColor: scheme.primary.withValues(alpha: 0.16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            padding: padding,
            decoration: ShapeDecoration(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(radius)),
              ),
              color: selected
                  ? scheme.primary.withValues(alpha: 0.22)
                  : Colors.transparent,
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  /// 顶栏用的系统状态栏样式：透明背景 + 跟随主题明暗的图标。
  ///
  /// 顶栏背景一旦设成透明，AppBar 自己推断出来的样式会把状态栏图标定成白色
  /// 并一直留着，所以这里显式给一份。iOS 看的是 [SystemUiOverlayStyle.statusBarBrightness]
  /// （状态栏背景的明暗），安卓看的是 `statusBarIconBrightness`，两个都要给。
  static SystemUiOverlayStyle overlayStyle(BuildContext context) {
    final bool light = Theme.of(context).brightness == Brightness.light;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: light ? Brightness.dark : Brightness.light,
      statusBarBrightness: light ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    );
  }

  /// 一块玻璃表面，[child] 画在玻璃之上。
  ///
  /// 关闭液态玻璃时原样返回 [child]，由调用方自己决定原来的外观。
  static Widget glassSurface({
    required Widget child,
    LiquidGlassShape shape = circleShape,
    EdgeInsetsGeometry? padding,
  }) {
    if (!enabled) {
      return child;
    }
    return LiquidGlassContainer(
      shape: shape,
      style: LiquidGlassStyle.regular,
      padding: padding,
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
    double size = barButtonSize,
  }) {
    if (!enabled) {
      return IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: icon,
      );
    }
    // 触摸交给 Flutter 的 InkWell：平台视图自己接管触摸时，回调偶尔传不回来，
    // 表现就是「返回键点了没反应」。
    final Widget button = LiquidGlassContainer(
      shape: circleShape,
      style: LiquidGlassStyle.regular,
      width: size,
      height: size,
      interactive: false,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          splashFactory: NoSplash.splashFactory,
          highlightColor:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.16),
          child: Center(child: icon),
        ),
      ),
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
