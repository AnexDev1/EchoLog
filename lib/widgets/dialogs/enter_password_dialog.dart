import 'package:echolog/services/password_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EnterPasswordDialog extends StatefulWidget {
  final PasswordService passwordService;
  final Function(bool passwordCorrect) onPasswordEntered;

  const EnterPasswordDialog({
    super.key,
    required this.passwordService,
    required this.onPasswordEntered,
  });

  @override
  State<EnterPasswordDialog> createState() => _EnterPasswordDialogState();
}

class _EnterPasswordDialogState extends State<EnterPasswordDialog> {
  String _enteredPin = "";
  String _promptText = "Enter your 4-digit PIN";
  String? _errorMessage;
  bool _isVerifying = false; // To prevent multiple verification attempts

  static const int _pinLength = 4;

  void _onNumberPress(String number) {
    if (_isVerifying) return; // Don't process if already verifying
    if (_enteredPin.length < _pinLength) {
      setState(() {
        _enteredPin += number;
        _errorMessage = null; // Clear error on new input
      });

      if (_enteredPin.length == _pinLength) {
        _verifyPin();
      }
    }
  }

  void _onBackspacePress() {
    if (_isVerifying) return;
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _errorMessage = null; // Clear error
      });
    }
  }

  void _onClearPress() {
    if (_isVerifying) return;
    setState(() {
      _enteredPin = "";
      _errorMessage = null;
    });
  }

  Future<void> _verifyPin() async {
    if (_enteredPin.length != _pinLength || _isVerifying) return;

    setState(() {
      _isVerifying = true;
      _errorMessage = null; // Clear previous error
    });

    bool isCorrect = await widget.passwordService.verifyPassword(_enteredPin);

    if (!mounted) return;

    if (isCorrect) {
      // Pop dialog BEFORE calling the callback
      Navigator.of(context).pop(true);
      widget.onPasswordEntered(true);
    } else {
      setState(() {
        _errorMessage = "Incorrect PIN. Please try again.";
        _enteredPin = ""; // Clear PIN for re-entry
        _isVerifying = false;
      });
      // Optionally, you could call widget.onPasswordEntered(false) here
      // if HomeScreen needs to know about failed attempts immediately,
      // but typically it only cares about success or dialog cancellation.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
      backgroundColor: theme.colorScheme.surface,
      title: Text(
        _promptText,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          fontSize: 18,
          color: theme.colorScheme.onSurface,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPinDots(theme),
          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: theme.colorScheme.error,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 20),
          _buildNumberPad(theme),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.only(
        bottom: 15.0,
        left: 15.0,
        right: 15.0,
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          child: Text(
            'Cancel',
            style: GoogleFonts.poppins(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 15,
            ),
          ),
          onPressed: () {
            Navigator.of(context).pop();
            widget.onPasswordEntered(false); // Indicate cancellation
          },
        ),
        // The "Unlock" button is removed as verification is automatic on 4-digit entry.
        // If you prefer an explicit button, you can add it back and call _verifyPin from its onPressed.
      ],
    );
  }

  Widget _buildPinDots(ThemeData theme) {
    List<Widget> dots = [];
    for (int i = 0; i < _pinLength; i++) {
      dots.add(
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: i < _enteredPin.length
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.5),
              width: 1.5,
            ),
          ),
        ),
      );
    }
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: dots);
  }

  Widget _buildNumberPad(ThemeData theme) {
    final List<List<String>> numPadLayout = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['CLEAR', '0', '⌫'], // Using ⌫ for backspace
    ];

    return Column(
      children: numPadLayout.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((item) {
              return _buildNumPadButton(item, theme);
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNumPadButton(String item, ThemeData theme) {
    bool isClear = item == 'CLEAR';
    bool isBackspace = item == '⌫';
    bool isControl = isClear || isBackspace;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Material(
          color: isControl
              ? theme.colorScheme.surfaceVariant.withOpacity(0.7)
              : theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: _isVerifying
                ? null
                : () {
                    // Disable buttons while verifying
                    if (isClear) {
                      _onClearPress();
                    } else if (isBackspace) {
                      _onBackspacePress();
                    } else {
                      _onNumberPress(item);
                    }
                  },
            borderRadius: BorderRadius.circular(12),
            splashColor: theme.colorScheme.primary.withOpacity(0.3),
            highlightColor: theme.colorScheme.primary.withOpacity(0.1),
            child: Container(
              height: 60,
              alignment: Alignment.center,
              child: Text(
                item,
                style: GoogleFonts.poppins(
                  fontSize: isControl ? 16 : 22,
                  fontWeight: isControl ? FontWeight.w500 : FontWeight.w600,
                  color: isControl
                      ? theme.colorScheme.onSurfaceVariant.withOpacity(0.8)
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
