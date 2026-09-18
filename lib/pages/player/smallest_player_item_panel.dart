import 'dart:io';
import 'package:flutter/material.dart';
import 'package:kazumi/bean/liquid_glass/kazumi_glass.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kazumi/bean/widget/play_pause_icon.dart';
import 'package:kazumi/pages/player/player_adjustment_hud.dart';
import 'package:kazumi/pages/player/controller/player_aspect_ratio.dart';
import 'package:kazumi/pages/player/controller/player_super_resolution.dart';
import 'package:kazumi/pages/player/player_panel_hold.dart';
import 'package:kazumi/services/player/pip_utils.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/services/player/remote.dart';
import 'package:kazumi/pages/settings/danmaku/danmaku_settings_sheet.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/bean/appbar/drag_to_move_bar.dart' as dtb;
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:kazumi/bean/widget/embedded_native_control_area.dart';
import 'package:kazumi/services/player/timed_shutdown_service.dart';
import 'package:kazumi/utils/device.dart';
import 'package:kazumi/utils/format.dart';

class SmallestPlayerItemPanel extends StatefulWidget {
  const SmallestPlayerItemPanel({
    super.key,
    required this.playerController,
    required this.videoPageController,
    required this.onBackPressed,
    required this.setPlaybackSpeed,
    required this.showDanmakuSwitch,
    required this.handleFullscreen,
    required this.enterAndroidPictureInPicture,
    required this.handleProgressBarDragStart,
    required this.handleProgressBarSeek,
    required this.handleSuperResolutionChange,
    required this.panelVisibilityController,
    required this.acquirePlayerPanelHold,
    required this.onMenuVisibilityChanged,
    required this.handleDanmaku,
    required this.skipOP,
    required this.showVideoInfo,
    required this.showSyncPlayPanel,
    required this.pauseForTimedShutdown,
    this.disableAnimations = false,
  });

  final PlayerController playerController;
  final VideoPageController videoPageController;
  final void Function(BuildContext) onBackPressed;
  final Future<void> Function(double) setPlaybackSpeed;
  final void Function() showDanmakuSwitch;
  final void Function() handleDanmaku;
  final void Function() skipOP;
  final void Function() handleFullscreen;
  final Future<void> Function() enterAndroidPictureInPicture;
  final VoidCallback handleProgressBarDragStart;
  final Future<void> Function(Duration duration) handleProgressBarSeek;
  final Future<void> Function(SuperResolutionMode mode)
      handleSuperResolutionChange;
  final AnimationController panelVisibilityController;
  final PlayerPanelHold Function() acquirePlayerPanelHold;
  final ValueChanged<bool> onMenuVisibilityChanged;
  final void Function() showVideoInfo;
  final void Function() showSyncPlayPanel;
  final VoidCallback pauseForTimedShutdown;
  final bool disableAnimations;

  @override
  State<SmallestPlayerItemPanel> createState() =>
      _SmallestPlayerItemPanelState();
}

class _SmallestPlayerItemPanelState extends State<SmallestPlayerItemPanel> {
  late Animation<Offset> topOffsetAnimation;
  late Animation<Offset> bottomOffsetAnimation;
  late final VideoPageController videoPageController =
      widget.videoPageController;
  late final PlayerController playerController;

  String? cachedSvgString;
  Widget? cachedDanmakuOnIcon;
  Widget? cachedDanmakuOffIcon;

  static const double _danmakuIconSize = 24.0;
  static const double _loadingIndicatorStrokeWidth = 2.0;

  void showForwardChange() {
    KazumiDialog.show(builder: (context) {
      String input = "";
      return AlertDialog(
        title: const Text('跳过秒数'),
        content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
          return TextField(
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: InputDecoration(
              floatingLabelBehavior: FloatingLabelBehavior.never,
              labelText: playerController.playback.buttonSkipTime.toString(),
            ),
            onChanged: (value) {
              input = value;
            },
          );
        }),
        actions: <Widget>[
          TextButton(
            onPressed: () => KazumiDialog.dismiss(),
            child: Text(
              '取消',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          TextButton(
            onPressed: () async {
              if (input != "") {
                playerController.setButtonForwardTime(int.parse(input));
                KazumiDialog.dismiss();
              } else {
                KazumiDialog.dismiss();
              }
            },
            child: const Text('确定'),
          ),
        ],
      );
    });
  }

  @override
  void initState() {
    super.initState();
    playerController = widget.playerController;
    topOffsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0),
      end: const Offset(0.0, 0.0),
    ).animate(CurvedAnimation(
      parent: widget.panelVisibilityController,
      curve: Curves.easeInOut,
    ));
    bottomOffsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: const Offset(0.0, 0.0),
    ).animate(CurvedAnimation(
      parent: widget.panelVisibilityController,
      curve: Curves.easeInOut,
    ));
    cacheSvgIcons();
  }

  void cacheSvgIcons() {
    cachedDanmakuOffIcon = RepaintBoundary(
      child: SvgPicture.asset(
        'assets/images/danmaku_off.svg',
        height: _danmakuIconSize,
      ),
    );
  }

  Widget danmakuOnIcon(BuildContext context) {
    final colorHex = Theme.of(context)
        .colorScheme
        .primary
        .toARGB32()
        .toRadixString(16)
        .substring(2);

    if (cachedSvgString != colorHex) {
      cachedSvgString = colorHex;
      final svgString = danmakuOnSvg.replaceFirst('00AEEC', colorHex);
      cachedDanmakuOnIcon = RepaintBoundary(
        child: SvgPicture.string(
          svgString,
          height: _danmakuIconSize,
        ),
      );
    }

    return cachedDanmakuOnIcon!;
  }

  Widget _buildDanmakuToggleButton(BuildContext context) {
    return Observer(builder: (context) {
      final danmakuLoading = playerController.danmaku.danmakuLoading;
      final danmakuOn = playerController.danmaku.danmakuOn;
      return IconButton(
        color: Colors.white,
        icon: danmakuLoading
            ? SizedBox(
                width: _danmakuIconSize,
                height: _danmakuIconSize,
                child: CircularProgressIndicator(
                  strokeWidth: _loadingIndicatorStrokeWidth,
                ),
              )
            : (danmakuOn ? danmakuOnIcon(context) : cachedDanmakuOffIcon!),
        onPressed: danmakuLoading
            ? null
            : () {
                widget.handleDanmaku();
              },
        tooltip: danmakuLoading ? '弹幕加载中...' : (danmakuOn ? '关闭弹幕' : '打开弹幕'),
      );
    });
  }

  Widget forwardIcon() {
    return Tooltip(
      message: '快进${playerController.playback.buttonSkipTime}秒，长按修改时间',
      child: GestureDetector(
        onLongPress: () => showForwardChange(),
        child: IconButton(
          icon: Image.asset(
            'assets/images/forward_80.png',
            color: Colors.white,
            height: 24,
          ),
          onPressed: () {
            widget.skipOP();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedPositioned(
          duration: const Duration(seconds: 1),
          top: 0,
          left: 0,
          right: 0,
          child: Observer(builder: (context) {
            return Visibility(
              visible: !playerController.panel.lockPanel &&
                  (widget.disableAnimations
                      ? playerController.panel.showVideoController
                      : true),
              child: widget.disableAnimations
                  ? Container(
                      height: 50,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black45,
                            Colors.transparent,
                          ],
                        ),
                      ),
                    )
                  : SlideTransition(
                      position: topOffsetAnimation,
                      child: Container(
                        height: 50,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black45,
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
            );
          }),
        ),
        AnimatedPositioned(
          duration: const Duration(seconds: 1),
          bottom: 0,
          left: 0,
          right: 0,
          child: Observer(builder: (context) {
            return Visibility(
              visible: !playerController.panel.lockPanel &&
                  (widget.disableAnimations
                      ? playerController.panel.showVideoController
                      : true),
              child: widget.disableAnimations
                  ? Container(
                      height: 100,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black45,
                          ],
                        ),
                      ),
                    )
                  : SlideTransition(
                      position: bottomOffsetAnimation,
                      child: Container(
                        height: 100,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black45,
                            ],
                          ),
                        ),
                      ),
                    ),
            );
          }),
        ),
        Positioned(
          top: 25,
          child: Observer(builder: (context) {
            // PlayerSeekHud latches values only while visible, so skipping the
            // position reads when hidden keeps the 1s tick from rebuilding this.
            final visible = playerController.panel.showSeekTime;
            return PlayerSeekHud(
              visible: visible,
              currentPosition: visible
                  ? playerController.playback.currentPosition
                  : Duration.zero,
              playerPosition: visible
                  ? playerController.playback.playerPosition
                  : Duration.zero,
              duration:
                  visible ? playerController.playback.duration : Duration.zero,
              direction: playerController.panel.seekDirection,
              disableAnimations: widget.disableAnimations,
            );
          }),
        ),
        Positioned(
          top: 25,
          child: Observer(builder: (context) {
            return PlayerSpeedHud(
              visible: playerController.panel.showPlaySpeed,
              speed: playerController.playback.playerSpeed,
              disableAnimations: widget.disableAnimations,
            );
          }),
        ),
        Positioned(
          top: 25,
          child: Observer(builder: (context) {
            final showVolume = playerController.panel.showVolume;
            final showBrightness = playerController.panel.showBrightness;
            return PlayerAdjustmentHud(
              visible: showVolume || showBrightness,
              type: showVolume
                  ? PlayerAdjustmentHudType.volume
                  : PlayerAdjustmentHudType.brightness,
              value: showVolume
                  ? playerController.playback.volume
                  : playerController.panel.brightness,
              disableAnimations: widget.disableAnimations,
            );
          }),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Observer(builder: (context) {
            return Visibility(
              visible: !playerController.panel.lockPanel &&
                  (widget.disableAnimations
                      ? playerController.panel.showVideoController
                      : true),
              child: widget.disableAnimations
                  ? topControlWidget
                  : SlideTransition(
                      position: topOffsetAnimation, child: topControlWidget),
            );
          }),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Observer(builder: (context) {
            return Visibility(
              visible: !playerController.panel.lockPanel &&
                  (widget.disableAnimations
                      ? playerController.panel.showVideoController
                      : true),
              child: widget.disableAnimations
                  ? bottomControlWidget
                  : SlideTransition(
                      position: bottomOffsetAnimation,
                      child: bottomControlWidget),
            );
          }),
        ),
      ],
    );
  }

  Widget get bottomControlWidget {
    return Row(
      children: [
        IconButton(
          icon: PlayPauseIcon(
            iconColor: Colors.white,
            playing: playerController.playback.playing,
          ),
          tooltip: playerController.playback.playing ? '暂停' : '播放',
          onPressed: () {
            playerController.playOrPause();
          },
        ),
        // Position reads stay inside these narrow Observers so the 1s progress
        // tick rebuilds only the bar and time text, not the whole bottom bar.
        Expanded(
          child: Observer(builder: (context) {
            return ProgressBar(
              thumbRadius: 8,
              thumbGlowRadius: 18,
              timeLabelLocation: TimeLabelLocation.none,
              progress: playerController.playback.currentPosition,
              buffered: playerController.playback.buffer,
              total: playerController.playback.duration,
              onSeek: widget.handleProgressBarSeek,
              onDragStart: (_) => widget.handleProgressBarDragStart(),
              onDragUpdate: (details) => playerController.seeking
                  .updateInteractiveSeek(details.timeStamp),
            );
          }),
        ),
        Observer(builder: (context) {
          return Text(
            "    ${durationToString(playerController.playback.currentPosition)} / ${durationToString(playerController.playback.duration)}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.0,
              fontFeatures: [
                FontFeature.tabularFigures(),
              ],
            ),
          );
        }),
        (!videoPageController.isPip)
            ? IconButton(
                color: Colors.white,
                icon: Icon(videoPageController.isFullscreen
                    ? Icons.fullscreen_exit_rounded
                    : Icons.fullscreen_rounded),
                tooltip: videoPageController.isFullscreen ? '退出全屏' : '全屏',
                onPressed: () {
                  widget.handleFullscreen();
                },
              )
            : const Text('    '),
      ],
    );
  }

  Widget get topControlWidget {
    return EmbeddedNativeControlArea(
      child: Row(
        children: [
          IconButton(
            color: Colors.white,
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: '返回',
            onPressed: () {
              widget.onBackPressed(context);
            },
          ),
          const Expanded(
            child: dtb.DragToMoveArea(child: SizedBox(height: 40)),
          ),
          forwardIcon(),
          if (isDesktop() || Platform.isAndroid)
            IconButton(
                onPressed: () async {
                  if (isDesktop()) {
                    if (videoPageController.isPip) {
                      await PipUtils.exitDesktopPIPWindow();
                    } else {
                      // Size the PiP window to the video aspect ratio to
                      // avoid letterboxing.
                      await PipUtils.enterDesktopPIPWindow(
                        width: playerController.debug.playerWidth,
                        height: playerController.debug.playerHeight,
                      );
                    }
                    videoPageController.isPip = !videoPageController.isPip;
                    return;
                  }
                  await widget.enterAndroidPictureInPicture();
                },
                tooltip: '画中画',
                icon:
                    const Icon(Icons.picture_in_picture, color: Colors.white)),
          _buildDanmakuToggleButton(context),
          PlayerPanelHoldCollectButton(
            acquirePlayerPanelHold: widget.acquirePlayerPanelHold,
            bangumiItem: videoPageController.bangumiItem,
          ),
          PlayerPanelHoldMenuAnchor(
            acquirePlayerPanelHold: widget.acquirePlayerPanelHold,
            onVisibilityChanged: widget.onMenuVisibilityChanged,
            consumeOutsideTap: true,
            builder: (BuildContext context, MenuController controller,
                Widget? child) {
              return IconButton(
                onPressed: () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                },
                tooltip: '更多选项',
                icon: const Icon(
                  Icons.more_vert,
                  color: Colors.white,
                ),
              );
            },
            menuChildren: <Widget>[
              PlayerPanelHoldMenuAnchor(
                acquirePlayerPanelHold: widget.acquirePlayerPanelHold,
                onVisibilityChanged: widget.onMenuVisibilityChanged,
                consumeOutsideTap: true,
                // 只改横屏：往上顶，和超分辨率菜单（基准）的下沿对齐
                alignmentOffset: playerLandscapeOffset(context, const Offset(-40, -186)),
                builder: (BuildContext context, MenuController controller,
                    Widget? child) {
                  // 触发条目本身就是普通玻璃条目：和别的条目同一个 widget、
                  // 同一套内边距 —— 文字自然对齐，按下深色范围也完全一致
                  return KazumiGlass.menuItem(
                    context: context,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    closeMenu: false,
                    onTap: () {
                      if (controller.isOpen) {
                        controller.close();
                      } else {
                        controller.open();
                      }
                    },
                    child: SizedBox(
                      height: 48,
                      width: 112,
                      child: Align(
                        alignment: Alignment.center,
                        child: Text(
                          '视频比例',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                    ),
                  );
                },
                menuChildren: <Widget>[

                  for (final aspectRatioMode in PlayerAspectRatio.values)
                    KazumiGlass.menuItem(
                      context: context,
                      // 四周等距：横向 14，纵向由条目高 48 撑开
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      selected:
                          playerController.panel.aspectRatioMode ==
                              aspectRatioMode,
                      onTap: () => playerController.panel.aspectRatioMode =
                          aspectRatioMode,
                      child: SizedBox(
                        height: 48,
                        width: 112,
                        child: Align(
                          alignment: Alignment.center,
                          child: Text(aspectRatioMode.label),
                        ),
                      ),
                    ),
                ],
              ),
              PlayerPanelHoldMenuAnchor(
                acquirePlayerPanelHold: widget.acquirePlayerPanelHold,
                onVisibilityChanged: widget.onMenuVisibilityChanged,
                consumeOutsideTap: true,
                // 只挪横屏：下沿和超分辨率菜单的下沿齐平
                alignmentOffset:
                    playerLandscapeOffset(
                      context, const Offset(-30, -240)),
                builder: (BuildContext context, MenuController controller,
                    Widget? child) {
                  // 触发条目就是普通玻璃条目，和别的条目同款
                  return KazumiGlass.menuItem(
                    context: context,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    closeMenu: false,
                    onTap: () {
                      if (controller.isOpen) {
                        controller.close();
                      } else {
                        controller.open();
                      }
                    },
                    child: SizedBox(
                      height: 48,
                      width: 112,
                      child: Align(
                        alignment: Alignment.center,
                        child: Text(
                          "倍速",
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                    ),
                  );
                },
                menuChildren: <Widget>[
                  ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 216.0),
                      child: SingleChildScrollView(
                        controller: ScrollController(
                          initialScrollOffset: () {
                            final int idx = defaultPlaySpeedList
                                .indexOf(playerController.playback.playerSpeed);
                            return idx <= 1 ? 0.0 : (idx - 1) * 54.0;
                          }(),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            for (final double i in defaultPlaySpeedList)
                            KazumiGlass.menuItem(
                              context: context,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              selected:
                                  i == playerController.playback.playerSpeed,
                              onTap: () async {
                                await widget.setPlaybackSpeed(i);
                              },
                              child: SizedBox(
                                height: 48,
                                width: 112,
                                child: Align(
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${i}x',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              PlayerPanelHoldMenuAnchor(
                acquirePlayerPanelHold: widget.acquirePlayerPanelHold,
                onVisibilityChanged: widget.onMenuVisibilityChanged,
                consumeOutsideTap: true,
                    // 只挪横屏（竖屏保持框架默认位置，之前误改过竖屏）。
                    // 框架的算法是 desiredPosition += alignmentOffset，
                    // 所以 dx 负=往左、dy 负=往上：往上顶回原来的位置，
                    // 再往左挪 30。
                    alignmentOffset: playerLandscapeOffset(
                        context, const Offset(-30, -240)),
                builder: (BuildContext context, MenuController controller,
                    Widget? child) {
                  // 触发条目本身就是普通玻璃条目：和别的条目同一个 widget、
                  // 同一套内边距 —— 文字自然对齐，按下深色范围也完全一致
                  return KazumiGlass.menuItem(
                    context: context,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    closeMenu: false,
                    onTap: () {
                      if (controller.isOpen) {
                        controller.close();
                      } else {
                        controller.open();
                      }
                    },
                    child: SizedBox(
                      height: 48,
                      width: 112,
                      child: Align(
                        alignment: Alignment.center,
                        child: Text(
                          '超分辨率',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                    ),
                  );
                },
                menuChildren: <Widget>[

                  for (final mode in SuperResolutionMode.values)
                    KazumiGlass.menuItem(
                      context: context,
                      // 四周等距：横向 14，纵向由条目高 48 撑开
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      selected:
                          playerController.playback.superResolutionMode ==
                              mode,
                      onTap: () => widget.handleSuperResolutionChange(mode),
                      child: SizedBox(
                        height: 48,
                        width: 112,
                        child: Align(
                          alignment: Alignment.center,
                          child: Text(mode.label),
                        ),
                      ),
                    ),
                ],
              ),
              KazumiGlass.menuItem(
                context: context,
                // 四周等距：横向 14，纵向由条目高 48 撑开
                padding: const EdgeInsets.symmetric(horizontal: 14),
                onTap: () {
                  widget.showSyncPlayPanel();
                },
                child: SizedBox(
                  height: 48,
                  width: 112,
                  child: Align(
                    alignment: Alignment.center,
                    child: Text("一起看"),
                  ),
                ),
              ),
              KazumiGlass.menuItem(
                context: context,
                // 四周等距：横向 14，纵向由条目高 48 撑开
                padding: const EdgeInsets.symmetric(horizontal: 14),
                onTap: () {
                  widget.showDanmakuSwitch();
                },
                child: SizedBox(
                  height: 48,
                  width: 112,
                  child: Align(
                    alignment: Alignment.center,
                    child: Text("弹幕切换"),
                  ),
                ),
              ),
              KazumiGlass.menuItem(
                context: context,
                // 四周等距：横向 14，纵向由条目高 48 撑开
                padding: const EdgeInsets.symmetric(horizontal: 14),
                onTap: () {
                  showDanmakuSettingsSheet(
                    context: context,
                    danmakuController:
                        playerController.danmaku.canvasController,
                    onUpdateDanmakuSpeed: playerController.updateDanmakuSpeed,
                    onTimelineOffsetChanged: playerController
                        .danmaku.clearAndInvalidateScheduledDanmakus,
                  );
                },
                child: SizedBox(
                  height: 48,
                  width: 112,
                  child: Align(
                    alignment: Alignment.center,
                    child: Text("弹幕设置"),
                  ),
                ),
              ),
              KazumiGlass.menuItem(
                context: context,
                // 四周等距：横向 14，纵向由条目高 48 撑开
                padding: const EdgeInsets.symmetric(horizontal: 14),
                onTap: () {
                  widget.showVideoInfo();
                },
                child: SizedBox(
                  height: 48,
                  width: 112,
                  child: Align(
                    alignment: Alignment.center,
                    child: Text("视频详情"),
                  ),
                ),
              ),
              KazumiGlass.menuItem(
                context: context,
                // 四周等距：横向 14，纵向由条目高 48 撑开
                padding: const EdgeInsets.symmetric(horizontal: 14),
                onTap: () {
                  bool needRestart = playerController.playback.playing;
                  playerController.pause();
                  RemotePlay()
                      .castVideo(playerController.videoUrl,
                          videoPageController.currentPlugin.referer)
                      .whenComplete(() {
                    if (mounted && needRestart) {
                      playerController.play();
                    }
                  });
                },
                child: SizedBox(
                  height: 48,
                  width: 112,
                  child: Align(
                    alignment: Alignment.center,
                    child: Text("远程投屏"),
                  ),
                ),
              ),
              KazumiGlass.menuItem(
                context: context,
                // 四周等距：横向 14，纵向由条目高 48 撑开
                padding: const EdgeInsets.symmetric(horizontal: 14),
                onTap: () {
                  playerController.launchExternalPlayer();
                },
                child: SizedBox(
                  height: 48,
                  width: 112,
                  child: Align(
                    alignment: Alignment.center,
                    child: Text("外部播放"),
                  ),
                ),
              ),
              PlayerPanelHoldMenuAnchor(
                acquirePlayerPanelHold: widget.acquirePlayerPanelHold,
                onVisibilityChanged: widget.onMenuVisibilityChanged,
                consumeOutsideTap: true,
                builder: (BuildContext context, MenuController controller,
                    Widget? child) {
                  // 触发条目本身就是普通玻璃条目：和别的条目同一个 widget、
                  // 同一套内边距 —— 文字自然对齐，按下深色范围也完全一致
                  return KazumiGlass.menuItem(
                    context: context,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    closeMenu: false,
                    onTap: () {
                      if (controller.isOpen) {
                        controller.close();
                      } else {
                        controller.open();
                      }
                    },
                    child: SizedBox(
                      height: 48,
                      width: 112,
                      child: Align(
                        alignment: Alignment.center,
                        child: ValueListenableBuilder<int>(
                          valueListenable:
                              TimedShutdownService().remainingSecondsNotifier,
                          builder: (context, remainingSeconds, child) {
                            return Text(
                              remainingSeconds > 0
                                  ? "定时关闭 (${TimedShutdownService().formatRemainingTime()})"
                                  : "定时关闭",
                              style: Theme.of(context).textTheme.labelLarge,
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
                menuChildren: <Widget>[

                  KazumiGlass.menuItem(
                    context: context,
                    // 四周等距：横向 14，纵向由条目高 48 撑开
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    // 点完只关这个二级菜单，一级的「更多」面板继续留着
                    closeLevel: KazumiMenuCloseLevel.current,
                    // 原来这里是 selected: !isActive，一打开「不开启」就是深色
                    // 选中态，像已经点过一样 —— 去掉，默认不带填充
                    onTap: () {
                      TimedShutdownService().cancel();
                    },
                    child: SizedBox(
                      height: 48,
                      width: 112,
                      child: const Align(
                        alignment: Alignment.center,
                        child: Text("不开启"),
                      ),
                    ),
                  ),
                  for (final int minutes in [15, 30, 60])
                    KazumiGlass.menuItem(
                      context: context,
                      // 四周等距：横向 14，纵向由条目高 48 撑开
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      // 点完只关这个二级菜单（和「不开启」一致）
                      closeLevel: KazumiMenuCloseLevel.current,
                      selected: TimedShutdownService().setMinutes == minutes,
                      onTap: () {
                        TimedShutdownService().start(minutes,
                            onExpired: widget.pauseForTimedShutdown);
                        KazumiDialog.showToast(
                            message:
                                '已设置 ${TimedShutdownService().formatMinutesToDisplay(minutes)} 后定时关闭');
                      },
                      child: SizedBox(
                        height: 48,
                        width: 112,
                        child: Align(
                          alignment: Alignment.center,
                          child: Text("$minutes 分钟"),
                        ),
                      ),
                    ),
                  KazumiGlass.menuItem(
                    context: context,
                    // 四周等距：横向 14，纵向由条目高 48 撑开
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    // 点「自定义」只关二级菜单（和上面几项一致）
                    closeLevel: KazumiMenuCloseLevel.current,
                    onTap: () {
                      TimedShutdownService.showCustomTimerDialog(
                        onExpired: widget.pauseForTimedShutdown,
                      );
                    },
                    child: SizedBox(
                      height: 48,
                      width: 112,
                      child: Align(
                        alignment: Alignment.center,
                        child: Text("自定义"),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
