import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Short themed message at the bottom of the screen.
void showMessage(String text) {
  final context = Get.context;
  if (context == null) return;
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 2)));
}
