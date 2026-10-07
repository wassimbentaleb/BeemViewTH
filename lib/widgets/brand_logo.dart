import 'package:flutter/material.dart';

import '../core/app_theme.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.large = false, this.login = false});

  final bool large;
  final bool login;

  @override
  Widget build(BuildContext context) {
    final mark = Image.asset(
      'assets/images/beemview-logo.png',
      width: login ? 40 : (large ? 52 : 28),
      height: login ? 40 : (large ? 52 : 28),
      excludeFromSemantics: true,
    );
    final wordmark = Text.rich(
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
        fontSize: login ? 20 : (large ? 24 : 16),
        fontWeight: login ? FontWeight.w700 : FontWeight.w800,
        letterSpacing: login ? -0.4 : -0.6,
        height: login ? 1.2 : null,
      ),
    );
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: large
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                mark,
                SizedBox(height: login ? 10 : 12),
                wordmark,
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [mark, const SizedBox(width: 8), wordmark],
            ),
    );
  }
}
