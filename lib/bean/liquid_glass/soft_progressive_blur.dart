import 'dart:ui';

import 'package:flutter/material.dart';

/// iOS 26 的 `scrollEdgeEffectStyle(.soft)`：从边缘往里推进的渐进模糊。
///
/// Flutter 没有现成的渐进模糊，这里用几条**互不重叠**的带子拼出阶梯式的模糊
/// （重叠的话下一层会把上一层的模糊结果再模糊一遍，越往下越糊，正好反了），
/// 越靠上越糊，再压一层渐变底色保证标题可读，带子的交接处由渐变柔化。
///
/// 用在顶栏这种「内容从下面滚过去」的位置，就是 iOS 26 那种软边观感。
class SoftProgressiveBlur extends StatelessWidget {
  const SoftProgressiveBlur({
    super.key,
    this.height = 104,
    this.maxSigma = 16,
    this.bands = 6,
    this.tint,
  });

  /// 从顶边往下多少逻辑像素内完成过渡。
  final double height;

  /// 顶边最糊的那条带子用的模糊半径。
  final double maxSigma;

  /// 分几条带子。条数越多过渡越平滑，代价是每条都要做一次背景模糊。
  final int bands;

  /// 叠在模糊之上的底色，越靠顶越不透明，用来把标题和按钮压出来。
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (var i = 0; i < bands; i++) _band(i),
          if (tint != null) _tint(),
        ],
      ),
    );
  }

  Widget _band(int index) {
    final double top = height * index / bands;
    // 多留半像素，避免相邻带子之间出现缝
    final double bandHeight = height / bands + 0.5;
    final double t = bands == 1 ? 0 : index / (bands - 1);
    final double sigma = maxSigma * (1 - t) + 1;
    return Positioned(
      top: top,
      left: 0,
      right: 0,
      height: bandHeight,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  Widget _tint() {
    final Color color = tint!;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.55),
              color.withValues(alpha: 0.18),
              color.withValues(alpha: 0),
            ],
            stops: const [0, 0.35, 1],
          ),
        ),
      ),
    );
  }
}
