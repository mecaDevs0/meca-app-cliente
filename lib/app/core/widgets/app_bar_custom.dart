import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../app_colors.dart';
import '../app_images.dart';

class AppBarCustom extends StatelessWidget implements PreferredSizeWidget {
  const AppBarCustom({
    super.key,
    this.title,
    this.leading,
    this.onLeadingIconTap,
    this.leadingText,
    this.actions,
    this.titleColor,
    this.backgroundColor,
    this.iconColor,
  });

  final String? title;
  final Widget? leading;
  final VoidCallback? onLeadingIconTap;
  final String? leadingText;
  final List<Widget>? actions;
  final Color? titleColor;
  final Color? backgroundColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      centerTitle: false,
      elevation: 0,
      backgroundColor: backgroundColor ?? Colors.white,
      leading: leading ??
          GestureDetector(
            onTap: onLeadingIconTap ?? () => Navigator.of(context).pop(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 20),
                SvgPicture.asset(
                  AppImages.icArrowBack,
                  alignment: Alignment.center,
                  colorFilter: ColorFilter.mode(
                    iconColor ?? AppColors.softBlackColor,
                    BlendMode.srcIn,
                  ),
                ),
              ],
            ),
          ),
      title: Text(
        title ?? '',
        style: TextStyle(
          color: titleColor ?? AppColors.softBlackColor,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
      actions: actions
          ?.map(
            (action) => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: action,
            ),
          )
          .toList(),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
