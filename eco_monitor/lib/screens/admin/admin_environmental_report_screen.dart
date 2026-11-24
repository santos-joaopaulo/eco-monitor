import "dart:typed_data";

import "package:material_ui/material_ui.dart";
import "package:pdf/pdf.dart";
import "package:printing/printing.dart";

import "../../data/admin_database_repository.dart";
import "../../data/collect_points_repository.dart";
import "../../data/waste_search_analytics_repository.dart";
import "../../domain/entities/collection_point.dart";
import "../../domain/entities/point_suggestion.dart";
import "../../domain/repositories/waste_search_analytics_repository_contract.dart";
import "../../domain/entities/civic_demand_summary.dart";
import "../../services/environmental_pdf_report_service.dart";
import "../../theme/app_colors.dart";
import "../../theme/eco_theme.dart";


// Classes ------------------------------------------------------------------ //


/// Tela de visualização, exportação e compartilhamento de Relatórios Ambientais em PDF.
class AdminEnvironmentalReportScreen extends StatefulWidget {
  const AdminEnvironmentalReportScreen({
    super.key,
    this.databaseRepository,
    this.collectPointsRepository,
    this.analyticsRepository,
    this.initialPoints,
    this.initialSuggestions,
    this.initialSearchStats,
    this.initialNeighborhood,
    this.reportService,
  });

  final AdminDatabaseRepository? databaseRepository;
  final CollectPointsRepository? collectPointsRepository;
  final IWasteSearchAnalyticsRepository? analyticsRepository;
  final List<CollectionPoint>? initialPoints;
  final List<PointSuggestion>? initialSuggestions;
  final List<WasteSearchStat>? initialSearchStats;
  final String? initialNeighborhood;
  final EnvironmentalPdfReportService? reportService;

  @override
  State<AdminEnvironmentalReportScreen> createState() =>
      _AdminEnvironmentalReportScreenState();
}

class _AdminEnvironmentalReportScreenState
    extends State<AdminEnvironmentalReportScreen> {
  late final EnvironmentalPdfReportService _service;
  late final AdminDatabaseRepository? _databaseRepo;
  late final IWasteSearchAnalyticsRepository _analyticsRepo;

  List<CollectionPoint> _points = const <CollectionPoint>[];
  List<PointSuggestion> _suggestions = const <PointSuggestion>[];
  List<WasteSearchStat> _searchStats = const <WasteSearchStat>[];
  CivicDemandSummary? _civicSummary;

  bool _isLoading = true;
  String? _errorMessage;
  String? _selectedNeighborhood;


// Lifecycle ---------------------------------------------------------------- //


  @override
  void initState() {
    super.initState();
    _service = widget.reportService ?? const EnvironmentalPdfReportService();
    _databaseRepo = widget.databaseRepository;
    _analyticsRepo =
        widget.analyticsRepository ?? WasteSearchAnalyticsRepository();
    _selectedNeighborhood = widget.initialNeighborhood;

    _loadReportData();
  }


// Methods ------------------------------------------------------------------ //


  Future<void> _loadReportData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      List<CollectionPoint> pts = widget.initialPoints ?? const [];
      List<PointSuggestion> sugs = widget.initialSuggestions ?? const [];
      List<WasteSearchStat> stats = widget.initialSearchStats ?? const [];

      if (pts.isEmpty && _databaseRepo != null) {
        pts = await _databaseRepo.fetchPoints();
      } else if (pts.isEmpty && widget.collectPointsRepository != null) {
        pts = await widget.collectPointsRepository!.loadOffline();
      }

      if (sugs.isEmpty && _databaseRepo != null) {
        sugs = await _databaseRepo.fetchSuggestions();
      }

      if (stats.isEmpty && widget.initialSearchStats == null) {
        try {
          stats = await _analyticsRepo.getRankedStats();
        } catch (_) {
          stats = const <WasteSearchStat>[];
        }
      }

      final CivicDemandSummary summary = CivicDemandSummary.fromData(
        suggestions: sugs,
        existingPoints: pts,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _points = pts;
        _suggestions = sugs;
        _searchStats = stats;
        _civicSummary = summary;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = "Erro ao carregar dados do relatório: $e";
        _isLoading = false;
      });
    }
  }

  Future<Uint8List> _generatePdf(PdfPageFormat format) {
    final CivicDemandSummary summary =
        _civicSummary ??
        CivicDemandSummary.fromData(
          suggestions: _suggestions,
          existingPoints: _points,
        );

    return _service.generateReportPdf(
      points: _points,
      civicSummary: summary,
      searchStats: _searchStats,
      filterNeighborhood: _selectedNeighborhood,
    );
  }

  String _pdfFileName() {
    final String dateSuffix =
        "${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, "0")}${DateTime.now().day.toString().padLeft(2, "0")}";
    if (_selectedNeighborhood != null &&
        _selectedNeighborhood!.trim().isNotEmpty) {
      final String safeNeighborhood = _selectedNeighborhood!
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r"[^a-z0-9]"), "_");
      return "relatorio_ambiental_${safeNeighborhood}_$dateSuffix.pdf";
    }
    return "relatorio_ambiental_geral_$dateSuffix.pdf";
  }

  void _onSelectNeighborhood(String? neighborhood) {
    setState(() {
      _selectedNeighborhood = neighborhood;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<String> availableNeighborhoods =
        _civicSummary?.neighborhoodDemands
            .map((NeighborhoodCivicDemand d) => d.neighborhood)
            .toList() ??
        const <String>[];

    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,

        title: const Text(
          "RELATÓRIO AMBIENTAL",
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),

        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_alt_rounded),
            tooltip: "Filtrar Abrangência Territorial",
            initialValue: _selectedNeighborhood,
            onSelected: _onSelectNeighborhood,
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem<String?>(
                  value: null,
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_city_rounded,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text("Todo o Município (Geral)"),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                for (final String n in availableNeighborhoods)
                  PopupMenuItem<String?>(
                    value: n,
                    child: Text(n),
                  ),
              ];
            },
          ),
        ],
      ),

      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : _errorMessage != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),

                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 48,
                        color: AppColors.warningText,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.warningText),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadReportData,
                        child: const Text("Tentar novamente"),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                children: [
                  // Faixa de seleção de abrangência atual
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: kEcoContentHorizontalPadding,
                      vertical: 10,
                    ),
                    color: AppColors.primaryTint,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: kEcoMaxContentWidth,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,

                          children: [
                            Expanded(
                              child: Text(
                                _selectedNeighborhood != null
                                    ? "Abrangência: Bairro ${_selectedNeighborhood!}"
                                    : "Abrangência: Todo o Município de Aracaju/SE",
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryAccessible,
                                ),
                              ),
                            ),
                            if (_selectedNeighborhood != null)
                              TextButton(
                                onPressed: () => _onSelectNeighborhood(null),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  "Ver Geral",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Área do PdfPreview
                  Expanded(
                    child: PdfPreview(
                      build: _generatePdf,
                      initialPageFormat: PdfPageFormat.a4,
                      canChangePageFormat: false,
                      canChangeOrientation: false,
                      pdfFileName: _pdfFileName(),
                      previewPageMargin: const EdgeInsets.all(12),
                      loadingWidget: const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                      actions: [
                        PdfPreviewAction(
                          icon: const Icon(Icons.share_rounded),
                          onPressed: (
                            BuildContext context,
                            LayoutCallback build,
                            PdfPageFormat pageFormat,
                          ) async {
                            final Uint8List bytes = await build(pageFormat);
                            await Printing.sharePdf(
                              bytes: bytes,
                              filename: _pdfFileName(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
