import 'package:flutter/material.dart';
import '../../config/constants.dart';

class LogoWidget extends StatelessWidget {
  final double? width;
  final double? height;
  final bool showText;

  const LogoWidget({
    super.key,
    this.width,
    this.height,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Hospital Logo Image
        Container(
          width: width ?? 200,
          height: height ?? 80,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Image.asset(
            AppConstants.logoPath,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              // Fallback if logo doesn't load
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.local_hospital,
                    size: 40,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Graphic Era Hospital',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
