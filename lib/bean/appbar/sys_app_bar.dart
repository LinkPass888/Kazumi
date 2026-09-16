import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final Widget? leadingWidget = leading != null
        ? EmbeddedNativeControlArea(
            requireOffset: needTopOffset,
            child: leading!,
          )
        : (ModalRoute.of(context)?.impliesAppBarDismissal ?? false)
            ? EmbeddedNativeControlArea(
                requireOffset: needTopOffset,
                child: IconButton(
                  onPressed: () {
                    context.maybePop();
                  },
                  icon: Icon(Icons.arrow_back),
                ),
              )
            : null;
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
        centerTitle: Platform.isIOS ? true : false,
        actions: acs.map((e) {
          if (e is SizedBox) {
            return e;
          }
          return KazumiGlass.buttonGlass(
            child: EmbeddedNativeControlArea(
              requireOffset: needTopOffset,
              child: e,
            ),
          );
        }).toList(),
        leading: leadingWidget == null
            ? null
            : KazumiGlass.buttonGlass(child: leadingWidget),
        leadingWidth: leadingWidth,
        backgroundColor: glass ? Colors.transparent : backgroundColor,
        elevation: glass ? 0 : elevation,
        shape: shape,
        bottom: bottom,
        flexibleSpace: KazumiGlass.softHeader(context),
        automaticallyImplyLeading: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              Theme.of(context).brightness == Brightness.light
                  ? Brightness.dark
                  : Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
        ),
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
