import 'package:flutter/material.dart';

void showCustomSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars(); // Avoid stacking

  messenger.showSnackBar(
    SnackBar(
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isError ? Colors.red.shade100 : Colors.teal.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? Colors.red.shade700 : Colors.teal.shade700,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.grey.shade900,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isError ? Colors.red.shade100 : Colors.teal.shade100,
          width: 1.5,
        ),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      elevation: 6,
      duration: const Duration(milliseconds: 2500),
      dismissDirection: DismissDirection.horizontal,
      action: SnackBarAction(
        label: '✕',
        textColor: Colors.grey.shade500,
        onPressed: () {
          messenger.hideCurrentSnackBar();
        },
      ),
    ),
  );
}
