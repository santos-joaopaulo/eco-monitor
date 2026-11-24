import "dart:async";

import "package:material_ui/material_ui.dart";

import "../../data/admin_database_repository.dart";
import "../../data/app_data_sync.dart";
import "../../data/firebase_service.dart";
import "../../services/admin_auth_service.dart";
import "../../theme/app_colors.dart";
import "../../theme/eco_theme.dart";
import "admin_campaigns_screen.dart";
import "admin_environmental_report_screen.dart";
import "admin_points_screen.dart";
import "admin_reviews_screen.dart";
import "admin_suggestions_screen.dart";


// Classes ----------------------------------------------------------------- //


/// Painel de controle do administrador para gerenciar coleções do banco de dados
/// (pontos de coleta, sugestões de usuários e campanhas) e sincronização.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    super.key,
    this.authService,
    this.databaseRepository,
    this.dataSync,
  });

  final AdminAuthService? authService;
  final AdminDatabaseRepository? databaseRepository;
  final AppDataSync? dataSync;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late final AdminAuthService _authService;
  late final AdminDatabaseRepository _repository;

  bool _isSyncing = false;


  // Lifecycle ------------------------------------------------------------- //


  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AdminAuthService();
    _repository =
        widget.databaseRepository ?? FirestoreAdminDatabaseRepository();
  }


  // Methods --------------------------------------------------------------- //


  Future<void> _lockAdminAccess() async {
    await _authService.revokeAuthorization();
    if (!mounted) {
      return;
    }

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Acesso administrativo bloqueado com sucesso."),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _syncAppData() async {
    final AppDataSync? dataSync = widget.dataSync;
    if (dataSync == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Sincronizador não configurado neste contexto."),
        ),
      );
      return;
    }

    setState(() {
      _isSyncing = true;
    });

    try {
      await dataSync.refreshAll();
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Dados do aplicativo sincronizados com o banco!"),
          backgroundColor: AppColors.primaryAccessible,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro ao sincronizar dados: $e"),
          backgroundColor: AppColors.warningText,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  void _navigateToPoints() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => AdminPointsScreen(
          databaseRepository: _repository,
          dataSync: widget.dataSync,
        ),
      ),
    );
  }

  void _navigateToSuggestions() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => AdminSuggestionsScreen(
          databaseRepository: _repository,
          dataSync: widget.dataSync,
        ),
      ),
    );
  }

  void _navigateToReviews() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => AdminReviewsScreen(
          databaseRepository: _repository,
          dataSync: widget.dataSync,
        ),
      ),
    );
  }

  void _navigateToCampaigns() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => AdminCampaignsScreen(
          databaseRepository: _repository,
          dataSync: widget.dataSync,
        ),
      ),
    );
  }

  void _navigateToEnvironmentalReport() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => AdminEnvironmentalReportScreen(
          databaseRepository: _repository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isOnline = widget.dataSync?.isOnline ?? true;
    final bool firebaseReady = isFirebaseReady;

    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "PAINEL ADMINISTRATIVO",
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.lock_outline),
            tooltip: "Bloquear Painel",
            onPressed: _lockAdminAccess,
          ),
        ],
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: kEcoContentHorizontalPadding,
            vertical: 20,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kEcoMaxContentWidth),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cartão de boas-vindas / status
                  Card(
                    elevation: 0,
                    color: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppColors.outline),
                    ),

                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: AppColors.primaryTint,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.storage_rounded,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Banco de Dados Cloud Firestore",
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),

                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: firebaseReady && isOnline
                                            ? AppColors.active
                                            : AppColors.inactive,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),

                                    Text(
                                      firebaseReady && isOnline
                                          ? "Conectado e operacional"
                                          : "Modo offline / local",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: firebaseReady && isOnline
                                            ? AppColors.active
                                            : AppColors.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Módulos de Gestão
                  const Text(
                    "MÓDULOS DE GERENCIAMENTO",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),

                  _AdminModuleCard(
                    title: "Pontos de Coleta",
                    subtitle: "Cadastrar, editar e ativar/desativar locais de descarte",
                    icon: Icons.place_outlined,
                    iconColor: AppColors.primary,
                    iconBackground: AppColors.primaryTint,
                    onTap: _navigateToPoints,
                  ),
                  const SizedBox(height: 10),

                  _AdminModuleCard(
                    title: "Sugestões de Usuários",
                    subtitle: "Moderar novas propostas de pontos enviadas pelo app",
                    icon: Icons.lightbulb_outline,
                    iconColor: AppColors.medicine,
                    iconBackground: AppColors.warningBackground,
                    onTap: _navigateToSuggestions,
                  ),
                  const SizedBox(height: 10),

                  _AdminModuleCard(
                    title: "Campanhas de Coleta",
                    subtitle: "Gerenciar alertas, datas e locais de eventos temporários",
                    icon: Icons.campaign_outlined,
                    iconColor: AppColors.sharps,
                    iconBackground: AppColors.surfaceSection,
                    onTap: _navigateToCampaigns,
                  ),
                  const SizedBox(height: 10),

                  _AdminModuleCard(
                    title: "Avaliações e Reportes Cidadãos",
                    subtitle: "Moderar notas, comentários e verificar ecopontos críticos",
                    icon: Icons.rate_review_outlined,
                    iconColor: AppColors.ratingStar,
                    iconBackground: AppColors.warningBackground,
                    onTap: _navigateToReviews,
                  ),
                  const SizedBox(height: 10),

                  _AdminModuleCard(
                    title: "Relatório Ambiental (PDF)",
                    subtitle: "Exportar indicadores de impacto ecológico e gestão cívica",
                    icon: Icons.picture_as_pdf_outlined,
                    iconColor: AppColors.primaryAccessible,
                    iconBackground: AppColors.primaryTint,
                    onTap: _navigateToEnvironmentalReport,
                  ),
                  const SizedBox(height: 24),

                  // Ações de Sistema
                  const Text(
                    "OPERAÇÕES DE SISTEMA",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Card(
                    elevation: 0,
                    color: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppColors.outline),
                    ),

                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                color: AppColors.primaryTint,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.sync_rounded,
                                color: AppColors.primary,
                                size: 22,
                              ),
                            ),
                            title: const Text(
                              "Sincronizar Dados",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            subtitle: const Text(
                              "Atualiza o cache do app com o estado mais recente do banco",
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            trailing: _isSyncing
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary,
                                    ),
                                  )
                                : ElevatedButton(
                                    onPressed: _syncAppData,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text("Atualizar"),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminModuleCard extends StatelessWidget {
  const _AdminModuleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.outline),
      ),

      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),

        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),

                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
