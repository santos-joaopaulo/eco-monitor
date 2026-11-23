import "package:material_ui/material_ui.dart";

import "../../data/admin_database_repository.dart";
import "../../data/app_data_sync.dart";
import "../../domain/entities/point_review.dart";
import "../../domain/entities/waste_type.dart";
import "../../models/collection_point.dart";
import "../../models/point_suggestion.dart";
import "../../services/location_service.dart";
import "../../theme/app_colors.dart";
import "../../theme/eco_theme.dart";
import "../../widgets/eco_app_bar.dart";
import "../../widgets/waste_style.dart";
import "admin_reviews_screen.dart";


// Classes ----------------------------------------------------------------- //


/// Formulário de criação ou edição de um ponto de coleta oficial.
class AdminPointFormScreen extends StatefulWidget {
  const AdminPointFormScreen({
    super.key,
    required this.databaseRepository,
    this.dataSync,
    this.existingPoint,
    this.fromSuggestion,
    this.locationService = const LocationService(),
  });

  final AdminDatabaseRepository databaseRepository;
  final AppDataSync? dataSync;
  final CollectionPoint? existingPoint;
  final PointSuggestion? fromSuggestion;
  final LocationService locationService;

  @override
  State<AdminPointFormScreen> createState() => _AdminPointFormScreenState();
}

class _AdminPointFormScreenState extends State<AdminPointFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  late final TextEditingController _hoursController;

  late PointType _pointType;
  late PointStatus _status;
  late Set<WasteType> _selectedWastes;

  bool _isLoadingGps = false;
  bool _isSaving = false;
  bool _isLoadingReviews = false;
  PointReviewStats? _reviewStats;
  String? _errorMessage;


  // Lifecycle ------------------------------------------------------------- //


  @override
  void initState() {
    super.initState();

    final CollectionPoint? existing = widget.existingPoint;
    final PointSuggestion? suggestion = widget.fromSuggestion;

    if (existing != null) {
      _nameController = TextEditingController(text: existing.name);
      _addressController = TextEditingController(text: existing.address);
      _latitudeController =
          TextEditingController(text: existing.latitude.toString());
      _longitudeController =
          TextEditingController(text: existing.longitude.toString());
      _hoursController = TextEditingController(text: existing.hours);
      _pointType = existing.type;
      _status = existing.status;
      _selectedWastes = Set<WasteType>.of(existing.acceptedWasteTypes);
      _loadReviewStats(existing.id);
    } else if (suggestion != null) {
      _nameController = TextEditingController(text: suggestion.name);
      _addressController = TextEditingController(text: suggestion.address);
      _latitudeController = TextEditingController(
        text: suggestion.latitude?.toString() ?? "",
      );
      _longitudeController = TextEditingController(
        text: suggestion.longitude?.toString() ?? "",
      );
      _hoursController = TextEditingController(text: suggestion.hours);
      _pointType = PointType.ecoPoint;
      _status = PointStatus.active;
      _selectedWastes = Set<WasteType>.of(suggestion.acceptedWasteTypes);
    } else {
      _nameController = TextEditingController();
      _addressController = TextEditingController();
      _latitudeController = TextEditingController();
      _longitudeController = TextEditingController();
      _hoursController =
          TextEditingController(text: "Segunda a Sexta: 08h às 17h");
      _pointType = PointType.ecoPoint;
      _status = PointStatus.active;
      _selectedWastes = <WasteType>{WasteType.medicines, WasteType.batteries};
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _hoursController.dispose();
    super.dispose();
  }


  // Methods --------------------------------------------------------------- //


  Future<void> _loadReviewStats(String pointId) async {
    setState(() {
      _isLoadingReviews = true;
    });

    try {
      final List<PointReview> reviews =
          await widget.databaseRepository.fetchReviews(pointId: pointId);
      if (!mounted) {
        return;
      }

      if (reviews.isEmpty) {
        setState(() {
          _reviewStats = PointReviewStats(
            pointId: pointId,
            averageRating: 0.0,
            totalReviews: 0,
          );
          _isLoadingReviews = false;
        });
        return;
      }

      int sumRating = 0;
      final Map<String, int> tagCounts = <String, int>{};
      for (final PointReview r in reviews) {
        sumRating += r.rating;
        for (final String t in r.tags) {
          tagCounts[t] = (tagCounts[t] ?? 0) + 1;
        }
      }

      final double avg = sumRating / reviews.length;
      setState(() {
        _reviewStats = PointReviewStats(
          pointId: pointId,
          averageRating: double.parse(avg.toStringAsFixed(1)),
          totalReviews: reviews.length,
          tagCounts: tagCounts,
        );
        _isLoadingReviews = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingReviews = false;
        });
      }
    }
  }

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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedWastes.isEmpty) {
      setState(() {
        _errorMessage = "Selecione pelo menos um tipo de resíduo aceito.";
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
      final String id = widget.existingPoint?.id ?? "";

      final CollectionPoint point = CollectionPoint(
        id: id,
        name: _nameController.text.trim(),
        type: _pointType,
        latitude: lat,
        longitude: lng,
        address: _addressController.text.trim(),
        acceptedWasteTypes: _selectedWastes,
        hours: _hoursController.text.trim(),
        status: _status,
      );

      await widget.databaseRepository.savePoint(point);

      // Se foi criado a partir de uma sugestão, marca a sugestão como aprovada
      final PointSuggestion? suggestion = widget.fromSuggestion;
      if (suggestion != null && suggestion.id.isNotEmpty) {
        await widget.databaseRepository.updateSuggestionStatus(
          suggestion.id,
          SuggestionStatus.approved,
        );
      }

      widget.dataSync?.refreshAll();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.existingPoint != null
                ? "Ponto atualizado com sucesso!"
                : "Novo ponto criado com sucesso!",
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
        _errorMessage = "Erro ao salvar no banco: $e";
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.existingPoint != null;

    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: EcoAppBar(
        title: isEditing ? "EDITAR PONTO" : "NOVO PONTO DE COLETA",
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
                    // Avaliação Cidadã (durante edição)
                    if (isEditing) ...[
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Expanded(
                                    child: Text(
                                      "AVALIAÇÃO DA POPULAÇÃO",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textSecondary,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                  if (_reviewStats != null &&
                                      _reviewStats!.hasReviews)
                                    TextButton.icon(
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (BuildContext context) =>
                                                AdminReviewsScreen(
                                              databaseRepository:
                                                  widget.databaseRepository,
                                              dataSync: widget.dataSync,
                                              initialPointId:
                                                  widget.existingPoint!.id,
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.visibility_outlined,
                                        size: 16,
                                      ),
                                      label: const Text(
                                        "Ver Reportes",
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              if (_isLoadingReviews)
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(12),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                )
                              else if (_reviewStats != null &&
                                  _reviewStats!.hasReviews) ...[
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      color: AppColors.ratingStar,
                                      size: 26,
                                    ),
                                    const SizedBox(width: 6),

                                    Text(
                                      "${_reviewStats!.averageRating.toStringAsFixed(1)} / 5.0",
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    Expanded(
                                      child: Text(
                                        "(${_reviewStats!.totalReviews} ${_reviewStats!.totalReviews == 1 ? "avaliação" : "avaliações"})",
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_reviewStats!.topTags.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: _reviewStats!.topTags.map((
                                      String tag,
                                    ) {
                                      final int count =
                                          _reviewStats!.tagCounts[tag] ?? 0;
                                      final bool isAlert =
                                          tag == PointReviewTags.fullCollector;
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isAlert
                                              ? AppColors.warningBackground
                                              : AppColors.surfaceSection,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: isAlert
                                              ? Border.all(
                                                  color: AppColors.warningText
                                                      .withAlpha(60),
                                                )
                                              : null,
                                        ),
                                        child: Text(
                                          "$tag ($count)",
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: isAlert
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: isAlert
                                                ? AppColors.warningText
                                                : AppColors.textSecondary,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ] else ...[
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.star_outline_rounded,
                                      color: AppColors.textSecondary,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),

                                    Expanded(
                                      child: Text(
                                        "Nenhuma avaliação de cidadão registrada para este ecoponto até o momento.",
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

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
                              "INFORMAÇÕES BÁSICAS",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 14),

                            TextFormField(
                              controller: _nameController,
                              validator: (String? v) =>
                                  v == null || v.trim().isEmpty
                                  ? "Informe o nome do estabelecimento"
                                  : null,
                              decoration: const InputDecoration(
                                labelText: "Nome do Ponto *",
                                hintText: "Ex.: Farmácia Popular Central",
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 14),

                            const Text(
                              "Tipo de Estabelecimento",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),

                            SegmentedButton<PointType>(
                              segments: const [
                                ButtonSegment<PointType>(
                                  value: PointType.pharmacy,
                                  label: Text("Farmácia"),
                                ),
                                ButtonSegment<PointType>(
                                  value: PointType.healthCenter,
                                  label: Text("UBS"),
                                ),
                                ButtonSegment<PointType>(
                                  value: PointType.ecoPoint,
                                  label: Text("Ecoponto"),
                                ),
                              ],
                              selected: {_pointType},
                              onSelectionChanged: (Set<PointType> newSelection) {
                                setState(() {
                                  _pointType = newSelection.first;
                                });
                              },
                            ),
                            const SizedBox(height: 14),

                            TextFormField(
                              controller: _addressController,
                              validator: (String? v) =>
                                  v == null || v.trim().isEmpty
                                  ? "Informe o endereço"
                                  : null,
                              decoration: const InputDecoration(
                                labelText: "Endereço Completo *",
                                hintText: "Ex.: Rua das Flores, 123 - Centro",
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 14),

                            TextFormField(
                              controller: _hoursController,
                              validator: (String? v) =>
                                  v == null || v.trim().isEmpty
                                  ? "Informe o horário de funcionamento"
                                  : null,
                              decoration: const InputDecoration(
                                labelText: "Horário de Funcionamento *",
                                hintText: "Ex.: Seg a Sex: 08h às 18h",
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Coordenadas Geográficas
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
                                    "LOCALIZAÇÃO GEOGRÁFICA",
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
                            const SizedBox(height: 8),

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

                    // Resíduos Aceitos e Status
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
                              "MATERIAIS ACEITOS",
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
                                  avatar: Icon(
                                    type.icon,
                                    size: 16,
                                    color: isSelected
                                        ? type.color
                                        : AppColors.textSecondary,
                                  ),
                                  label: Text(type.label),
                                  selected: isSelected,
                                  selectedColor: type.color.withAlpha(35),
                                  checkmarkColor: type.color,
                                  labelStyle: TextStyle(
                                    color: isSelected
                                        ? type.color
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
                            const SizedBox(height: 16),

                            const Divider(height: 1, color: AppColors.outline),
                            const SizedBox(height: 8),

                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                "Ponto Ativo no Mapa",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              subtitle: const Text(
                                "Quando inativo, o ponto não é exibido aos cidadãos",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              value: _status == PointStatus.active,
                              activeThumbColor: AppColors.primary,
                              onChanged: (bool value) {
                                setState(() {
                                  _status = value
                                      ? PointStatus.active
                                      : PointStatus.inactive;
                                });
                              },
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
                                  : "Cadastrar Ponto",
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
