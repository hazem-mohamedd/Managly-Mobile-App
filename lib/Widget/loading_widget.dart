import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class LoadingWidget extends StatelessWidget {
  const LoadingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 250, // 👈 حجم كبير
        height: 250,
        child: Lottie.asset(
          'assets/Loading Dots Blue.json',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}