import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:squad_tracker_flutter/l10n/gen/app_localizations.dart';

class BarcodeScannerSimple extends StatefulWidget {
  const BarcodeScannerSimple({super.key});

  @override
  State<BarcodeScannerSimple> createState() => _BarcodeScannerSimpleState();
}

class _BarcodeScannerSimpleState extends State<BarcodeScannerSimple>
    with WidgetsBindingObserver {
  final controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    detectionTimeoutMs: 500,
    returnImage: false, // set to false unless you truly need images
    formats: const [BarcodeFormat.qrCode],
    autoStart: false,
    facing: CameraFacing.back,
  );

  Barcode? _barcode;
  bool _isClosing = false;
  bool _isStarted = false;
  DateTime? _lastInvalidFeedbackAt;

  bool _isTorchOn = false;

  Future<void> _onDetect(BarcodeCapture barcodes) async {
    if (mounted) {
      setState(() {
        _barcode = barcodes.barcodes.firstOrNull;
      });

      // Validate and pop the value when it looks like a squad code
      if (_barcode != null && _barcode!.displayValue != null) {
        final raw = _barcode!.displayValue!.trim();
        // Remove possible NULs and extract a 6-char token if embedded
        final sanitized = raw.replaceAll('\u0000', '');
        final match = RegExp(r'([A-Za-z0-9]{6})').firstMatch(sanitized);
        final token = (match != null) ? match.group(1)! : sanitized;
        final candidate = token.toLowerCase();
        final valid = RegExp(r'^[a-z0-9]{6}$').hasMatch(candidate);

        if (!valid) {
          // Light feedback for invalid reads, but throttle to avoid spamming
          final now = DateTime.now();
          if (_lastInvalidFeedbackAt == null ||
              now.difference(_lastInvalidFeedbackAt!).inMilliseconds > 750) {
            _lastInvalidFeedbackAt = now;
            HapticFeedback.mediumImpact();
            if (mounted) {
              final l10n = AppLocalizations.of(context)!;
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.invalidSquadCode)),
              );
            }
          }
          return;
        }

        if (_isClosing) return;
        _isClosing = true;
        HapticFeedback.heavyImpact();
        // Stop camera before leaving to release buffers cleanly
        try {
          await controller.stop();
        } catch (_) {}
        _isStarted = false;
        if (mounted) {
          Navigator.pop(context, candidate);
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Start camera after first frame to avoid init-time buffer pressure
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _safeStart();
    });
  }

  void _safeStart() {
    if (_isStarted) return;
    _isStarted = true;
    unawaited(controller.start());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!controller.value.hasCameraPermission) {
      return;
    }

    switch (state) {
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        if (_isStarted) {
          unawaited(controller.stop());
          _isStarted = false;
        }
        return;
      case AppLifecycleState.resumed:
        _safeStart();
        break;
      case AppLifecycleState.inactive:
        if (_isStarted) {
          unawaited(controller.stop());
          _isStarted = false;
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.scanSquadQrTitle),
        actions: [
          IconButton(
            tooltip: _isTorchOn
                ? AppLocalizations.of(context)!.stop
                : AppLocalizations.of(context)!.scan,
            onPressed: () async {
              try {
                await controller.toggleTorch();
                if (mounted) {
                  setState(() {
                    _isTorchOn = !_isTorchOn;
                  });
                }
              } catch (_) {
                // ignore
              }
            },
            icon: Icon(_isTorchOn ? Icons.flash_on : Icons.flash_off),
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final cutOut = math.min(width, height) * 0.70;
          final left = (width - cutOut) / 2;
          final top = (height - cutOut) / 2;
          final overlayRect = Rect.fromLTWH(left, top, cutOut, cutOut);

          return Stack(
            fit: StackFit.expand,
            children: [
              // Camera preview
              MobileScanner(
                controller: controller,
                onDetect: _onDetect,
                fit: BoxFit.cover,
                errorBuilder: (context, error) {
                  return _ScannerError(onRetry: _safeStart);
                },
              ),

              // Dark overlay with transparent square cut-out and corner guides
              IgnorePointer(
                child: CustomPaint(
                  painter: _ScannerOverlayPainter(rect: overlayRect),
                  size: Size(width, height),
                ),
              ),

              // Center hint text
              Positioned(
                bottom: height * 0.22,
                left: 24,
                right: 24,
                child: const _InstructionChip(),
              ),

              // Bottom controls
              Positioned(
                bottom: 24 + MediaQuery.of(context).padding.bottom,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _RoundButton(
                      icon: Icons.close,
                      label: AppLocalizations.of(context)!.cancel,
                      onTap: () async {
                        if (_isStarted) {
                          try {
                            await controller.stop();
                          } catch (_) {}
                          _isStarted = false;
                        }
                        if (mounted) Navigator.pop(context);
                      },
                    ),
                    _RoundButton(
                      icon: Icons.cameraswitch,
                      label: 'Switch',
                      onTap: () => controller.switchCamera(),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Explicitly stop before dispose to avoid buffer leaks
    if (_isStarted) {
      unawaited(controller.stop());
      _isStarted = false;
    }
    controller.dispose();
    super.dispose();
  }
}

class _ScannerError extends StatelessWidget {
  final VoidCallback onRetry;

  const _ScannerError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.white70, size: 48),
          const SizedBox(height: 12),
          const Text(
            'Camera unavailable or permission denied',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          )
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _RoundButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.black54,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Icon(icon, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}

class _InstructionChip extends StatelessWidget {
  const _InstructionChip();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Text(
          'Align the QR inside the frame',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final Rect rect;

  _ScannerOverlayPainter({required this.rect});

  @override
  void paint(Canvas canvas, Size size) {
    // Darken whole screen
    final overlayPaint = Paint()..color = Colors.black54;
    canvas.drawRect(Offset.zero & size, overlayPaint);

    // Clear the scan window with even-odd path
    final clearPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)));
    canvas.drawPath(clearPath, Paint()..blendMode = BlendMode.clear);

    // Draw corner guides
    final cornerPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    const double cornerLen = 28;
    final r =
        RRect.fromRectAndRadius(rect, const Radius.circular(16)).outerRect;

    // Top-left
    canvas.drawLine(
        r.topLeft, r.topLeft + const Offset(cornerLen, 0), cornerPaint);
    canvas.drawLine(
        r.topLeft, r.topLeft + const Offset(0, cornerLen), cornerPaint);

    // Top-right
    canvas.drawLine(
        r.topRight, r.topRight + const Offset(-cornerLen, 0), cornerPaint);
    canvas.drawLine(
        r.topRight, r.topRight + const Offset(0, cornerLen), cornerPaint);

    // Bottom-left
    canvas.drawLine(
        r.bottomLeft, r.bottomLeft + const Offset(cornerLen, 0), cornerPaint);
    canvas.drawLine(
        r.bottomLeft, r.bottomLeft + const Offset(0, -cornerLen), cornerPaint);

    // Bottom-right
    canvas.drawLine(r.bottomRight, r.bottomRight + const Offset(-cornerLen, 0),
        cornerPaint);
    canvas.drawLine(r.bottomRight, r.bottomRight + const Offset(0, -cornerLen),
        cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
