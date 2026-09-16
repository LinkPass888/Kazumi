import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/liquid_glass/kazumi_glass.dart';
import 'package:kazumi/bean/widget/embedded_native_control_area.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:window_manager/window_manager.dart';
import 'package:kazumi/utils/device.dart';

class SysAppBar extends StatelessWidget implements PreferredSizeWidget {
  final double? toolbarHeight;

  final Widget? title;

  final Color? backgroundColor;

  final double? elevation;

  final ShapeBorder? shape;

  final List<Widget>? actions;

  final Widget? leading;

  final double? leadingWidth;

  final PreferredSizeWidget? bottom;

  final bool needTopOffset;

  const SysAppBar(
      {super.key,
      this.toolbarHeight,
      this.title,
      this.backgroundColor,
      this.elevation,
      this.shape,
      this.actions,
      this.leading,
      this.leadingWidth,
      this.bottom,
      this.needTopOffset = true});

  bool showWindowButton() {
    return GStorage.getSetting(SettingsKeys.showWindowButton);
  }

  @override
  Widget build(BuildContext context) {
    final bool glass = KazumiGlass.enabled;
    List<Widget> acs = [];
    if (actions != null) {
      acs.addAll(actions!);
    }
    if (isDesktop()) {
      // acs.add(IconButton(onPressed: () => windowManager.minimize(), icon: const Icon(Icons.minimize)));
      if (!showWindowButton()) {
        acs.add(CloseButton(onPressed: () => windowManager.close()));
      }
      acs.add(const SizedBox(width: 8));
    }
    // 顶栏不再整条铺玻璃（那会在别的页面盖过来时透出一道光边），改成
    // iOS 26 的软渐进模糊，按钮各自带一层玻璃。
    // 返回键与右侧按钮统一成同样大小的圆形玻璃，图标居中，离边缘留白
    Widget? leadingWidget;
    if (leading != null) {
      leadingWidget = Center(
        child: KazumiGlass.buttonGlass(
          child: SizedBox(
            width: KazumiGlass.barButtonSize,
            height: KazumiGlass.barButtonSize,
            child: EmbeddedNativeControlArea(
              requireOffset: needTopOffset,
              child: leading!,
            ),
          ),
        ),
      );
    } else if (ModalRoute.of(context)?.impliesAppBarDismissal ?? false) {
      leadingWidget = Center(
        child: KazumiGlass.iconButton(
          context: context,
          icon: const Icon(Icons.arrow_back, size: 22),
          onPressed: () => context.maybePop(),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        ),
      );
    }
    final List<Widget> actionWidgets = <Widget>[];
    for (final Widget action in acs) {
      if (action is SizedBox) {
        actionWidgets.add(action);
        continue;
      }
      if (actionWidgets.isNotEmpty) {
        actionWidgets.add(const SizedBox(width: KazumiGlass.barButtonGap));
      }
      actionWidgets.add(
        KazumiGlass.buttonGlass(
          child: SizedBox(
            width: KazumiGlass.barButtonSize,
            height: KazumiGlass.barButtonSize,
            child: EmbeddedNativeControlArea(
              requireOffset: needTopOffset,
              child: action,
            ),
          ),
        ),
      );
    }
    if (actionWidgets.isNotEmpty) {
      actionWidgets.add(const SizedBox(width: KazumiGlass.barEdgeInset));
    }
    return GestureDetector(
      onPanStart: (_) => (isDesktop()) ? windowManager.startDragging() : null,
      child: AppBar(
        toolbarHeight: preferredSize.height,
        scrolledUnderElevation: 0.0,
        title: title != null
            ? EmbeddedNativeControlArea(
                requireOffset: needTopOffset,
                child: title!,
              )
            : null,
        centerTitle: false,
        actions: actionWidgets,
        leading: leadingWidget,
        leadingWidth: leadingWidth ?? KazumiGlass.barLeadingWidth,
        backgroundColor: glass ? Colors.transparent : backgroundColor,
        elevation: glass ? 0 : elevation,
        shape: shape,
        bottom: bottom,
        flexibleSpace: KazumiGlass.softHeader(context),
        automaticallyImplyLeading: false,
        systemOverlayStyle: KazumiGlass.overlayStyle(context),
      ),
    );
  }

  @override
  Size get preferredSize {
    // macOS needs to add 22(macOS title bar height)
    // to default toolbar height to build appbar like normal
    if (Platform.isMacOS && needTopOffset && showWindowButton()) {
      if (toolbarHeight != null) {
        return Size.fromHeight(toolbarHeight! + 22);
      } else {
        return const Size.fromHeight(kToolbarHeight + 22);
      }
    } else {
      return Size.fromHeight(toolbarHeight ?? kToolbarHeight);
    }
  }
}
