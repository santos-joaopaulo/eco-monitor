import "package:material_ui/material_ui.dart";

import "../data/app_data_sync.dart";
import "../data/point_suggestions_repository.dart";
import "../domain/entities/waste_type.dart";
import "../domain/entities/point_suggestion.dart";
import "../services/location_service.dart";
import "../theme/app_colors.dart";
import "../theme/eco_theme.dart";
import "../widgets/custom_bottom_nav_bar.dart";
import "../widgets/opening_hours_row.dart";
import "../widgets/waste_type_option_card.dart";


// Enums -------------------------------------------------------------------- //


/// Dias da semana exibidos na seção de horário de funcionamento.
enum _Weekday {
  monday("Seg"),
  tuesday("Ter"),
  wednesday("Qua"),
  thursday("Qui"),
  friday("Sex"),
  saturday("Sáb"),
  sunday("Dom");

  const _Weekday(this.label);

  final String label;
}


// Classes ------------------------------------------------------------------ //


/// Tela com formulário completo para sugestão anônima de novos pontos de coleta (RF10, RF11, RNF06).
class SuggestScreen extends StatefulWidget {
  const SuggestScreen({
    super.key,
    this.repository,
    this.dataSync,
    this.locationService = const LocationService(),
  });

  final PointSuggestionsRepository? repository;
  final AppDataSync? dataSync;
  final LocationService locationService;

  @override
  State<SuggestScreen> createState() => _SuggestScreenState();
}

class _SuggestScreenState extends State<SuggestScreen> {
  static const TimeOfDay _defaultOpensAt = TimeOfDay(hour: 8, minute: 0);
  static const TimeOfDay _defaultClosesAt = TimeOfDay(hour: 18, minute: 0);

  static const List<WasteType> _wasteTypeOrder = <WasteType>[
    WasteType.medicines,
    WasteType.batteries,
    WasteType.sharps,
    WasteType.electronics,
    WasteType.glass,
  ];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();

  final Set<WasteType> _selectedWasteTypes = <WasteType>{};

  final Map<_Weekday, _DaySchedule> _schedules = <_Weekday, _DaySchedule>{
    for (final _Weekday day in _Weekday.values)
      day: _DaySchedule(
        isOpen: day.index <= _Weekday.friday.index,
        opensAt: _defaultOpensAt,
        closesAt: _defaultClosesAt,
      ),
  };

  bool _isLocating = false;
  bool _isSubmitting = false;
  bool _wasteTypeHasError = false;
  bool _hoursHasError = false;
  String? _hoursErrorMessage;


// Inicialização ------------------------------------------------------------ //


  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }


// Methods ------------------------------------------------------------------ //


  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError
              ? AppColors.medicine
              : AppColors.primary,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  Future<void> _captureLocation() async {
    setState(() {
      _isLocating = true;
    });

    try {
      final UserLocation? location = await widget.locationService
          .currentPosition();

      if (!mounted) {
        return;
      }

      if (location != null) {
        setState(() {
          _latitudeController.text = location.latitude.toStringAsFixed(5);
          _longitudeController.text = location.longitude.toStringAsFixed(5);
        });

        _showSnackBar("Coordenadas GPS capturadas com sucesso!");
      } else {
        _showSnackBar(
          "Não foi possível obter a localização do aparelho.",
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLocating = false;
        });
      }
    }
  }

  Future<void> _pickTime(_Weekday day, {required bool isOpening}) async {
    final _DaySchedule schedule = _schedules[day]!;

    final TimeOfDay? selected = await showTimePicker(
      context: context,
      initialTime: isOpening ? schedule.opensAt : schedule.closesAt,
      helpText: isOpening ? "Horário de abertura" : "Horário de fechamento",
      cancelText: "Cancelar",
      confirmText: "Confirmar",

      builder: (BuildContext context, Widget? child) {
        final ThemeData theme = Theme.of(context);

        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),

          child: Theme(
            data: theme.copyWith(
              colorScheme: theme.colorScheme.copyWith(
                primary: AppColors.primary,
                onPrimary: Colors.white,
                surface: AppColors.surface,
                onSurface: AppColors.textPrimary,
              ),
              timePickerTheme: TimePickerThemeData(
                backgroundColor: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                hourMinuteColor: AppColors.primaryTint,
                hourMinuteTextColor: AppColors.primary,
                dialBackgroundColor: AppColors.surfaceSection,
                dialHandColor: AppColors.primary,
                dialTextColor: AppColors.textPrimary,
                dayPeriodColor: AppColors.primaryTint,
                dayPeriodTextColor: AppColors.primary,
                helpTextStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),

            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      if (isOpening) {
        schedule.opensAt = selected;
      } else {
        schedule.closesAt = selected;
      }

      _hoursHasError = false;
      _hoursErrorMessage = null;
    });
  }

  void _toggleWasteType(WasteType type) {
    setState(() {
      if (!_selectedWasteTypes.remove(type)) {
        _selectedWasteTypes.add(type);
      }

      _wasteTypeHasError = false;
    });
  }

  void _toggleDay(_Weekday day) {
    setState(() {
      final _DaySchedule schedule = _schedules[day]!;
      schedule.isOpen = !schedule.isOpen;

      _hoursHasError = false;
      _hoursErrorMessage = null;
    });
  }

  void _replicateSchedule() {
    _DaySchedule? source;

    for (final _DaySchedule schedule in _schedules.values) {
      if (schedule.isOpen) {
        source = schedule;
        break;
      }
    }

    final TimeOfDay opensAt = source?.opensAt ?? _defaultOpensAt;
    final TimeOfDay closesAt = source?.closesAt ?? _defaultClosesAt;

    setState(() {
      for (final _DaySchedule schedule in _schedules.values) {
        schedule
          ..isOpen = true
          ..opensAt = opensAt
          ..closesAt = closesAt;
      }

      _hoursHasError = false;
      _hoursErrorMessage = null;
    });

    _showSnackBar("Horário replicado para todos os dias.");
  }

  bool _validateSchedules() {
    final List<String> invalidDays = <String>[];

    for (final MapEntry<_Weekday, _DaySchedule> entry in _schedules.entries) {
      final _DaySchedule schedule = entry.value;

      if (!schedule.isOpen) {
        continue;
      }

      final int opensAtMinutes =
          schedule.opensAt.hour * 60 + schedule.opensAt.minute;
      final int closesAtMinutes =
          schedule.closesAt.hour * 60 + schedule.closesAt.minute;

      if (closesAtMinutes <= opensAtMinutes) {
        invalidDays.add(entry.key.label);
      }
    }

    if (invalidDays.isEmpty) {
      _hoursErrorMessage = null;
      return true;
    }

    _hoursErrorMessage =
        "O fechamento deve ser depois da abertura: ${invalidDays.join(", ")}.";
    return false;
  }

  String _formatSchedule() {
    final List<String> blocks = <String>[];
    final List<_Weekday> group = <_Weekday>[];

    void addGroup() {
      if (group.isEmpty) {
        return;
      }

      final _DaySchedule schedule = _schedules[group.first]!;
      final String days = switch (group.length) {
        1 => group.first.label,
        7 => "Todos os dias",
        _ => "${group.first.label} a ${group.last.label}",
      };

      blocks.add(
        "$days: ${formatTimeOfDayValue(schedule.opensAt)} às "
        "${formatTimeOfDayValue(schedule.closesAt)}",
      );

      group.clear();
    }

    for (final _Weekday day in _Weekday.values) {
      final _DaySchedule schedule = _schedules[day]!;

      if (!schedule.isOpen) {
        addGroup();
        continue;
      }

      if (group.isNotEmpty) {
        final _DaySchedule previous = _schedules[group.last]!;
        final bool isConsecutive = group.last.index + 1 == day.index;
        final bool hasSameHours =
            previous.opensAt == schedule.opensAt &&
            previous.closesAt == schedule.closesAt;

        if (!isConsecutive || !hasSameHours) {
          addGroup();
        }
      }

      group.add(day);
    }

    addGroup();

    return blocks.join(" · ");
  }

  void _resetSchedules() {
    for (final _Weekday day in _Weekday.values) {
      final _DaySchedule schedule = _schedules[day]!;

      schedule
        ..isOpen = day.index <= _Weekday.friday.index
        ..opensAt = _defaultOpensAt
        ..closesAt = _defaultClosesAt;
    }
  }

  Future<void> _submitForm() async {
    final bool isFormValid = _formKey.currentState?.validate() ?? false;
    final bool hasWasteTypes = _selectedWasteTypes.isNotEmpty;
    final bool hasValidHours = _validateSchedules();

    setState(() {
      _wasteTypeHasError = !hasWasteTypes;
      _hoursHasError = !hasValidHours;
    });

    if (!isFormValid || !hasWasteTypes || !hasValidHours || _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final double? parsedLatitude = _parseCoordinate(_latitudeController.text);
    final double? parsedLongitude = _parseCoordinate(_longitudeController.text);

    final PointSuggestion suggestion = PointSuggestion(
      id: "",
      name: _nameController.text.trim(),
      address: _addressController.text.trim(),
      acceptedWasteTypes: _selectedWasteTypes,
      hours: _formatSchedule(),
      latitude: parsedLatitude,
      longitude: parsedLongitude,
      status: SuggestionStatus.pending,
      createdAt: DateTime.now().toUtc(),
    );

    try {
      final SuggestionSubmitResult result;
      final AppDataSync? sync = widget.dataSync;
      final PointSuggestionsRepository? repo = widget.repository;

      if (sync != null) {
        result = await sync.submitSuggestion(suggestion);
      } else if (repo != null) {
        result = await repo.submit(suggestion);
      } else {
        result = SuggestionSubmitResult.sent;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _nameController.clear();
        _addressController.clear();
        _latitudeController.clear();
        _longitudeController.clear();
        _selectedWasteTypes.clear();
        _resetSchedules();
        _wasteTypeHasError = false;
        _hoursHasError = false;
        _hoursErrorMessage = null;
        _formKey.currentState?.reset();
      });

      final String message = result == SuggestionSubmitResult.sent
          ? "Sugestão enviada com sucesso! Obrigado por colaborar."
          : kOfflineQueuedMessage;

      _showSnackBar(message);
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showSnackBar(
        "Ocorreu um erro ao enviar. Tente novamente.",
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }


// Construção --------------------------------------------------------------- //


  @override
  Widget build(BuildContext context) {
    final double bottomInset =
        CustomBottomNavBar.reservedBottomInset(context) + 48;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kEcoMaxContentWidth),

        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            kEcoContentHorizontalPadding,
            20,
            kEcoContentHorizontalPadding,
            bottomInset,
          ),

          child: Form(
            key: _formKey,

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,

              children: [
                _buildHero(),
                const SizedBox(height: 24),

                _buildFieldLabel("Nome do estabelecimento"),
                const SizedBox(height: 8),
                _buildNameField(),
                const SizedBox(height: 18),

                _buildFieldLabel("Endereço"),
                const SizedBox(height: 8),
                _buildAddressField(),
                const SizedBox(height: 18),

                _buildFieldLabel("Coordenadas (opcional)"),
                const SizedBox(height: 8),
                _buildCoordinatesSection(),
                const SizedBox(height: 24),

                _buildWasteTypeSection(),
                const SizedBox(height: 24),

                _buildHoursSection(),
                const SizedBox(height: 28),

                _buildSubmitButton(),
                const SizedBox(height: 12),

                _buildAnonymousFootnote(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Semantics(
          header: true,
          child: const Text(
            "Ajude o mapa a crescer 🌱",
            style: TextStyle(
              fontSize: 24,
              height: 1.2,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 8),

        const Text(
          "Conheça um local que recebe resíduos? Envie para nossa equipe validar.",
          style: TextStyle(
            fontSize: 15,
            height: 1.45,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    final Color errorColor = Theme.of(context).colorScheme.error;

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
      filled: true,
      fillColor: AppColors.surface,
      prefixIcon: Icon(prefixIcon, size: 20, color: AppColors.textSecondary),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: AppColors.primary,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: errorColor),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: errorColor, width: 1.5),
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      textInputAction: TextInputAction.next,
      decoration: _fieldDecoration(
        hint: "Ex: Farmácia dos trabalhadores",
        prefixIcon: Icons.storefront_rounded,
      ),
      validator: (String? value) {
        final String trimmed = value?.trim() ?? "";
        if (trimmed.isEmpty) {
          return "Informe o nome do local.";
        }
        if (trimmed.length < 2) {
          return "O nome deve ter no mínimo 2 caracteres.";
        }
        if (trimmed.length > 120) {
          return "O nome deve ter no máximo 120 caracteres.";
        }
        return null;
      },
    );
  }

  double? _parseCoordinate(String raw) {
    final String normalized = raw.trim().replaceAll(",", ".");
    if (normalized.isEmpty) {
      return null;
    }
    return double.tryParse(normalized);
  }

  Widget _buildAddressField() {
    return TextFormField(
      controller: _addressController,
      textInputAction: TextInputAction.next,
      decoration: _fieldDecoration(
        hint: "Ex.: Rua das Flores, 120",
        prefixIcon: Icons.location_on_outlined,
      ),
      validator: (String? value) {
        final String trimmed = value?.trim() ?? "";
        if (trimmed.isEmpty) {
          return "Informe o endereço do local.";
        }
        if (trimmed.length < 5) {
          return "O endereço deve ter no mínimo 5 caracteres.";
        }
        if (trimmed.length > 200) {
          return "O endereço deve ter no máximo 200 caracteres.";
        }
        return null;
      },
    );
  }

  Widget _buildCoordinatesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,

      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Expanded(
              child: TextFormField(
                controller: _latitudeController,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                decoration: _fieldDecoration(
                  hint: "Latitude (ex.: -10.9472)",
                  prefixIcon: Icons.explore_outlined,
                ),
                validator: (String? value) {
                  final String trimmed = value?.trim() ?? "";
                  final String lonTrimmed = _longitudeController.text.trim();
                  if (trimmed.isEmpty) {
                    if (lonTrimmed.isNotEmpty) {
                      return "Informe a latitude.";
                    }
                    return null;
                  }
                  final double? parsed = _parseCoordinate(trimmed);
                  if (parsed == null || parsed < -90 || parsed > 90) {
                    return "Latitude inválida.";
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: TextFormField(
                controller: _longitudeController,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                decoration: _fieldDecoration(
                  hint: "Longitude (ex.: -37.0731)",
                  prefixIcon: Icons.explore_outlined,
                ),
                validator: (String? value) {
                  final String trimmed = value?.trim() ?? "";
                  final String latTrimmed = _latitudeController.text.trim();
                  if (trimmed.isEmpty) {
                    if (latTrimmed.isNotEmpty) {
                      return "Informe a longitude.";
                    }
                    return null;
                  }
                  final double? parsed = _parseCoordinate(trimmed);
                  if (parsed == null || parsed < -180 || parsed > 180) {
                    return "Longitude inválida.";
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        Tooltip(
          message: "Preencher com localização atual (GPS)",
          child: OutlinedButton.icon(
            onPressed: _isLocating ? null : _captureLocation,
            style: OutlinedButton.styleFrom(
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.primaryAccessible,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: _isLocating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : const Icon(
                    Icons.my_location_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
            label: Text(
              _isLocating
                  ? "Obtendo localização..."
                  : "Usar localização atual (GPS)",
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWasteTypeSection() {
    final double textScale = MediaQuery.textScalerOf(context).scale(1);
    final bool singleColumn = textScale > 1.25;
    final int crossAxisCount = singleColumn ? 1 : 2;
    final double extent = (54 * textScale.clamp(1.0, 1.4)).roundToDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        _buildFieldLabel("Materiais aceitos"),
        const SizedBox(height: 10),

        GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _wasteTypeOrder.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: extent,
          ),
          itemBuilder: (BuildContext context, int index) {
            final WasteType type = _wasteTypeOrder[index];

            return WasteTypeOptionCard(
              type: type,
              isSelected: _selectedWasteTypes.contains(type),
              onTap: () => _toggleWasteType(type),
            );
          },
        ),

        if (_wasteTypeHasError) ...[
          const SizedBox(height: 8),
          const Text(
            "Selecione ao menos um tipo de resíduo aceito.",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.warningText,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHoursSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        _buildFieldLabel("Horário de funcionamento"),
        const SizedBox(height: 6),

        for (final _Weekday day in _Weekday.values)
          OpeningHoursRow(
            dayLabel: day.label,
            isOpen: _schedules[day]!.isOpen,
            opensAt: _schedules[day]!.opensAt,
            closesAt: _schedules[day]!.closesAt,
            onToggleOpen: () => _toggleDay(day),
            onOpeningTap: () => _pickTime(day, isOpening: true),
            onClosingTap: () => _pickTime(day, isOpening: false),
          ),

        Align(
          alignment: Alignment.centerRight,

          child: Tooltip(
            message: "Replicar horário para todos os dias",
            child: TextButton(
              onPressed: _replicateSchedule,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.content_copy_rounded, size: 16),
                  SizedBox(width: 6),

                  Flexible(
                    child: Text(
                      "Replicar horário para todos os dias",
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        if (_hoursHasError && _hoursErrorMessage != null) ...[
          const SizedBox(height: 4),
          Text(
            _hoursErrorMessage!,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.warningText,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSubmitButton() {
    return FilledButton(
      onPressed: _isSubmitting ? null : _submitForm,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),

      child: _isSubmitting
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          : const Text("Enviar sugestão"),
    );
  }

  Widget _buildAnonymousFootnote() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,

      children: [
        Icon(
          Icons.lock_outline_rounded,
          size: 14,
          color: AppColors.textSecondary,
        ),
        SizedBox(width: 6),

        Flexible(
          child: Text(
            "Envio estritamente anônimo. Nenhum dado pessoal é coletado.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.35,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}


// Classes ------------------------------------------------------------------ //


class _DaySchedule {
  _DaySchedule({
    required this.isOpen,
    required this.opensAt,
    required this.closesAt,
  });

  bool isOpen;
  TimeOfDay opensAt;
  TimeOfDay closesAt;
}
