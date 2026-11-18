part of '../notes_screen.dart';

// Error state widget.

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppErrorState(title: message, onRetry: onRetry);
  }
}
