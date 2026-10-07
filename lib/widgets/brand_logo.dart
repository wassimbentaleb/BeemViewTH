import 'package:flutter/material.dart';

import '../core/app_theme.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.large = false});

  final bool large;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/beemview-logo.png',
            width: large ? 68 : 28,
            height: large ? 68 : 28,
            excludeFromSemantics: true,
          ),
          SizedBox(width: large ? 14 : 8),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Beem View ',
                  style: TextStyle(color: AppColors.of(context).primary),
                ),
                TextSpan(
                  text: '360',
                  style: TextStyle(color: AppColors.of(context).amber),
                ),
              ],
            ),
            style: TextStyle(
              fontSize: large ? 28 : 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
        ],
      ),
    );
  }
}
