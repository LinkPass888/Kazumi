import 'package:flutter/material.dart';
import 'package:kazumi/bean/liquid_glass/kazumi_glass.dart';
import 'package:kazumi/bean/widget/collect_button.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';

/// A one-shot lease that keeps the player panel visible until released.
class PlayerPanelHold {
  PlayerPanelHold({required VoidCallback onRelease}) : _onRelease = onRelease;

  VoidCallback? _onRelease;

  bool get isReleased => _onRelease == null;

  void release() {
    final onRelease = _onRelease;
    if (onRelease == null) {
      return;
    }
    _onRelease = null;
    onRelease();
  }

  void releaseSilently() {
    _onRelease = null;
  }
}

/// Binds a hover/menu widget lifecycle to a panel hold so callers do not manage
/// counters or menu identities by hand.
class PlayerPanelHoldMouseRegion extends StatefulWidget {
  const PlayerPanelHoldMouseRegion({
    super.key,
    required this.acquirePlayerPanelHold,
    required this.child,
    this.cursor = MouseCursor.defer,
  });

  final PlayerPanelHold Function() acquirePlayerPanelHold;
  final Widget child;
  final MouseCursor cursor;

  @override
  State<PlayerPanelHoldMouseRegion> createState() =>
      _PlayerPanelHoldMouseRegionState();
}

class _PlayerPanelHoldMouseRegionState
    extends State<PlayerPanelHoldMouseRegion> {
  PlayerPanelHold? _hold;

  @override
  void dispose() {
    _releaseHold();
    super.dispose();
  }

  void _acquireHold() {
    if (_hold?.isReleased == false) {
      return;
    }
    _hold = widget.acquirePlayerPanelHold();
  }

  void _releaseHold() {
    _hold?.release();
    _hold = null;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.cursor,
      onEnter: (_) => _acquireHold(),
      onExit: (_) => _releaseHold(),
      child: widget.child,
    );
  }
}

/// Returns an offset only in landscape, preserving each caller's exact offset.
Offset? playerLandscapeOffset(BuildContext context, Offset offset) {
  final Size size = MediaQuery.sizeOf(context);
  return size.width > size.height ? offset : null;
}

class PlayerPanelHoldMenuAnchor extends StatefulWidget {
  const PlayerPanelHoldMenuAnchor({
    super.key,
    required this.acquirePlayerPanelHold,
    required this.onVisibilityChanged,
    required this.builder,
    required this.menuChildren,
    this.consumeOutsideTap = false,
    this.style,
    this.alignmentOffset,
  });

  final PlayerPanelHold Function() acquirePlayerPanelHold;
  final ValueChanged<bool> onVisibilityChanged;
  final Widget Function(
    BuildContext context,
    MenuController controller,
    Widget? child,
  ) builder;
  final List<Widget> menuChildren;
  final bool consumeOutsideTap;

  /// 菜单面板的样式，需要指定宽高（例如倍速菜单）时传进来。
  final MenuStyle? style;

  /// 菜单相对锚点的偏移。负的 dy 把面板顶到按钮上方（横屏按钮贴底时要用）。
  final Offset? alignmentOffset;

  @override
  State<PlayerPanelHoldMenuAnchor> createState() =>
      _PlayerPanelHoldMenuAnchorState();
}

class _PlayerPanelHoldMenuAnchorState extends State<PlayerPanelHoldMenuAnchor> {
  PlayerPanelHold? _hold;
  bool _isOpen = false;

  @override
  void dispose() {
    _handleClose();
    super.dispose();
  }

  void _handleOpen() {
    if (_isOpen) {
      return;
    }
    _isOpen = true;
    widget.onVisibilityChanged(true);
    if (_hold?.isReleased == false) {
      return;
    }
    _hold = widget.acquirePlayerPanelHold();
  }

  void _handleClose() {
    if (_isOpen) {
      _isOpen = false;
      widget.onVisibilityChanged(false);
    }
    _hold?.release();
    _hold = null;
  }

  @override
  Widget build(BuildContext context) {
    // 菜单不要滚动条（倍速那种长列表会把滚动条压在圆角上）
    return ScrollbarTheme(
      data: const ScrollbarThemeData(
        thickness: WidgetStatePropertyAll(0),
        thumbVisibility: WidgetStatePropertyAll(false),
        trackVisibility: WidgetStatePropertyAll(false),
      ),
      child: MenuAnchor(
      // 播放器的弹出菜单（倍速、超分辨率…）统一用和别的菜单一样的圆角
      style: (widget.style ?? const MenuStyle()).merge(
        MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(0),
          padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(
                Radius.circular(KazumiGlass.panelRadiusOf(context)),
              ),
            ),
          ),
        ),
      ),
      consumeOutsideTap: widget.consumeOutsideTap,
      alignmentOffset: widget.alignmentOffset,
      onOpen: _handleOpen,
      onClose: _handleClose,
      builder: widget.builder,
      menuChildren: [
        // 和收藏状态菜单同一套写法：一块玻璃当面板，内容原样交给它。
        // 不钉高度、不自接管滚动——上次就是那两样把面板弄坏的。
        KazumiGlass.glassSurface(
          shape: KazumiGlass.panelShapeOf(context),
          // 上下留空 = 面板圆角 − 条目圆角，两个圆角同心
          padding: KazumiGlass.menuPanelPadding,
          // 子菜单（倍速…）是从这里长出来的，ScrollbarTheme 套在这一层才吃得到
          child: ScrollbarTheme(
            data: const ScrollbarThemeData(
              thickness: WidgetStatePropertyAll(0),
              thumbVisibility: WidgetStatePropertyAll(false),
              trackVisibility: WidgetStatePropertyAll(false),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: widget.menuChildren,
            ),
          ),
        ),
      ],
      ),
    );
  }
}

class PlayerPanelHoldCollectButton extends StatefulWidget {
  const PlayerPanelHoldCollectButton({
    super.key,
    required this.acquirePlayerPanelHold,
    required this.bangumiItem,
    this.color = Colors.white,
  });

  final PlayerPanelHold Function() acquirePlayerPanelHold;
  final BangumiItem bangumiItem;
  final Color color;

  @override
  State<PlayerPanelHoldCollectButton> createState() =>
      _PlayerPanelHoldCollectButtonState();
}

class _PlayerPanelHoldCollectButtonState
    extends State<PlayerPanelHoldCollectButton> {
  PlayerPanelHold? _hold;

  @override
  void dispose() {
    _releaseHold();
    super.dispose();
  }

  void _acquireHold() {
    if (_hold?.isReleased == false) {
      return;
    }
    _hold = widget.acquirePlayerPanelHold();
  }

  void _releaseHold() {
    _hold?.release();
    _hold = null;
  }

  @override
  Widget build(BuildContext context) {
    return CollectButton(
      bangumiItem: widget.bangumiItem,
      color: widget.color,
      onOpen: _acquireHold,
      onClose: _releaseHold,
    );
  }
}
