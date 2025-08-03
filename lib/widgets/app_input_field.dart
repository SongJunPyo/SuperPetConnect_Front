// app_input_field.dart: 이메일, 패스워드 등 특화된 입력 필드들
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_theme.dart';

enum AppInputType { text, email, password, phone, number, multiline }

class AppInputField extends StatefulWidget {
  final String? label;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final String? initialValue;
  final AppInputType type;
  final bool enabled;
  final bool required;
  final int? maxLines;
  final int? maxLength;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function()? onTap;
  final bool readOnly;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;

  const AppInputField({
    super.key,
    this.label,
    this.hintText,
    this.helperText,
    this.errorText,
    this.initialValue,
    this.type = AppInputType.text,
    this.enabled = true,
    this.required = false,
    this.maxLines,
    this.maxLength,
    this.prefixIcon,
    this.suffixIcon,
    this.controller,
    this.validator,
    this.onChanged,
    this.onTap,
    this.readOnly = false,
    this.inputFormatters,
    this.focusNode,
  });

  @override
  State<AppInputField> createState() => _AppInputFieldState();
}

class _AppInputFieldState extends State<AppInputField> {
  bool _obscureText = true;
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    } else {
      _focusNode.removeListener(_onFocusChange);
    }
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) _buildLabel(),
        const SizedBox(height: AppTheme.spacing8),
        _buildTextField(),
        if (widget.helperText != null || widget.errorText != null)
          const SizedBox(height: AppTheme.spacing4),
        if (widget.helperText != null && widget.errorText == null)
          _buildHelperText(),
        if (widget.errorText != null) _buildErrorText(),
      ],
    );
  }

  Widget _buildLabel() {
    return RichText(
      text: TextSpan(
        text: widget.label,
        style: AppTheme.bodyMediumStyle.copyWith(fontWeight: FontWeight.w600),
        children: [
          if (widget.required)
            const TextSpan(text: ' *', style: TextStyle(color: AppTheme.error)),
        ],
      ),
    );
  }

  Widget _buildTextField() {
    return Container(
      height:
          widget.type == AppInputType.multiline ? null : AppTheme.inputHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        boxShadow: _isFocused ? AppTheme.shadowSmall : null,
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        initialValue: widget.controller == null ? widget.initialValue : null,
        enabled: widget.enabled,
        readOnly: widget.readOnly,
        obscureText:
            widget.type == AppInputType.password ? _obscureText : false,
        keyboardType: _getKeyboardType(),
        textInputAction:
            widget.type == AppInputType.multiline
                ? TextInputAction.newline
                : TextInputAction.done,
        maxLines:
            widget.type == AppInputType.multiline ? (widget.maxLines ?? 3) : 1,
        maxLength: widget.maxLength,
        inputFormatters: widget.inputFormatters,
        validator: widget.validator,
        onChanged: widget.onChanged,
        onTap: widget.onTap,
        style: AppTheme.bodyLargeStyle,
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: AppTheme.bodyLargeStyle.copyWith(
            color: AppTheme.textTertiary,
          ),
          prefixIcon: widget.prefixIcon,
          suffixIcon: _buildSuffixIcon(),
          filled: true,
          fillColor:
              widget.enabled
                  ? (_isFocused
                      ? AppTheme.veryLightBlue
                      : AppTheme.veryLightGray)
                  : AppTheme.lightGray.withOpacity(0.3),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            borderSide: BorderSide.none,
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            borderSide: const BorderSide(color: AppTheme.error, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            borderSide: const BorderSide(color: AppTheme.error, width: 2),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing16,
            vertical: AppTheme.spacing16,
          ),
          counterText: '',
          errorStyle: const TextStyle(height: 0.01, color: Colors.transparent),
        ),
      ),
    );
  }

  Widget? _buildSuffixIcon() {
    if (widget.type == AppInputType.password) {
      return IconButton(
        icon: Icon(
          _obscureText
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color: AppTheme.textTertiary,
        ),
        onPressed: () {
          setState(() {
            _obscureText = !_obscureText;
          });
        },
      );
    }
    return widget.suffixIcon;
  }

  Widget _buildHelperText() {
    return Padding(
      padding: const EdgeInsets.only(left: AppTheme.spacing4),
      child: Text(
        widget.helperText!,
        style: AppTheme.bodySmallStyle.copyWith(color: AppTheme.textTertiary),
      ),
    );
  }

  Widget _buildErrorText() {
    return Padding(
      padding: const EdgeInsets.only(left: AppTheme.spacing4),
      child: Text(
        widget.errorText!,
        style: AppTheme.bodySmallStyle.copyWith(color: AppTheme.error),
      ),
    );
  }

  TextInputType _getKeyboardType() {
    switch (widget.type) {
      case AppInputType.email:
        return TextInputType.emailAddress;
      case AppInputType.phone:
        return TextInputType.phone;
      case AppInputType.number:
        return TextInputType.number;
      case AppInputType.multiline:
        return TextInputType.multiline;
      case AppInputType.password:
      case AppInputType.text:
      default:
        return TextInputType.text;
    }
  }
}

// 편의성을 위한 특화된 입력 필드들
class AppEmailField extends StatelessWidget {
  final String? label;
  final String? hintText;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final bool required;

  const AppEmailField({
    super.key,
    this.label,
    this.hintText,
    this.controller,
    this.validator,
    this.onChanged,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppInputField(
      label: label ?? '이메일',
      hintText: hintText ?? '이메일 주소를 입력하세요',
      type: AppInputType.email,
      controller: controller,
      validator: validator ?? _defaultEmailValidator,
      onChanged: onChanged,
      required: required,
      prefixIcon: const Icon(
        Icons.email_outlined,
        color: AppTheme.textTertiary,
      ),
    );
  }

  String? _defaultEmailValidator(String? value) {
    if (value == null || value.isEmpty) {
      return '이메일을 입력해주세요';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return '올바른 이메일 형식을 입력해주세요';
    }
    return null;
  }
}

class AppPasswordField extends StatelessWidget {
  final String? label;
  final String? hintText;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final bool required;

  const AppPasswordField({
    super.key,
    this.label,
    this.hintText,
    this.controller,
    this.validator,
    this.onChanged,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppInputField(
      label: label ?? '비밀번호',
      hintText: hintText ?? '비밀번호를 입력하세요',
      type: AppInputType.password,
      controller: controller,
      validator: validator,
      onChanged: onChanged,
      required: required,
      prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.textTertiary),
    );
  }
}
