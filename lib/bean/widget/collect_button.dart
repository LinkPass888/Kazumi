import 'package:flutter/material.dart';
import 'package:kazumi/bean/liquid_glass/kazumi_glass.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:flutter_modular/flutter_modular.dart';

class CollectButton extends StatefulWidget {
  CollectButton({
    super.key,
    required this.bangumiItem,
    this.color = Colors.white,
    this.onOpen,
    this.onClose,
  }) {
    isExtended = false;
  }

  CollectButton.extend({
    super.key,
    required this.bangumiItem,
    this.color = Colors.white,
    this.onOpen,
    this.onClose,
  }) {
    isExtended = true;
  }

  final BangumiItem bangumiItem;
  final Color color;
  late final bool isExtended;
  final void Function()? onOpen;
  final void Function()? onClose;

  @override
  State<CollectButton> createState() => _CollectButtonState();
}

class _CollectButtonState extends State<CollectButton> {
  // 1. 在看
  // 2. 想看
  // 3. 搁置
  // 4. 看过
  // 5. 抛弃
  late int collectType;
  final CollectController collectController = inject<CollectController>();

  @override
  void initState() {
    super.initState();
  }

  String getTypeStringByInt(int collectType) {
    switch (collectType) {
      case 1:
        return "在看";
      case 2:
        return "想看";
      case 3:
        return "搁置";
      case 4:
        return "看过";
      case 5:
        return "抛弃";
      default:
        return "未追";
    }
  }

  IconData getIconByInt(int collectType) {
    switch (collectType) {
      case 1:
        return Icons.favorite;
      case 2:
        return Icons.star_rounded;
      case 3:
        return Icons.pending_actions;
      case 4:
        return Icons.done;
      case 5:
        return Icons.heart_broken;
      default:
        return Icons.favorite_border;
    }
  }

  @override
  Widget build(BuildContext context) {
    collectType = collectController.getCollectType(widget.bangumiItem);
    return MenuAnchor(
      consumeOutsideTap: true,
      onClose: widget.onClose,
      onOpen: widget.onOpen,
      crossAxisUnconstrained: false,
      // 面板本身画不了玻璃（框架自己画 Material），所以把它整块变透明，
      // 再在 menuChildren 里放一块玻璃顶上去。
      style: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Colors.transparent),
        elevation: WidgetStatePropertyAll(0),
        padding: WidgetStatePropertyAll(EdgeInsets.zero),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
        ),
      ),
      builder: (_, MenuController controller, __) {
        if (widget.isExtended) {
          return FilledButton.icon(
            onPressed: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
            icon: Icon(getIconByInt(collectType)),
            label: Text(getTypeStringByInt(collectType)),
          );
        } else {
          return IconButton(
            onPressed: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
            tooltip: getTypeStringByInt(collectType),
            icon: Icon(
              getIconByInt(collectType),
              color: widget.color,
            ),
          );
        }
      },
      // 面板整块用玻璃画：框架的菜单面板本身画不了玻璃，所以先把它的背景
      // 变透明，再把这一块玻璃当作唯一的面板内容顶上去。
      menuChildren: [
        KazumiGlass.glassSurface(
          shape: KazumiGlass.panelShape,
          child: SizedBox(
            width: 176,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: List<MenuItemButton>.generate(
                6,
                (int index) => MenuItemButton(
                  onPressed: () async {
                    if (index != collectType && mounted) {
                      await collectController.addCollect(widget.bangumiItem,
                          type: index);
                      // 防止状态错误刷新
                      if (!mounted) {
                        return;
                      }
                      setState(() {});
                    }
                  },
                  child: Container(
                    height: 44,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            getIconByInt(index),
                            color: index == collectType
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            ' ${getTypeStringByInt(index)}',
                            style: TextStyle(
                              color: index == collectType
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
