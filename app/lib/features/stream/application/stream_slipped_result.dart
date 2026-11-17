// Typed outcome and failures for slipped-task triage actions.

typedef StreamSlippedUndo = Future<void> Function();

enum StreamSlippedFailure { missingTask, repository }

class StreamSlippedException implements Exception {
  const StreamSlippedException(
    this.failure, {
    this.taskId,
    this.cause,
    this.stackTrace,
  });

  const StreamSlippedException.missingTask(String taskId)
    : this(StreamSlippedFailure.missingTask, taskId: taskId);

  const StreamSlippedException.repository({
    String? taskId,
    Object? cause,
    StackTrace? stackTrace,
  }) : this(
         StreamSlippedFailure.repository,
         taskId: taskId,
         cause: cause,
         stackTrace: stackTrace,
       );

  final StreamSlippedFailure failure;
  final String? taskId;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() => 'StreamSlippedException(${failure.name})';
}

class StreamSlippedResult {
  const StreamSlippedResult({required this.taskId, this.undo});

  final String taskId;
  final StreamSlippedUndo? undo;
}
