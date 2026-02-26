import 'package:flutter/material.dart';

void showCustomSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  final overlayState = Overlay.of(context);
  late OverlayEntry overlayEntry;

  // Animation controller for smooth entry/exit
  final controller = AnimationController(
    duration: const Duration(milliseconds: 300),
    vsync: Navigator.of(context),
  );

  final offsetAnimation = Tween<Offset>(
    begin: const Offset(0, -1.5),
    end: const Offset(0, 0),
  ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOutBack));

  final opacityAnimation = Tween<double>(
    begin: 0.0,
    end: 1.0,
  ).animate(CurvedAnimation(parent: controller, curve: Curves.easeIn));

  overlayEntry = OverlayEntry(
    builder: (context) {
      return Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: SlideTransition(
            position: offsetAnimation,
            child: FadeTransition(
              opacity: opacityAnimation,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: isError
                        ? Colors.red.shade100
                        : const Color(0xFF4C8077).withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isError
                            ? Colors.red.shade50
                            : const Color(0xFF4C8077).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isError
                            ? Icons.error_outline
                            : Icons.check_circle_outline,
                        color: isError
                            ? Colors.red.shade600
                            : const Color(0xFF4C8077),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        message,
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () async {
                        await controller.reverse();
                        overlayEntry.remove();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  overlayState.insert(overlayEntry);
  controller.forward();

  // Auto dismiss after 3 seconds
  Future.delayed(const Duration(seconds: 3), () async {
    if (overlayEntry.mounted) {
      await controller.reverse();
      overlayEntry.remove();
      controller.dispose();
    }
  });
}
