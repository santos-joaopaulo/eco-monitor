import "package:material_ui/material_ui.dart";

import "../../data/admin_database_repository.dart";
import "../../data/app_data_sync.dart";
import "../../domain/entities/waste_type.dart";
import "../../models/campaign.dart";
import "../../services/location_service.dart";
import "../../theme/app_colors.dart";
import "../../theme/eco_theme.dart";
import "../../utils/formatters.dart";
import "../../widgets/eco_app_bar.dart";
import "../../widgets/waste_style.dart";


// Classes ----------------------------------------------------------------- //


/// Formulário de criação ou edição de uma campanha de coleta.
class AdminCampaignFormScreen extends StatefulWidget {
  const AdminCampaignFormScreen({
    super.key,
    required this.databaseRepository,
    this.dataSync,
    this.existingCampaign,
    this.locationService = const LocationService(),
  });

  final AdminDatabaseRepository databaseRepository;
  final AppDataSync? dataSync;
  final Campaign? existingCampaign;
  final LocationService locationService;

  @override
  State<AdminCampaignFormScreen> createState() =>
      _AdminCampaignFormScreenState();
}

class _AdminCampaignFormScreenState extends State<AdminCampaignFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationNameController;
  late final TextEditingController _addressController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;

  late DateTime _startDate;
  late DateTime _endDate;
  late CampaignStatus _status;
  late Set<WasteType> _selectedWastes;

  bool _isLoadingGps = false;
  bool _isSaving = false;
  String? _errorMessage;


  // Lifecycle ------------------------------------------------------------- //


  @override
  void initState() {
    super.initState();

    final Campaign? existing = widget.existingCampaign;
    final DateTime now = DateTime.now().toUtc();

    if (existing != null) {
      _titleController = TextEditingController(text: existing.title);
      _descriptionController =
          TextEditingController(text: existing.description);
      _locationNameController =
          TextEditingController(text: existing.locationName);
      _addressController = TextEditingController(text: existing.address);
      _latitudeController =
          TextEditingController(text: existing.latitude.toString());
      _longitudeController =
          TextEditingController(text: existing.longitude.toString());
      _startDate = existing.startDate;
      _endDate = existing.endDate;
      _status = existing.status;
      _selectedWastes = Set<WasteType>.of(existing.wasteTypes);
    } else {
      _titleController = TextEditingController();
      _descriptionController = TextEditingController();
      _locationNameController = TextEditingController();
      _addressController = TextEditingController();
      _latitudeController = TextEditingController();
      _longitudeController = TextEditingController();
      _startDate = DateTime.utc(now.year, now.month, now.day);
      _endDate = _startDate.add(const Duration(days: 7));
      _status = CampaignStatus.active;
      _selectedWastes = <WasteType>{
        WasteType.medicines,
        WasteType.batteries,
        WasteType.electronics,
      };
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationNameController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }


  // Methods --------------------------------------------------------------- //


  Future<void> _fetchCurrentLocation() async {
    setState(() {
      _isLoadingGps = true;
    });

    try {
      final UserLocation? location =
          await widget.locationService.currentPosition();
      if (!mounted) {
        return;
      }

      if (location != null) {
        _latitudeController.text = location.latitude.toStringAsFixed(6);
        _longitudeController.text = location.longitude.toStringAsFixed(6);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Não foi possível obter a localização GPS atual."),
          ),
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Falha ao acessar serviço de localização.")),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingGps = false;
        });
      }
    }
  }

  Future<void> _pickStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (picked != null && mounted) {
      setState(() {
        _startDate = DateTime.utc(picked.year, picked.month, picked.day);
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(days: 1));
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2035),
    );

    if (picked != null && mounted) {
      setState(() {
        _endDate = DateTime.utc(picked.year, picked.month, picked.day, 23, 59, 59);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedWastes.isEmpty) {
      setState(() {
        _errorMessage = "Selecione pelo menos um tipo de resíduo para a campanha.";
      });
      return;
    }

    final double? lat = double.tryParse(_latitudeController.text.trim());
    final double? lng = double.tryParse(_longitudeController.text.trim());

    if (lat == null || lng == null) {
      setState(() {
        _errorMessage = "Coordenadas de latitude e longitude inválidas.";
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final String id = widget.existingCampaign?.id ?? "";

      final Campaign campaign = Campaign(
        id: id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        wasteTypes: _selectedWastes,
        locationName: _locationNameController.text.trim(),
        address: _addressController.text.trim(),
        latitude: lat,
        longitude: lng,
        startDate: _startDate,
        endDate: _endDate,
        status: _status,
      );

      await widget.databaseRepository.saveCampaign(campaign);
      widget.dataSync?.refreshAll();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.existingCampaign != null
                ? "Campanha atualizada com sucesso!"
                : "Nova campanha cadastrada com sucesso!",
          ),
          backgroundColor: AppColors.primaryAccessible,
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = "Erro ao salvar campanha no banco: $e";
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.existingCampaign != null;

    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: EcoAppBar(
        title: isEditing ? "EDITAR CAMPANHA" : "NOVA CAMPANHA",
        onBack: () => Navigator.of(context).pop(),
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

              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Dados Principais
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "INFORMAÇÕES DA CAMPANHA",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 14),

                            TextFormField(
                              controller: _titleController,
                              validator: (String? v) =>
                                  v == null || v.trim().isEmpty
                                  ? "Informe o título da campanha"
                                  : null,
                              decoration: const InputDecoration(
                                labelText: "Título da Campanha *",
                                hintText: "Ex.: Mutirão de Coleta de Eletrônicos",
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 14),

                            TextFormField(
                              controller: _descriptionController,
                              maxLines: 3,
                              validator: (String? v) =>
                                  v == null || v.trim().isEmpty
                                  ? "Informe a descrição da campanha"
                                  : null,
                              decoration: const InputDecoration(
                                labelText: "Descrição *",
                                hintText:
                                    "Descreva o objetivo e orientações aos cidadãos",
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 14),

                            const Text(
                              "Status da Campanha",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),

                            SegmentedButton<CampaignStatus>(
                              segments: const [
                                ButtonSegment<CampaignStatus>(
                                  value: CampaignStatus.active,
                                  label: Text("Ativa"),
                                ),
                                ButtonSegment<CampaignStatus>(
                                  value: CampaignStatus.upcoming,
                                  label: Text("Prevista"),
                                ),
                                ButtonSegment<CampaignStatus>(
                                  value: CampaignStatus.finished,
                                  label: Text("Encerrada"),
                                ),
                              ],
                              selected: {_status},
                              onSelectionChanged: (
                                Set<CampaignStatus> newSelection,
                              ) {
                                setState(() {
                                  _status = newSelection.first;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Datas
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "PERÍODO DO EVENTO",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 12),

                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _pickStartDate,
                                    icon: const Icon(Icons.date_range, size: 18),
                                    label: Text(
                                      "Início: ${formatDate(_startDate)}",
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),

                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _pickEndDate,
                                    icon: const Icon(Icons.event_available, size: 18),
                                    label: Text(
                                      "Fim: ${formatDate(_endDate)}",
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Localização
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Text(
                                    "LOCAL DO EVENTO",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textSecondary,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: _isLoadingGps
                                      ? null
                                      : _fetchCurrentLocation,
                                  icon: _isLoadingGps
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.my_location, size: 16),
                                  label: const Text(
                                    "GPS Atual",
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            TextFormField(
                              controller: _locationNameController,
                              validator: (String? v) =>
                                  v == null || v.trim().isEmpty
                                  ? "Informe o nome do local"
                                  : null,
                              decoration: const InputDecoration(
                                labelText: "Nome do Local *",
                                hintText: "Ex.: Praça Fausto Cardoso",
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),

                            TextFormField(
                              controller: _addressController,
                              validator: (String? v) =>
                                  v == null || v.trim().isEmpty
                                  ? "Informe o endereço completo"
                                  : null,
                              decoration: const InputDecoration(
                                labelText: "Endereço *",
                                hintText: "Ex.: Av. Rio Branco, s/n - Centro",
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),

                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _latitudeController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                          signed: true,
                                        ),
                                    validator: (String? v) =>
                                        v == null || v.trim().isEmpty
                                        ? "Latitude obrigatória"
                                        : null,
                                    decoration: const InputDecoration(
                                      labelText: "Latitude *",
                                      hintText: "-10.951234",
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                Expanded(
                                  child: TextFormField(
                                    controller: _longitudeController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                          signed: true,
                                        ),
                                    validator: (String? v) =>
                                        v == null || v.trim().isEmpty
                                        ? "Longitude obrigatória"
                                        : null,
                                    decoration: const InputDecoration(
                                      labelText: "Longitude *",
                                      hintText: "-37.067890",
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Resíduos Aceitos
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "RESÍDUOS ACEITOS NA CAMPANHA",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 10),

                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: WasteType.values.map((WasteType type) {
                                final bool isSelected =
                                    _selectedWastes.contains(type);
                                return FilterChip(
                                  label: Text(type.label),
                                  selected: isSelected,
                                  selectedColor: AppColors.primaryTint,
                                  checkmarkColor: AppColors.primaryAccessible,
                                  labelStyle: TextStyle(
                                    color: isSelected
                                        ? AppColors.primaryAccessible
                                        : AppColors.textPrimary,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                  ),
                                  onSelected: (bool selected) {
                                    setState(() {
                                      if (selected) {
                                        _selectedWastes.add(type);
                                      } else {
                                        _selectedWastes.remove(type);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.warningBackground,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: AppColors.warningText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              isEditing
                                  ? "Salvar Alterações"
                                  : "Cadastrar Campanha",
                              style: const TextStyle(
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
    );
  }
}
