import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

class VoiceSearchSheet extends StatefulWidget {
  const VoiceSearchSheet({super.key});

  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const VoiceSearchSheet(),
    );
  }

  @override
  State<VoiceSearchSheet> createState() => _VoiceSearchSheetState();
}

class _VoiceSearchSheetState extends State<VoiceSearchSheet>
    with SingleTickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  String _text = 'Listening...';
  String _statusMessage = 'Try saying "Shoes" or "T-shirt"';
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    // Automatically initialize speech-to-text
    _initSpeech();
  }

  @override
  void dispose() {
    _speech.stop();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      bool available = await _speech.initialize(
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
      );

      if (mounted) {
        setState(() {
          _isInitialized = available;
          if (!available) {
            _text = 'Speech recognition not available';
            _statusMessage = 'Please check system settings or permissions.';
          }
        });

        if (available) {
          _startListening();
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isInitialized = false;
          _text = 'Initialization error';
          _statusMessage = 'Could not start voice search. Please try again.';
        });
      }
    }
  }

  void _onSpeechStatus(String status) {
    if (!mounted) return;
    debugPrint('🔔 Speech Status: $status');
    if (status == 'listening') {
      setState(() {
        _isListening = true;
      });
      _pulseController.repeat();
    } else {
      setState(() {
        _isListening = false;
      });
      _pulseController.stop();
    }
  }

  void _onSpeechError(SpeechRecognitionError error) {
    if (!mounted) return;
    debugPrint('🔔 Speech Error: ${error.errorMsg}');
    setState(() {
      _isListening = false;
      _pulseController.stop();
      
      final msg = error.errorMsg.toLowerCase();
      if (msg.contains('error_speech_timeout') || msg.contains('error_no_match')) {
        _statusMessage = 'Please try again. Tap the mic and speak clearly.';
      } else if (msg.contains('error_permission')) {
        _text = 'Permission denied';
        _statusMessage = 'Microphone permission is required for voice search.';
      } else if (msg.contains('error_busy')) {
        _statusMessage = 'Voice search is busy. Please try again.';
      } else {
        _statusMessage = 'Please try again. Tap the mic to restart.';
      }
    });
  }

  Future<void> _startListening() async {
    if (!_isInitialized) return;
    setState(() {
      _text = 'Listening...';
      _statusMessage = 'Please speak now';
      _isListening = true;
    });

    await _speech.listen(
      onResult: _onSpeechResult,
      // ignore: deprecated_member_use
      listenFor: const Duration(seconds: 20),
      // ignore: deprecated_member_use
      pauseFor: const Duration(seconds: 4),
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
      ),
    );

  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    setState(() {
      _text = result.recognizedWords;
    });

    if (result.finalResult) {
      // Pause slightly so the user can see their final text before navigation
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted && _text.trim().isNotEmpty && _text != 'Listening...') {
          Navigator.of(context).pop(_text);
        }
      });
    }
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    if (mounted) {
      setState(() {
        _isListening = false;
      });
      _pulseController.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _text.isNotEmpty && _text != 'Listening...';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          
          // Header / Status
          Text(
            _isListening ? 'Listening' : 'Voice Search',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF9CA3AF),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),

          // Main text displaying transcription
          Container(
            constraints: const BoxConstraints(minHeight: 80),
            alignment: Alignment.center,
            child: Text(
              _text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: hasText ? const Color(0xFF111827) : const Color(0xFF9CA3AF),
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Suggestion / Help Subtext
          Text(
            _statusMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 40),

          // Pulsing microphone button
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Pulse ripple effect
                if (_isListening)
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Opacity(
                          opacity: (1.5 - _pulseAnimation.value).clamp(0.0, 1.0),
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: const BoxDecoration(
                              color: Color(0x33FB5404),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                
                // Outer circle border
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: _isListening
                        ? const Color(0xFFFB5404)
                        : const Color(0xFFF3F4F6),
                    shape: BoxShape.circle,
                    boxShadow: _isListening
                        ? [
                            const BoxShadow(
                              color: Color(0x4DFB5404),
                              blurRadius: 16,
                              offset: Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                ),

                // Button itself
                SizedBox(
                  width: 90,
                  height: 90,
                  child: IconButton(
                    onPressed: () {
                      if (_isListening) {
                        _stopListening();
                      } else {
                        if (!_isInitialized) {
                          _initSpeech();
                        } else {
                          _startListening();
                        }
                      }
                    },
                    icon: Icon(
                      _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                      size: 40,
                      color: _isListening ? Colors.white : const Color(0xFFFB5404),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),

          // Action buttons: Close
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6B7280),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Cancel'),
              ),
              if (hasText) ...[
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(_text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFB5404),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Search'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
