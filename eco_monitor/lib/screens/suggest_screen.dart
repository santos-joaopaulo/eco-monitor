import "dart:async";

import "package:flutter/material.dart";

import "../data/app_data_sync.dart";
import "../data/point_suggestions_repository.dart";
import "../models/collection_point.dart";
import "../models/point_suggestion.dart";
import "../services/location_service.dart";
import "../theme/app_colors.dart";
import "../theme/eco_theme.dart";
import "../widgets/custom_bottom_nav_bar.dart";
import "../widgets/waste_style.dart";


// Classes ----------------------------------------------------------------- //


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
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _hoursController = TextEditingController();

  final Set<WasteType> _selectedWasteTypes = <WasteType>{};

  double? _latitude;
  double? _longitude;
  bool _isLocating = false;
  bool _isSubmitting = false;
  bool _wasteTypeHasError = false;


  // Init ------------------------------------------------------------------ //


  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _hoursController.dispose();
    super.dispose();
  }


  // Methods --------------------------------------------------------------- //


  Future<void> _captureLocation() async {
    setState(() {
      _isLocating = true;
    });

    try {
      final UserLocation? location =
          await widget.locationService.currentPosition();

      if (!mounted) {
        return;
      }

      if (location != null) {
        setState(() {
          _latitude = location.latitude;
          _longitude = location.longitude;
        });

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text("Coordenadas GPS capturadas com sucesso!"),
              backgroundColor: AppColors.primaryAccessible,
              duration: Duration(seconds: 2),
            ),
          );
      } else {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                "Não foi possível obter a localização do aparelho.",
              ),
              duration: Duration(seconds: 3),
            ),
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

  Future<void> _submitForm() async {
    final bool isFormValid = _formKey.currentState?.validate() ?? false;
    final bool hasWasteTypes = _selectedWasteTypes.isNotEmpty;

    setState(() {
      _wasteTypeHasError = !hasWasteTypes;
    });

    if (!isFormValid || !hasWasteTypes || _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final PointSuggestion suggestion = PointSuggestion(
      id: "",
      name: _nameController.text.trim(),
      address: _addressController.text.trim(),
      acceptedWasteTypes: _selectedWasteTypes,
      hours: _hoursController.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
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
        _hoursController.clear();
        _selectedWasteTypes.clear();
        _latitude = null;
        _longitude = null;
        _wasteTypeHasError = false;
        _formKey.currentState?.reset();
      });

      final String message = result == SuggestionSubmitResult.sent
          ? "Sugestão enviada com sucesso! Obrigado por colaborar."
          : "Sugestão salva na fila offline. Será enviada assim que houver conexão.";

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.primaryAccessible,
            duration: const Duration(seconds: 4),
          ),
        );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text("Ocorreu um erro ao enviar. Tente novamente."),
            duration: Duration(seconds: 3),
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }


  // Build ----------------------------------------------------------------- //


  @override
  Widget build(BuildContext context) {
    final double bottomInset =
        CustomBottomNavBar.reservedBottomInset(context) + 24;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kEcoMaxContentWidth),

        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            kEcoContentHorizontalPadding,
            16,
            kEcoContentHorizontalPadding,
            bottomInset,
          ),

          child: Form(
            key: _formKey,

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildAnonymousNotice(),
                const SizedBox(height: 20),

                _buildNameField(),
                const SizedBox(height: 16),

                _buildAddressField(),
                if (_latitude != null && _longitude != null) ...[
                  const SizedBox(height: 8),
                  _buildCoordinatesBadge(),
                ],
                const SizedBox(height: 20),

                _buildWasteTypeSection(),
                const SizedBox(height: 20),

                _buildHoursField(),
                const SizedBox(height: 28),

                _buildSubmitButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnonymousNotice() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        borderRadius: BorderRadius.circular(16),
      ),

      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 22,
            color: AppColors.primaryAccessible,
          ),
          SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Envio estritamente anônimo",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryAccessible,
                  ),
                ),
                SizedBox(height: 4),

                Text(
                  "Não coletamos nem enviamos nenhum dado pessoal, de conta ou identificador do dispositivo.",
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: "Nome do local *",
        hintText: "Ex.: Farmácia Popular Central",
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.timelineLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.timelineLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.primaryAccessible,
            width: 1.5,
          ),
        ),
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

  Widget _buildAddressField() {
    return TextFormField(
      controller: _addressController,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: "Endereço completo *",
        hintText: "Ex.: Rua das Flores, 123 - Bairro Centro",
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.timelineLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.timelineLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.primaryAccessible,
            width: 1.5,
          ),
        ),
        suffixIcon: IconButton(
          tooltip: "Preencher com localização atual (GPS)",
          icon: _isLocating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(
                  Icons.my_location_rounded,
                  color: AppColors.primaryAccessible,
                ),
          onPressed: _isLocating ? null : _captureLocation,
        ),
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

  Widget _buildCoordinatesBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        borderRadius: BorderRadius.circular(8),
      ),

      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 16,
            color: AppColors.primaryAccessible,
          ),
          const SizedBox(width: 6),

          Expanded(
            child: Text(
              "GPS: ${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}",
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryAccessible,
              ),
            ),
          ),

          InkWell(
            onTap: () {
              setState(() {
                _latitude = null;
                _longitude = null;
              });
            },
            child: const Icon(
              Icons.close_rounded,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWasteTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "RESÍDUOS ACEITOS *",
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final WasteType type in WasteType.values)
              FilterChip(
                selected: _selectedWasteTypes.contains(type),
                showCheckmark: false,
                avatar: Icon(
                  type.icon,
                  size: 18,
                  color: _selectedWasteTypes.contains(type)
                      ? Colors.white
                      : type.color,
                ),
                label: Text(type.label),
                labelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _selectedWasteTypes.contains(type)
                      ? Colors.white
                      : AppColors.textPrimary,
                ),
                selectedColor: AppColors.primaryAccessible,
                backgroundColor: AppColors.surface,
                side: BorderSide(
                  color: _selectedWasteTypes.contains(type)
                      ? AppColors.primaryAccessible
                      : AppColors.timelineLine,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                onSelected: (bool selected) {
                  setState(() {
                    if (selected) {
                      _selectedWasteTypes.add(type);
                      _wasteTypeHasError = false;
                    } else {
                      _selectedWasteTypes.remove(type);
                    }
                  });
                },
              ),
          ],
        ),

        if (_wasteTypeHasError) ...[
          const SizedBox(height: 6),
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

  Widget _buildHoursField() {
    return TextFormField(
      controller: _hoursController,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: "Horário de funcionamento (opcional)",
        hintText: "Ex.: Segunda a Sexta, 08h às 18h",
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.timelineLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.timelineLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.primaryAccessible,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return FilledButton(
      onPressed: _isSubmitting ? null : _submitForm,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primaryAccessible,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
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
}
