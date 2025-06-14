import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/password_service.dart';

class CreatePasswordDialog extends StatefulWidget {
  final PasswordService passwordService;
  final Function(bool passwordCreated) onPasswordSet;

  const CreatePasswordDialog({
    super.key,
    required this.passwordService,
    required this.onPasswordSet,
  });

  @override
  State<CreatePasswordDialog> createState() => _CreatePasswordDialogState();
}

class _CreatePasswordDialogState extends State<CreatePasswordDialog> {
  String _enteredPin = "";
  String? _firstPinAttempt;
  bool _isConfirmingPin = false;
  String _promptText = "Create a 4-digit PIN";
  String? _errorMessage;

  static const int _pinLength = 4;

  void _onNumberPress(String number) {
    if (_enteredPin.length < _pinLength) {
      setState(() {
        _enteredPin += number;
        _errorMessage = null; // Clear error on new input
      });

      if (_enteredPin.length == _pinLength) {
        _handlePinCompleted();
      }
    }
  }

  void _onBackspacePress() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _errorMessage = null; // Clear error
      });
    }
  }

  void _onClearPress() {
    setState(() {
      _enteredPin = "";
      _errorMessage = null;
      // If they were confirming and clear, maybe reset to initial step
      // or just clear current attempt. For simplicity, just clear current.
    });
  }

  void _handlePinCompleted() async {
    if (!_isConfirmingPin) {
      // First PIN entry completed
      setState(() {
        _firstPinAttempt = _enteredPin;
        _enteredPin = "";
        _isConfirmingPin = true;
        _promptText = "Confirm your 4-digit PIN";
      });
    } else {
      // Confirmation PIN entry completed
      if (_enteredPin == _firstPinAttempt) {
        // PINs match
        try {
          await widget.passwordService.setPassword(_enteredPin);
          // If setPassword completes without throwing, assume success.
          // Check mounted after an async gap before interacting with context.
          if (mounted) {
            Navigator.of(context).pop(true);
            widget.onPasswordSet(true);
          }
        } catch (e) {
          // Handle potential errors from setPassword.
          if (mounted) {
            // Check mounted before setState
            setState(() {
              _errorMessage = "Failed to save PIN. Please try again.";
              _resetToFirstStep();
            });
          }
        }
      } else {
        // PINs do not match
        setState(() {
          _errorMessage = "PINs do not match. Try again.";
          // Reset to re-enter the first PIN for a better UX
          // or just clear the confirmation and let them re-confirm.
          // For this example, let's reset fully.
          _resetToFirstStep(
            clearFirstAttempt: false,
          ); // Keep first attempt, just clear current input
          _enteredPin = ""; // Clear current input for re-confirmation
          _promptText = "Confirm PIN. Mismatch.";
        });
      }
    }
  }

  void _resetToFirstStep({bool clearFirstAttempt = true}) {
    setState(() {
      if (clearFirstAttempt) _firstPinAttempt = null;
      _enteredPin = "";
      _isConfirmingPin = false;
      _promptText = "Create a 4-digit PIN";
      // _errorMessage = null; // Error message is usually set before calling this
    });
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
            widget.onPasswordSet(false);
          },
        ),
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
            onTap: () {
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
