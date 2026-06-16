import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../theme.dart';

class MotivationScreen extends StatelessWidget {
  final AppTheme t;
  final void Function(String, {Map<String, dynamic>? props}) navigate;
  final Map<String, dynamic> props;

  const MotivationScreen({
    super.key,
    required this.t,
    required this.navigate,
    required this.props,
  });

  @override
  Widget build(BuildContext context) {
    final photoPath = props['photoPath'] as String?;
    
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: t.text),
          onPressed: () => navigate('home'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Text(
                '確定不練？',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: t.text,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'You already got your guitar ready!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: t.textSec,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 20),
              
              if (photoPath != null)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: AspectRatio(
                      aspectRatio: 1, // Reduced height to fit on screen
                      child: photoPath == 'mock_path'
                          ? Container(
                              color: t.surface,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.image, size: 60, color: t.textSec),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Mock Photo (Simulator)',
                                    style: TextStyle(color: t.textSec),
                                  ),
                                ],
                              ),
                            )
                          : kIsWeb
                              ? Image.network(
                                  photoPath,
                                  fit: BoxFit.cover,
                                )
                              : Image.file(
                                  File(photoPath),
                                  fit: BoxFit.cover,
                                ),
                    ),
                  ),
                ),
                
              const SizedBox(height: 20),
              
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: t.border),
                ),
                child: Column(
                  children: [
                    Icon(Icons.format_quote, color: t.accent, size: 40),
                    const SizedBox(height: 10),
                    Text(
                      '"Strike an E chord for me!"',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: t.text,
                        fontSize: 20,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '- Your future self',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: t.textSec,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.accent,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 5,
                    shadowColor: t.accent.withValues(alpha: 0.5),
                  ),
                  onPressed: () {
                    // Navigate to practice screen with the practice props
                    navigate('practicing', props: props);
                  },
                  child: const Text(
                    '練！哪次不練！ (Start Practice)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
