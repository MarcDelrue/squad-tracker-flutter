import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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

  Widget _buildBarcode(Barcode? value) {
    if (value == null) {
      return const Text(
        'Scan something!',
        overflow: TextOverflow.fade,
        style: TextStyle(color: Colors.white),
      );
    }

    return Text(
      value.displayValue ?? 'No display value.',
      overflow: TextOverflow.fade,
      style: const TextStyle(color: Colors.white),
    );
  }

  Future<void> _onDetect(BarcodeCapture barcodes) async {
    if (mounted) {
      setState(() {
        _barcode = barcodes.barcodes.firstOrNull;
      });

      // Check if a barcode value is available and pop the value to the previous screen
      if (_barcode != null && _barcode!.displayValue != null) {
        if (_isClosing) return;
        _isClosing = true;
        // Stop camera before leaving to release buffers cleanly
        try {
          await controller.stop();
        } catch (_) {}
        _isStarted = false;
        if (mounted) {
          Navigator.pop(context, _barcode!.displayValue);
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
      appBar: AppBar(title: const Text('Barcode Scanner')),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              return const Center(
                child: Text('Something went wrong!'),
              );
            },
            fit: BoxFit.contain,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              alignment: Alignment.bottomCenter,
              height: 100,
              color: Colors.black,
              child: Center(child: _buildBarcode(_barcode)),
            ),
          ),
        ],
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
