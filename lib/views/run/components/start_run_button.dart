import 'package:flutter/material.dart';
import 'dart:async'; // Added for Timer

class CountdownStartButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color buttonColor;
  final Color textColor;
  final bool isLoading;
  final bool autoStart;
  final Future<void> Function()? onCountdownStart;

  const CountdownStartButton({
    super.key,
    required this.onPressed,
    required this.backgroundColor,
    required this.buttonColor,
    required this.textColor,
    this.isLoading = false,
    this.autoStart = false,
    this.onCountdownStart,
  });

  @override
  State<CountdownStartButton> createState() => _CountdownStartButtonState();
}

class _CountdownStartButtonState extends State<CountdownStartButton> with TickerProviderStateMixin {
  late AnimationController _countdownController;
  late Animation<double> _scaleAnimation;
  int _countdownValue = 3;
  bool _isCountingDown = false;

  @override
  void initState() {
    super.initState();
    _countdownController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _countdownController,
      curve: Curves.easeInOut,
    ));

    // Auto-start countdown if requested
    if (widget.autoStart && !widget.isLoading) {
      // Delay a tick to ensure build context is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _startCountdown();
        }
      });
    }
  }

  @override
  void dispose() {
    _countdownController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    if (_isCountingDown || widget.isLoading) return;
    
    print('🚀 Starting countdown...');
    setState(() {
      _isCountingDown = true;
      _countdownValue = 3;
    });

    // Fire warmup/pre-initialization without blocking UI
    try {
      widget.onCountdownStart?.call();
    } catch (_) {}

    // Start countdown timer
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      print('⏱️ Countdown: $_countdownValue');
      setState(() {
        _countdownValue--;
      });

      // Animate the button for each countdown number
      _countdownController.forward().then((_) {
        _countdownController.reverse();
      });

      if (_countdownValue <= 0) {
        timer.cancel();
        print('🎯 Countdown finished, starting run...');
        setState(() {
          _isCountingDown = false;
        });
        
        // Execute the actual start action
        if (widget.onPressed != null) {
          widget.onPressed!();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: (widget.isLoading || _isCountingDown) 
            ? widget.backgroundColor.withOpacity(0.6) 
            : widget.backgroundColor,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: widget.buttonColor.withOpacity((widget.isLoading || _isCountingDown) ? 0.1 : 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: (widget.isLoading || _isCountingDown) ? null : _startCountdown,
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: _buildButtonContent(),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildButtonContent() {
    print('🔍 Building button content: isLoading=${widget.isLoading}, _isCountingDown=$_isCountingDown, _countdownValue=$_countdownValue');
    
    if (widget.isLoading) {
      print('📱 Showing loading state');
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(widget.textColor),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Starting...',
            style: TextStyle(
              color: widget.textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }

    if (_isCountingDown) {
      print('⏱️ Showing countdown state: $_countdownValue');
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timer, color: widget.textColor, size: 24),
          const SizedBox(width: 8),
          Text(
            '$_countdownValue',
            style: TextStyle(
              color: widget.textColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }

    print('🚀 Showing start state');
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.play_arrow, color: widget.textColor, size: 28),
        const SizedBox(width: 8),
        Text(
          'Start Run',
          style: TextStyle(
            color: widget.textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
