import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:aidx/utils/theme.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final double borderRadius;
  final Color? backgroundColor;
  final double blur;
  final Border? border;
  final BoxShadow? boxShadow;
  
  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.width,
    this.height,
    this.borderRadius = 16.0,
    this.backgroundColor,
    this.blur = 10.0,
    this.border,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          padding: padding ?? const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            color: backgroundColor ?? AppTheme.bgGlassLight,
            borderRadius: BorderRadius.circular(borderRadius),
            border: border ?? Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1.0,
            ),
            boxShadow: boxShadow != null ? [boxShadow!] : [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: -5,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
} 