// app_button.dart: Primary, Secondary, Outline, Text 타입의 버튼들
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

enum AppButtonType { primary, secondary, outline, text }

enum AppButtonSize { large, medium, small }

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonType type;
  final AppButtonSize size;
  final bool isLoading;
  final Widget? icon;
  final double? width;
  final Color? customColor;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type = AppButtonType.primary,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
    this.icon,
    this.width,
    this.customColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onPressed != null && !isLoading;

    Widget button = ElevatedButton(
      onPressed: isEnabled ? onPressed : null,
      style: _getButtonStyle(isEnabled),
      child: isLoading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getLoadingColor(),
                ),
              ),
            )
          : _buildButtonContent(),
    );

    if (width != null) {
      return SizedBox(
        width: width,
        height: _getHeight(),
        child: button,
      );
    }

    return SizedBox(
      width: double.infinity,
      height: _getHeight(),
      child: button,
    );
  }

  Widget _buildButtonContent() {
    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon!,
          const SizedBox(width: AppTheme.spacing8),
          Text(text, style: _getTextStyle()),
        ],
      );
    }

    return Text(text, style: _getTextStyle());
  }

  double _getHeight() {
    switch (size) {
      case AppButtonSize.large:
        return AppTheme.buttonHeightLarge;
      case AppButtonSize.medium:
        return AppTheme.buttonHeightMedium;
      case AppButtonSize.small:
        return AppTheme.buttonHeightSmall;
    }
  }

  ButtonStyle _getButtonStyle(bool isEnabled) {
    final Color backgroundColor = _getBackgroundColor(isEnabled);
    final Color foregroundColor = _getForegroundColor(isEnabled);
    final BorderSide borderSide = _getBorderSide(isEnabled);

    return ElevatedButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      elevation: type == AppButtonType.primary ? 0 : 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        side: borderSide,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: _getHorizontalPadding(),
        vertical: 0,
      ),
    );
  }

  Color _getBackgroundColor(bool isEnabled) {
    if (!isEnabled) {
      return AppTheme.veryLightGray;
    }

    switch (type) {
      case AppButtonType.primary:
        return customColor ?? AppTheme.primaryBlue;
      case AppButtonType.secondary:
        return AppTheme.lightBlue;
      case AppButtonType.outline:
        return Colors.transparent;
      case AppButtonType.text:
        return Colors.transparent;
    }
  }

  Color _getForegroundColor(bool isEnabled) {
    if (!isEnabled) {
      return AppTheme.textDisabled;
    }

    switch (type) {
      case AppButtonType.primary:
        return Colors.white;
      case AppButtonType.secondary:
        return AppTheme.primaryBlue;
      case AppButtonType.outline:
        return customColor ?? AppTheme.primaryBlue;
      case AppButtonType.text:
        return customColor ?? AppTheme.primaryBlue;
    }
  }

  BorderSide _getBorderSide(bool isEnabled) {
    if (type == AppButtonType.outline) {
      return BorderSide(
        color:
            isEnabled
                ? (customColor ?? AppTheme.primaryBlue)
                : AppTheme.lightGray,
        width: 1.5,
      );
    }
    return BorderSide.none;
  }

  TextStyle _getTextStyle() {
    final double fontSize = _getFontSize();
    final FontWeight fontWeight = FontWeight.w600;

    return TextStyle(fontSize: fontSize, fontWeight: fontWeight, height: 1.2);
  }

  double _getFontSize() {
    switch (size) {
      case AppButtonSize.large:
        return AppTheme.h4;
      case AppButtonSize.medium:
        return AppTheme.bodyLarge;
      case AppButtonSize.small:
        return AppTheme.bodyMedium;
    }
  }

  double _getHorizontalPadding() {
    switch (size) {
      case AppButtonSize.large:
        return AppTheme.spacing24;
      case AppButtonSize.medium:
        return AppTheme.spacing20;
      case AppButtonSize.small:
        return AppTheme.spacing16;
    }
  }

  Color _getLoadingColor() {
    switch (type) {
      case AppButtonType.primary:
        return Colors.white;
      case AppButtonType.secondary:
      case AppButtonType.outline:
      case AppButtonType.text:
        return customColor ?? AppTheme.primaryBlue;
    }
  }
}

// 편의성을 위한 특화된 버튼들
class AppPrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Widget? icon;
  final double? width;
  final AppButtonSize size;

  const AppPrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
    this.size = AppButtonSize.medium,
  });

  @override
  Widget build(BuildContext context) {
    return AppButton(
      text: text,
      onPressed: onPressed,
      type: AppButtonType.primary,
      size: size,
      isLoading: isLoading,
      icon: icon,
      width: width,
    );
  }
}

class AppSecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Widget? icon;
  final double? width;
  final AppButtonSize size;

  const AppSecondaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
    this.size = AppButtonSize.medium,
  });

  @override
  Widget build(BuildContext context) {
    return AppButton(
      text: text,
      onPressed: onPressed,
      type: AppButtonType.secondary,
      size: size,
      isLoading: isLoading,
      icon: icon,
      width: width,
    );
  }
}

class AppOutlineButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Widget? icon;
  final double? width;
  final AppButtonSize size;
  final Color? color;

  const AppOutlineButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
    this.size = AppButtonSize.medium,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppButton(
      text: text,
      onPressed: onPressed,
      type: AppButtonType.outline,
      size: size,
      isLoading: isLoading,
      icon: icon,
      width: width,
      customColor: color,
    );
  }
}
