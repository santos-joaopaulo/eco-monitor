import "dart:async";

import "package:material_ui/material_ui.dart";

import "../../data/admin_database_repository.dart";
import "../../data/app_data_sync.dart";
import "../../services/admin_auth_service.dart";
import "../../theme/app_colors.dart";
import "../../theme/eco_theme.dart";
import "../../widgets/eco_app_bar.dart";
import "admin_dashboard_screen.dart";


// Classes ------------------------------------------------------------------ //


/// Tela de validação da chave de acesso exibida na primeira tentativa de entrada
/// no painel administrativo ou após revogação manual da autorização.
class AdminKeyScreen extends StatefulWidget {
  const AdminKeyScreen({
    super.key,
    this.authService,
    this.databaseRepository,
    this.dataSync,
  });

  final AdminAuthService? authService;
  final AdminDatabaseRepository? databaseRepository;
  final AppDataSync? dataSync;

  @override
  State<AdminKeyScreen> createState() => _AdminKeyScreenState();
}

class _AdminKeyScreenState extends State<AdminKeyScreen> {
  final TextEditingController _keyController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  late final AdminAuthService _authService;
  bool _obscureText = true;
  bool _isLoading = false;
  String? _errorMessage;
  int _remainingLockoutSeconds = 0;
  Timer? _countdownTimer;


// Lifecycle ---------------------------------------------------------------- //


  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AdminAuthService();
    _checkInitialLockout();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _keyController.dispose();
    _focusNode.dispose();
    super.dispose();
  }


// Methods ------------------------------------------------------------------ //


  Future<void> _checkInitialLockout() async {
    final int seconds = await _authService.remainingLockoutSeconds();
    if (seconds > 0 && mounted) {
      _startLockoutCountdown(seconds);
    }
  }

  void _startLockoutCountdown(int seconds) {
    _countdownTimer?.cancel();
    setState(() {
      _remainingLockoutSeconds = seconds;
      _errorMessage =
          "Muitas tentativas incorretas. Bloqueado por $_remainingLockoutSeconds segundos.";
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _remainingLockoutSeconds--;
        if (_remainingLockoutSeconds <= 0) {
          timer.cancel();
          _errorMessage = null;
        } else {
          _errorMessage =
              "Muitas tentativas incorretas. Bloqueado por $_remainingLockoutSeconds segundos.";
        }
      });
    });
  }

  Future<void> _submitKey() async {
    final String key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() {
        _errorMessage = "Informe a chave de acesso.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final AdminAuthResult result = await _authService.authenticate(key);

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
    });

    if (result.isSuccess) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => AdminDashboardScreen(
            authService: _authService,
            databaseRepository: widget.databaseRepository,
            dataSync: widget.dataSync,
          ),
        ),
      );
    } else if (result.isLockedOut) {
      _startLockoutCountdown(result.remainingLockoutSeconds);
    } else {
      setState(() {
        _errorMessage =
            "Chave de acesso incorreta. Tentativas restantes: ${result.attemptsRemaining}.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLockedOut = _remainingLockoutSeconds > 0;

    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: EcoAppBar(
        title: "ACESSO ADMINISTRATIVO",
        onBack: () => Navigator.of(context).pop(),
      ),

      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: kEcoContentHorizontalPadding,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kEcoMaxContentWidth),

              child: Card(
                elevation: 0,
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.outline),
                ),

                child: Padding(
                  padding: const EdgeInsets.all(24),

                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,

                    children: [
                      Center(
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryTint,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.admin_panel_settings_outlined,
                            size: 32,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        "Chave de Acesso",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),

                      const Text(
                        "Informe a chave mestre para liberar o painel de gerenciamento do banco de dados neste dispositivo.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),

                      TextField(
                        controller: _keyController,
                        focusNode: _focusNode,
                        enabled: !isLockedOut && !_isLoading,
                        obscureText: _obscureText,
                        autocorrect: false,
                        enableSuggestions: false,
                        autofocus: true,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submitKey(),
                        decoration: InputDecoration(
                          labelText: "Chave de Acesso",
                          hintText: "Digite a chave administrativa",
                          prefixIcon: const Icon(Icons.key_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureText
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            tooltip: _obscureText
                                ? "Exibir chave"
                                : "Ocultar chave",
                            onPressed: () {
                              setState(() {
                                _obscureText = !_obscureText;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.outline),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.outline),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: isLockedOut
                              ? AppColors.inactiveBackground
                              : AppColors.surface,
                        ),
                      ),

                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warningBackground,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: AppColors.warningText,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.warningText,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),

                      ElevatedButton(
                        onPressed: isLockedOut || _isLoading ? null : _submitKey,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                "Liberar Acesso",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
