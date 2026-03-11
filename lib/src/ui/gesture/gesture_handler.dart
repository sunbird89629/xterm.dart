import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:xterm/core.dart';
import 'package:xterm/src/core/mouse/button.dart';
import 'package:xterm/src/core/mouse/button_state.dart';
import 'package:xterm/src/terminal_view.dart';
import 'package:xterm/src/ui/controller.dart';
import 'package:xterm/src/ui/gesture/gesture_detector.dart';
import 'package:xterm/src/ui/pointer_input.dart';
import 'package:xterm/src/ui/render.dart';
import 'package:xterm/src/ui/selection_mode.dart';

class TerminalGestureHandler extends StatefulWidget {
  const TerminalGestureHandler({
    super.key,
    required this.terminalView,
    required this.terminalController,
    this.child,
    this.onTapUp,
    this.onSingleTapUp,
    this.onTapDown,
    this.onSecondaryTapDown,
    this.onSecondaryTapUp,
    this.onTertiaryTapDown,
    this.onTertiaryTapUp,
    this.readOnly = false,
    this.onDragEnd,
    this.onDragCancel,
  });

  final TerminalViewState terminalView;

  final TerminalController terminalController;

  final Widget? child;

  final GestureTapUpCallback? onTapUp;

  final GestureTapUpCallback? onSingleTapUp;

  final GestureTapDownCallback? onTapDown;

  final GestureTapDownCallback? onSecondaryTapDown;

  final GestureTapUpCallback? onSecondaryTapUp;

  final GestureTapDownCallback? onTertiaryTapDown;

  final GestureTapUpCallback? onTertiaryTapUp;

  final GestureDragEndCallback? onDragEnd;

  final GestureDragCancelCallback? onDragCancel;

  final bool readOnly;

  @override
  State<TerminalGestureHandler> createState() => _TerminalGestureHandlerState();
}

class _TerminalGestureHandlerState extends State<TerminalGestureHandler> {
  TerminalViewState get terminalView => widget.terminalView;

  RenderTerminal get renderTerminal => terminalView.renderTerminal;

  DragStartDetails? _lastDragStartDetails;
  CellOffset? _dragStartCellOffset;
  DragUpdateDetails? _lastDragUpdateDetails;
  Timer? _autoScrollTimer;

  LongPressStartDetails? _lastLongPressStartDetails;

  @override
  Widget build(BuildContext context) {
    return TerminalGestureDetector(
      child: widget.child,
      onTapUp: widget.onTapUp,
      onSingleTapUp: onSingleTapUp,
      onTapDown: onTapDown,
      onSecondaryTapDown: onSecondaryTapDown,
      onSecondaryTapUp: onSecondaryTapUp,
      onTertiaryTapDown: onSecondaryTapDown,
      onTertiaryTapUp: onSecondaryTapUp,
      onLongPressStart: onLongPressStart,
      onLongPressMoveUpdate: onLongPressMoveUpdate,
      // onLongPressUp: onLongPressUp,
      onDragStart: widget.readOnly ? null : onDragStart,
      onDragUpdate: widget.readOnly ? null : onDragUpdate,
      onDragEnd: widget.readOnly ? null : onDragEnd,
      onDragCancel: widget.readOnly ? null : onDragCancel,
      onDoubleTapDown: onDoubleTapDown,
    );
  }

  bool get _shouldSendTapEvent =>
      !widget.readOnly &&
      widget.terminalController.shouldSendPointerInput(PointerInput.tap);

  void _tapDown(
    GestureTapDownCallback? callback,
    TapDownDetails details,
    TerminalMouseButton button, {
    bool forceCallback = false,
  }) {
    // Check if the terminal should and can handle the tap down event.
    var handled = false;
    if (_shouldSendTapEvent) {
      handled = renderTerminal.mouseEvent(
        button,
        TerminalMouseButtonState.down,
        details.localPosition,
      );
    }
    // If the event was not handled by the terminal, use the supplied callback.
    if (!handled || forceCallback) {
      callback?.call(details);
    }
  }

  void _tapUp(
    GestureTapUpCallback? callback,
    TapUpDetails details,
    TerminalMouseButton button, {
    bool forceCallback = false,
  }) {
    // Check if the terminal should and can handle the tap up event.
    var handled = false;
    if (_shouldSendTapEvent) {
      handled = renderTerminal.mouseEvent(
        button,
        TerminalMouseButtonState.up,
        details.localPosition,
      );
    }
    // If the event was not handled by the terminal, use the supplied callback.
    if (!handled || forceCallback) {
      callback?.call(details);
    }
  }

  void onTapDown(TapDownDetails details) {
    // onTapDown is special, as it will always call the supplied callback.
    // The TerminalView depends on it to bring the terminal into focus.
    _tapDown(
      widget.onTapDown,
      details,
      TerminalMouseButton.left,
      forceCallback: true,
    );
  }

  void onSingleTapUp(TapUpDetails details) {
    _tapUp(widget.onSingleTapUp, details, TerminalMouseButton.left);
  }

  void onSecondaryTapDown(TapDownDetails details) {
    _tapDown(widget.onSecondaryTapDown, details, TerminalMouseButton.right);
  }

  void onSecondaryTapUp(TapUpDetails details) {
    _tapUp(widget.onSecondaryTapUp, details, TerminalMouseButton.right);
  }

  void onTertiaryTapDown(TapDownDetails details) {
    _tapDown(widget.onTertiaryTapDown, details, TerminalMouseButton.middle);
  }

  void onTertiaryTapUp(TapUpDetails details) {
    _tapUp(widget.onTertiaryTapUp, details, TerminalMouseButton.right);
  }

  void onDoubleTapDown(TapDownDetails details) {
    renderTerminal.selectWord(details.localPosition);
  }

  void onLongPressStart(LongPressStartDetails details) {
    _lastLongPressStartDetails = details;
    renderTerminal.selectWord(details.localPosition);
  }

  void onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    renderTerminal.selectWord(
      _lastLongPressStartDetails!.localPosition,
      details.localPosition,
    );
  }

  // void onLongPressUp() {}

  void onDragStart(DragStartDetails details) {
    _lastDragStartDetails = details;
    _dragStartCellOffset = renderTerminal.getCellOffset(details.localPosition);

    final isBlockSelection =
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isAltPressed;

    widget.terminalController.setSelectionMode(
      isBlockSelection ? SelectionMode.block : SelectionMode.line,
    );
  }

  void onDragUpdate(DragUpdateDetails details) {
    _lastDragUpdateDetails = details;
    _updateSelectionForDrag(details.localPosition);
    _checkAutoScroll(details.localPosition);
  }

  void _updateSelectionForDrag(Offset localPosition) {
    if (_dragStartCellOffset == null) return;

    // Use the absolute logical CellOffset cached at the start of the drag
    // rather than the physical coordinates, so it stays pinned while scrolling.
    renderTerminal.selectCharactersFromOffset(
      _dragStartCellOffset!,
      localPosition,
    );
  }

  void _checkAutoScroll(Offset localPosition) {
    if (!renderTerminal.hasSize) return;

    final scrollController = widget.terminalView.scrollController;
    if (!scrollController.hasClients) return;

    final rect = Offset.zero & renderTerminal.size;
    const scrollZoneHeight = 30.0;
    const maxScrollSpeed = 20.0;

    double scrollDelta = 0;

    if (localPosition.dy < rect.top + scrollZoneHeight) {
      // Scroll up
      final distance = rect.top + scrollZoneHeight - localPosition.dy;
      final speedFactor = (distance / scrollZoneHeight).clamp(0.0, 1.0);
      scrollDelta = -maxScrollSpeed * speedFactor;
    } else if (localPosition.dy > rect.bottom - scrollZoneHeight) {
      // Scroll down
      final distance = localPosition.dy - (rect.bottom - scrollZoneHeight);
      final speedFactor = (distance / scrollZoneHeight).clamp(0.0, 1.0);
      scrollDelta = maxScrollSpeed * speedFactor;
    }

    if (scrollDelta != 0) {
      if (_autoScrollTimer == null) {
        _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 16), (
          timer,
        ) {
          if (!scrollController.hasClients) {
            _stopAutoScroll();
            return;
          }
          final currentScroll = scrollController.offset;
          final targetScroll = (currentScroll + scrollDelta).clamp(
            0.0,
            scrollController.position.maxScrollExtent,
          );

          if (currentScroll == targetScroll) return;

          scrollController.jumpTo(targetScroll);

          if (_lastDragUpdateDetails != null) {
            _updateSelectionForDrag(_lastDragUpdateDetails!.localPosition);
          }
        });
      }
    } else {
      _stopAutoScroll();
    }
  }

  void onDragEnd(DragEndDetails details) {
    _stopAutoScroll();
    widget.onDragEnd?.call(details);
  }

  void onDragCancel() {
    _stopAutoScroll();
    widget.onDragCancel?.call();
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }
}
