part of 'day_mark_gestures.dart';

extension _DayMarkGestureMove on _DayMarkGesturesState {
  void _onLongPressStart(LongPressStartDetails d, Size size) {
    final x = d.localPosition.dx;
    if (_inEdge(x, size)) {
      _moveMarkId = null;
      _creating = false;
      return;
    }
    final id = _hitMark(x, d.localPosition.dy, size);
    if (id != null) {
      _moveMarkId = id;
      final mark = _moveMarkFor(id);
      final pressTime = widget.viewport.pxToTime(d.localPosition.dy);
      _moveMark = mark;
      _originalStartMs = mark?.startMs ?? pressTime;
      _grabOffsetMs = pressTime - _originalStartMs;
      _pressY = d.localPosition.dy;
      _movedBeyond = false;
      _lastSnappedMs = -1;
    } else {
      _moveMarkId = null;
      _creating = true;
      _createStartY = d.localPosition.dy;
      _createCurrentY = d.localPosition.dy;
    }
  }

  void _onLongPressMove(LongPressMoveUpdateDetails d, Size size) {
    if (_moveMarkId != null) {
      if ((d.localPosition.dy - _pressY).abs() >= widget.moveThresholdDp) {
        _movedBeyond = true;
      }
      final pressTime = widget.viewport.pxToTime(d.localPosition.dy);
      final newStart = _snap(pressTime - _grabOffsetMs);
      if (newStart != _lastSnappedMs) {
        _lastSnappedMs = newStart;
        if (_movedBeyond) AppFeedback.selection();
      }
      if (_movedBeyond || newStart != _originalStartMs) {
        widget.onMoveMark?.call(_moveMarkId!, newStart);
        final formatter = widget.timeFormatter ?? widget.formatTime;
        widget.dragPreview?.value = DragPreviewData(
          id: _moveMarkId!,
          localPosition: d.localPosition,
          label: _moveMark?.title ?? '',
          timeLabel: formatter != null
              ? formatter(newStart)
              : _formatEpochMs(newStart),
        );
      }
    } else if (_creating) {
      _createCurrentY = d.localPosition.dy;
    }
  }

  void _onLongPressEnd(LongPressEndDetails d) {
    if (_moveMarkId != null) {
      final id = _moveMarkId!;
      if (_movedBeyond || _lastSnappedMs != _originalStartMs) {
        final snapped = _lastSnappedMs >= 0 ? _lastSnappedMs : _originalStartMs;
        if (snapped != _originalStartMs) {
          widget.onMoveMarkEnd?.call(id, snapped);
        }
      }
      widget.dragPreview?.value = null;
      _moveMarkId = null;
      _moveMark = null;
      _lastSnappedMs = -1;
    } else if (_creating) {
      _handleCreateEnd();
    }
  }
}

String _formatEpochMs(int ms) {
  final dt = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}
