import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:echolog/services/security_service.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen>
    with SingleTickerProviderStateMixin {
  String _enteredPin = '';
  late AnimationController _controller;
  late Animation<Offset> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticIn));

    // Attempt biometric auth immediately when the screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryBiometricAuth();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _tryBiometricAuth() async {
    if (!mounted) return;
    final securityService = Provider.of<SecurityService>(
      context,
      listen: false,
    );
    if (securityService.authMethod == AuthMethod.Biometrics) {
      final didAuthenticate = await securityService.authenticate();
      if (didAuthenticate && mounted) {
        securityService.unlockApp();
      }
    }
  }

  void _onKeyPressed(String value) {
    HapticFeedback.lightImpact();
    if (value == 'backspace') {
      if (_enteredPin.isNotEmpty) {
        setState(() {
          _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        });
      }
    } else if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += value;
      });
      if (_enteredPin.length == 4) {
        _verifyPin();
      }
    }
  }

  void _verifyPin() {
    final securityService = Provider.of<SecurityService>(
      context,
      listen: false,
    );
    final isCorrect = securityService.checkPasscode(_enteredPin);

    if (isCorrect) {
      securityService.unlockApp();
    } else {
      // Trigger shake animation
      _controller.forward(from: 0.0);
      // Clear PIN after a short delay
      Timer(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _enteredPin = '';
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final securityService = context.watch<SecurityService>();

    // Define the shake animation
    _animation = Tween<Offset>(
      begin: const Offset(-0.05, 0.0),
      end: const Offset(0.05, 0.0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticIn));

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              Icon(
                Icons.shield_moon_outlined,
                size: 60,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Enter Passcode',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 40),
              SlideTransition(
                position: _animation,
                child: _buildPinIndicator(),
              ),
              const Spacer(flex: 1),
              _buildKeypad(),
              const Spacer(flex: 1),
              if (securityService.authMethod == AuthMethod.Biometrics)
                TextButton.icon(
                  icon: Icon(
                    Icons.fingerprint,
                    color: theme.colorScheme.secondary,
                  ),
                  label: Text(
                    'Use Biometrics',
                    style: GoogleFonts.poppins(
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onPressed: _tryBiometricAuth,
                ),
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: index < _enteredPin.length
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.surfaceVariant,
          ),
        );
      }),
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            '1',
            '2',
            '3',
          ].map((e) => _KeypadButton(label: e, onTap: _onKeyPressed)).toList(),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            '4',
            '5',
            '6',
          ].map((e) => _KeypadButton(label: e, onTap: _onKeyPressed)).toList(),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            '7',
            '8',
            '9',
          ].map((e) => _KeypadButton(label: e, onTap: _onKeyPressed)).toList(),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 70, height: 70), // Placeholder
            _KeypadButton(label: '0', onTap: _onKeyPressed),
            _KeypadButton(
              isIcon: true,
              icon: Icons.backspace_outlined,
              onTap: (_) => _onKeyPressed('backspace'),
            ),
          ],
        ),
      ],
    );
  }
}

class _KeypadButton extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final bool isIcon;
  final Function(String) onTap;

  const _KeypadButton({
    this.label,
    this.icon,
    this.isIcon = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(35),
        onTap: () => onTap(label ?? ''),
        child: Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isIcon
                ? Colors.transparent
                : theme.colorScheme.surfaceVariant.withOpacity(0.5),
          ),
          child: Center(
            child: isIcon
                ? Icon(icon, color: theme.colorScheme.onSurfaceVariant)
                : Text(
                    label!,
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
