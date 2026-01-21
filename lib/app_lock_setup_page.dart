import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:artoku_app/services/ui_helper.dart';


class AppLockSetupPage extends StatefulWidget {
  final bool isChanging;
  final bool forceSetupFlow;

  const AppLockSetupPage({
    super.key,
    this.isChanging = false,
    this.forceSetupFlow = false,
  });

  @override
  State<AppLockSetupPage> createState() => _AppLockSetupPageState();
}


class _AppLockSetupPageState extends State<AppLockSetupPage> {
  String _oldPin = "";
  String _newPin = "";
  String _confirmPin = "";
  bool _showNewPinStep = false;
  bool _showConfirmStep = false;
  bool _isLoading = false;
  final int _pinLength = 6;
  final Color primaryColor = const Color(0xFF0F4C5C);

  @override
  void initState() {
    super.initState();
    // Jika forceSetupFlow true, pastikan flow dua tahap (input PIN baru lalu konfirmasi)
    if (widget.forceSetupFlow) {
      _showNewPinStep = false;
      _showConfirmStep = false;
      _oldPin = "";
      _newPin = "";
      _confirmPin = "";
    }
  }

  void _addDigit(String digit) {
    if (widget.isChanging && !_showNewPinStep) {
      if (_oldPin.length < _pinLength) {
        setState(() {
          _oldPin += digit;
        });
      }
    } else if (!_showConfirmStep && _showNewPinStep) {
      if (_newPin.length < _pinLength) {
        setState(() {
          _newPin += digit;
        });
      }
    } else if (_showConfirmStep) {
      if (_confirmPin.length < _pinLength) {
        setState(() {
          _confirmPin += digit;
        });
        if (_confirmPin.length == _pinLength) {
          _verifyAndSave();
        }
      }
    } else {
      if (_newPin.length < _pinLength) {
        setState(() {
          _newPin += digit;
        });
      }
    }
  }

  void _removeDigit() {
    if (widget.isChanging && !_showNewPinStep) {
      if (_oldPin.isNotEmpty) {
        setState(() {
          _oldPin = _oldPin.substring(0, _oldPin.length - 1);
        });
      }
    } else if (!_showConfirmStep && _showNewPinStep) {
      if (_newPin.isNotEmpty) {
        setState(() {
          _newPin = _newPin.substring(0, _newPin.length - 1);
        });
      }
    } else if (_showConfirmStep) {
      if (_confirmPin.isNotEmpty) {
        setState(() {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        });
      }
    } else {
      if (_newPin.isNotEmpty) {
        setState(() {
          _newPin = _newPin.substring(0, _newPin.length - 1);
        });
      }
    }
  }

  void _proceedToConfirm() {
    if (_newPin.length != _pinLength) {
      UIHelper.showError(context, "PIN harus 6 digit!");
      return;
    }
    setState(() => _showConfirmStep = true);
  }

  Future<void> _verifyOldPin() async {
    if (_oldPin.length != _pinLength) {
      UIHelper.showError(context, "PIN harus 6 digit!");
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final savedPinHash = prefs.getString('appLockPin') ?? '';
    final inputHash = sha256.convert(utf8.encode(_oldPin)).toString();

    if (inputHash != savedPinHash) {
      if (mounted) {
        UIHelper.showError(context, "PIN lama salah. Coba lagi!");
      }
      setState(() => _oldPin = "");
      return;
    }

    if (mounted) {
      setState(() {
        _showNewPinStep = true;
      });
    }
  }

  void _backToFirstStep() {
    if (_showConfirmStep) {
      setState(() {
        _showConfirmStep = false;
        _confirmPin = "";
      });
    } else if (widget.isChanging && _showNewPinStep) {
      setState(() {
        _showNewPinStep = false;
        _newPin = "";
      });
    }
  }

  Future<void> _verifyAndSave() async {
    if (_newPin != _confirmPin) {
      if (mounted) {
        UIHelper.showError(context, "PIN tidak cocok. Coba lagi!");
      }
      setState(() {
        _confirmPin = "";
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final pinHash = sha256.convert(utf8.encode(_newPin)).toString();
      
      await prefs.setString('appLockPin', pinHash);
      await prefs.setBool('appLockEnabled', true);

      if (mounted) {
        // Tampilkan pesan sukses
        UIHelper.showSuccess(
          context,
          "Berhasil",
          widget.isChanging 
            ? "PIN aplikasi berhasil diubah."
            : "PIN aplikasi berhasil dibuat.",
        );
        
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            // Pop 1: Menutup Dialog UIHelper.showSuccess
            Navigator.pop(context); 
            
            // Pop 2: Menutup Halaman AppLockSetupPage agar kembali ke Profile
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        UIHelper.showError(context, "Gagal menyimpan PIN: $e");
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    String currentPin;
    String title;
    String subtitle;
    bool showLanjutButton = false;

    if (widget.isChanging && !_showNewPinStep) {
      currentPin = _oldPin;
      title = "Verifikasi PIN Lama";
      subtitle = "Masukkan PIN lama Anda untuk konfirmasi";
      showLanjutButton = _oldPin.length == _pinLength;
    } else if (_showConfirmStep) {
      currentPin = _confirmPin;
      title = "Konfirmasi PIN Baru";
      subtitle = "Masukkan kembali PIN baru Anda untuk konfirmasi";
      showLanjutButton = false;
    } else {
      currentPin = _newPin;
      // Jika forceSetupFlow true, pastikan title selalu "Buat PIN"
      title = (widget.isChanging ? "PIN Baru" : "Buat PIN");
      subtitle = "Masukkan 6 digit PIN untuk kunci aplikasi Anda";
      showLanjutButton = _newPin.length == _pinLength;
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _isLoading
            ? null
            : IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: Theme.of(context).iconTheme.color,
                ),
                onPressed: (_showConfirmStep || (widget.isChanging && _showNewPinStep))
                    ? _backToFirstStep
                    : () => Navigator.pop(context),
              ),
        title: Text(
          widget.isChanging ? "Ubah PIN Aplikasi" : "Kunci Aplikasi",
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // PIN Display
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                6,
                (index) => Container(
                  width: 48,
                  height: 55,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: primaryColor.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: index < currentPin.length
                        ? Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: primaryColor,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 60),

            // Numpad
            _buildNumpad(),
            const SizedBox(height: 40),

            // Action Button
            if (showLanjutButton)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    if (widget.isChanging && !_showNewPinStep && !widget.forceSetupFlow) {
                      _verifyOldPin();
                    } else {
                      _proceedToConfirm();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    disabledBackgroundColor: primaryColor.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    widget.isChanging && !_showNewPinStep ? "Verifikasi" : "Lanjutkan",
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: [
          _buildNumpadRow(['1', '2', '3']),
          const SizedBox(height: 15),
          _buildNumpadRow(['4', '5', '6']),
          const SizedBox(height: 15),
          _buildNumpadRow(['7', '8', '9']),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const SizedBox(width: 70),
              _buildNumButton('0'),
              _buildBackspaceButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNumpadRow(List<String> numbers) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: numbers
          .map((number) => _buildNumButton(number))
          .toList(),
    );
  }

  Widget _buildNumButton(String number) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: _isLoading ? null : () => _addDigit(number),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? Colors.grey[800] : Colors.grey[100],
          border: Border.all(
            color: primaryColor.withOpacity(0.4),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            number,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: _isLoading ? null : _removeDigit,
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? Colors.grey[800] : Colors.grey[100],
          border: Border.all(
            color: primaryColor.withOpacity(0.4),
            width: 1.5,
          ),
        ),
        child: Icon(
          Icons.backspace,
          color: primaryColor,
          size: 24,
        ),
      ),
    );
  }
}
