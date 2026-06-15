import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../theme.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';

class CheckInScreen extends StatefulWidget {
  final AppTheme t;
  final void Function(String, {Map<String, dynamic>? props}) navigate;
  final Map<String, dynamic> props;

  const CheckInScreen({
    super.key,
    required this.t,
    required this.navigate,
    required this.props,
  });

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isTakingPicture = false;
  bool _isMockCamera = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    bool hasPermission = false;
    
    if (kIsWeb) {
      // On Web, availableCameras() automatically requests permission from the browser.
      hasPermission = true; 
    } else {
      final status = await Permission.camera.request();
      hasPermission = status.isGranted;
    }

    if (hasPermission) {
      try {
        _cameras = await availableCameras();
        if (_cameras != null && _cameras!.isNotEmpty) {
          // Use front camera if available, otherwise back
          final camera = _cameras!.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
            orElse: () => _cameras!.first,
          );
          _cameraController = CameraController(
            camera,
            ResolutionPreset.high,
            enableAudio: false,
          );
          await _cameraController!.initialize();
          if (mounted) {
            setState(() {
              _isCameraInitialized = true;
            });
          }
        } else {
          // Fallback for iOS Simulator which has no camera
          print("No cameras available. Using mock camera mode.");
          if (mounted) {
            setState(() {
              _isCameraInitialized = true;
              _isMockCamera = true;
            });
          }
        }
      } catch (e) {
        print("Error initializing camera: \$e");
        // Fallback on error (e.g. simulator)
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
            _isMockCamera = true;
          });
        }
      }
    } else {
      print("Camera permission denied");
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    print("Take picture button tapped!");
    if (_isTakingPicture) {
      print("Already taking picture, returning.");
      return;
    }
    
    if (_isMockCamera) {
      setState(() => _isTakingPicture = true);
      await Future.delayed(const Duration(seconds: 1)); // Simulate delay
      if (mounted) {
        widget.navigate('motivation', props: {
          ...widget.props,
          'photoPath': 'mock_path',
        });
      }
      return;
    }

    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      print("Camera controller is null or not initialized!");
      return;
    }

    print("Setting _isTakingPicture to true...");

    setState(() {
      _isTakingPicture = true;
    });

    try {
      final XFile picture = await _cameraController!.takePicture();
      // Pass the picture path to the next screen
      if (mounted) {
        widget.navigate('motivation', props: {
          ...widget.props,
          'photoPath': picture.path,
        });
      }
    } catch (e) {
      print("Error taking picture: \$e");
      setState(() {
        _isTakingPicture = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.t.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: widget.t.text),
          onPressed: () => widget.navigate('home'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                'Time to practice!\nTake a picture with your guitar 🎸',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: widget.t.text,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 40),
            if (_isCameraInitialized)
              if (_isMockCamera)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  height: 400,
                  decoration: BoxDecoration(
                    color: widget.t.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: widget.t.border),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        Icon(Icons.camera_alt, size: 64, color: widget.t.text.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        Text(
                          'Mock Camera (Simulator)',
                          style: TextStyle(color: widget.t.text.withValues(alpha: 0.5)),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_cameraController != null)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: widget.t.accent.withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: AspectRatio(
                      aspectRatio: 3 / 4,
                      child: CameraPreview(_cameraController!),
                    ),
                  ),
                )
              else
                const SizedBox()
            else
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                height: 400,
                decoration: BoxDecoration(
                  color: widget.t.surface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: CircularProgressIndicator(color: widget.t.accent),
                ),
              ),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.only(bottom: 40.0),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _takePicture,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.transparent,
                    border: Border.all(
                      color: widget.t.accent,
                      width: 4,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isTakingPicture ? widget.t.accentMid : widget.t.accent,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      )),
    );
  }
}
