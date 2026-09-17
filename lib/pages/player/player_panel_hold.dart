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

class PlayerPanelHoldMenuAnchor extends StatefulWidget {
  const PlayerPanelHoldMenuAnchor({
    super.key,
    required this.acquirePlayerPanelHold,
    required this.onVisibilityChanged,
    required this.builder,
    required this.menuChildren,
    this.consumeOutsideTap = false,
    this.style,
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
    final MenuStyle base = widget.style ?? const MenuStyle();
    final Size? fixed = base.fixedSize?.resolve(const <WidgetState>{});
    return MenuAnchor(
      // 播放器的弹出菜单（倍速、超分辨率…）和别的菜单一样：面板透明、圆角一致，
      // 真正的面板由下面那块玻璃画。
      style: base.merge(
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
      onOpen: _handleOpen,
      onClose: _handleClose,
      builder: widget.builder,
      menuChildren: [
        KazumiGlass.glassSurface(
          shape: KazumiGlass.panelShapeOf(context),
          padding: const EdgeInsets.all(KazumiGlass.menuPanelInset),
          child: SizedBox(
            width: fixed?.width,
            height: fixed?.height,
            child: fixed?.height != null
                // 定高面板（倍速菜单）：条目在里面滚，滚动条两端避开圆角
                ? SingleChildScrollView(
                    // 内边距必须是 0：面板高度是定死的，再加内边距内容就少一截
                    padding: EdgeInsets.zero,
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                      children: widget.menuChildren,
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: widget.menuChildren,
                  ),
          ),
        ),
      ],
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
