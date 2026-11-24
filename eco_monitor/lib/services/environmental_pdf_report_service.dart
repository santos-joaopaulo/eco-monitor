import "dart:typed_data";

import "package:pdf/pdf.dart";
import "package:pdf/widgets.dart" as pw;

import "../domain/entities/collection_point.dart";
import "../domain/entities/waste_type.dart";
import "../domain/repositories/waste_search_analytics_repository_contract.dart";
import "../models/civic_demand_summary.dart";


// Constantes de Design PDF (mapeadas estritamente de AppColors) ------------- //


const PdfColor _pdfPrimary = PdfColor.fromInt(0xFF58A29D);
const PdfColor _pdfPrimaryDark = PdfColor.fromInt(0xFF2F746E);
const PdfColor _pdfPrimaryTint = PdfColor.fromInt(0xFFE6F4F1);
const PdfColor _pdfSurfaceSection = PdfColor.fromInt(0xFFEEF1F1);
const PdfColor _pdfTextPrimary = PdfColor.fromInt(0xFF1C2B2A);
const PdfColor _pdfTextSecondary = PdfColor.fromInt(0xFF7A8886);
const PdfColor _pdfOutline = PdfColor.fromInt(0xFFDFE6E5);
const PdfColor _pdfWarningText = PdfColor.fromInt(0xFF9B1C1C);
const PdfColor _pdfWarningBackground = PdfColor.fromInt(0xFFFDE2E2);
const PdfColor _pdfActive = PdfColor.fromInt(0xFF58A29D);
const PdfColor _pdfInactive = PdfColor.fromInt(0xFF9CA3AF);


// Classes ----------------------------------------------------------------- //


/// Serviço de geração de relatórios oficiais em formato PDF sobre impacto ambiental,
/// infraestrutura municipal de pontos de coleta e diagnóstico cívico territorial.
class EnvironmentalPdfReportService {
  const EnvironmentalPdfReportService();


  // Methods --------------------------------------------------------------- //


  /// Gera o arquivo PDF formatado para padrão A4 em formato de bytes (`Uint8List`).
  Future<Uint8List> generateReportPdf({
    required List<CollectionPoint> points,
    required CivicDemandSummary civicSummary,
    List<WasteSearchStat> searchStats = const <WasteSearchStat>[],
    String? filterNeighborhood,
    DateTime? issuedAt,
    pw.Font? baseFont,
    pw.Font? boldFont,
  }) async {
    final pw.Document doc = buildReportDocument(
      points: points,
      civicSummary: civicSummary,
      searchStats: searchStats,
      filterNeighborhood: filterNeighborhood,
      issuedAt: issuedAt,
      baseFont: baseFont,
      boldFont: boldFont,
    );

    return doc.save();
  }

  /// Constrói a estrutura do documento `pw.Document` para visualização ou persistência.
  pw.Document buildReportDocument({
    required List<CollectionPoint> points,
    required CivicDemandSummary civicSummary,
    List<WasteSearchStat> searchStats = const <WasteSearchStat>[],
    String? filterNeighborhood,
    DateTime? issuedAt,
    pw.Font? baseFont,
    pw.Font? boldFont,
  }) {
    final DateTime issueDate = issuedAt ?? DateTime.now();
    final pw.Document doc = pw.Document(
      title: "Relatório Ambiental e Territorial de Gestão Cívica",
      author: "EcoMonitor Aracaju",
      creator: "EcoMonitor",
    );

    final pw.ThemeData theme = pw.ThemeData.withFont(
      base: baseFont,
      bold: boldFont,
    );

    // Métricas ecológicas e de infraestrutura
    final int totalPoints = points.length;
    final int activePoints = points.where((CollectionPoint p) => p.isActive).length;
    final int inactivePoints = totalPoints - activePoints;

    final int pharmacyCount =
        points.where((CollectionPoint p) => p.type == PointType.pharmacy).length;
    final int pharmacyActive = points
        .where((CollectionPoint p) => p.type == PointType.pharmacy && p.isActive)
        .length;

    final int healthCenterCount = points
        .where((CollectionPoint p) => p.type == PointType.healthCenter)
        .length;
    final int healthCenterActive = points
        .where(
          (CollectionPoint p) =>
              p.type == PointType.healthCenter && p.isActive,
        )
        .length;

    final int ecoPointCount =
        points.where((CollectionPoint p) => p.type == PointType.ecoPoint).length;
    final int ecoPointActive = points
        .where((CollectionPoint p) => p.type == PointType.ecoPoint && p.isActive)
        .length;

    // Resíduos aceitos em pontos ativos
    final int activeMedicines = points
        .where(
          (CollectionPoint p) =>
              p.isActive && p.accepts(WasteType.medicines),
        )
        .length;
    final int activeBatteries = points
        .where(
          (CollectionPoint p) =>
              p.isActive && p.accepts(WasteType.batteries),
        )
        .length;
    final int activeSharps = points
        .where(
          (CollectionPoint p) => p.isActive && p.accepts(WasteType.sharps),
        )
        .length;
    final int activeElectronics = points
        .where(
          (CollectionPoint p) =>
              p.isActive && p.accepts(WasteType.electronics),
        )
        .length;
    final int activeGlass = points
        .where((CollectionPoint p) => p.isActive && p.accepts(WasteType.glass))
        .length;

    // Estimativas de impacto ambiental
    // - Remédios: 1 kg descarta incorretamente contamina até 450.000 L de água subterrânea.
    //   Cada ponto ativo estima 450.000 litros preservados por ciclo mensal.
    final int preservedWaterLiters = activeMedicines * 450000;
    // - Pilhas: contenção de metais pesados tóxicos (chumbo, cádmio, mercúrio)
    final int preventedMetalsKg = activeBatteries * 25;
    // - Perfurocortantes: biossegurança para agentes de limpeza e catadores
    final int sharpsSafePoints = activeSharps;

    final String scopeLabel = filterNeighborhood != null &&
            filterNeighborhood.trim().isNotEmpty
        ? "Abrangência: Bairro ${filterNeighborhood.trim()}"
        : "Abrangência: Todo o Município de Aracaju/SE";

    final String docId = _generateDocumentId(issueDate, filterNeighborhood);

    doc.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) => _buildHeader(
          issueDate: issueDate,
          scopeLabel: scopeLabel,
        ),
        footer: (pw.Context context) => _buildFooter(
          context: context,
          documentId: docId,
        ),
        build: (pw.Context context) {
          return [
            pw.SizedBox(height: 8),

            // Seção 1: Sumário Executivo de Impacto Ambiental
            _buildSectionTitle("1. SUMÁRIO EXECUTIVO DE IMPACTO ECOLÓGICO"),
            pw.SizedBox(height: 6),
            pw.Text(
              "Estimativas calculadas com base nos pontos de coleta cadastrados e ativos no município, "
              "considerando coeficientes técnicos de biossegurança e prevenção de contaminação hídrica:",
              style: const pw.TextStyle(
                fontSize: 9.5,
                color: _pdfTextSecondary,
              ),
            ),
            pw.SizedBox(height: 10),

            _buildImpactCardsGrid(
              preservedWaterLiters: preservedWaterLiters,
              preventedMetalsKg: preventedMetalsKg,
              sharpsSafePoints: sharpsSafePoints,
              activePoints: activePoints,
            ),
            pw.SizedBox(height: 16),

            // Seção 2: Métricas de Infraestrutura
            _buildSectionTitle("2. PANORAMA DA INFRAESTRUTURA DE COLETA"),
            pw.SizedBox(height: 8),
            _buildInfrastructureTable(
              pharmacyActive: pharmacyActive,
              pharmacyTotal: pharmacyCount,
              healthCenterActive: healthCenterActive,
              healthCenterTotal: healthCenterCount,
              ecoPointActive: ecoPointActive,
              ecoPointTotal: ecoPointCount,
              activePoints: activePoints,
              inactivePoints: inactivePoints,
              totalPoints: totalPoints,
            ),
            pw.SizedBox(height: 10),
            _buildAcceptedMaterialsGrid(
              medicines: activeMedicines,
              batteries: activeBatteries,
              sharps: activeSharps,
              electronics: activeElectronics,
              glass: activeGlass,
              activePoints: activePoints,
            ),
            pw.SizedBox(height: 16),

            // Seção 3: Estatísticas Cívicas de Demanda e Pesquisa
            _buildSectionTitle("3. ESTATÍSTICAS CÍVICAS DE DEMANDA POPULAR"),
            pw.SizedBox(height: 8),
            _buildCivicDemandOverview(civicSummary: civicSummary),
            pw.SizedBox(height: 10),
            if (searchStats.isNotEmpty) ...[
              pw.Text(
                "Resíduos Mais Consultados no Aplicativo pelos Cidadãos:",
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: _pdfTextPrimary,
                ),
              ),
              pw.SizedBox(height: 6),
              _buildSearchStatsTable(searchStats),
              pw.SizedBox(height: 16),
            ],

            // Seção 4: Seção Territorial de Carência
            _buildSectionTitle(
              filterNeighborhood != null
                  ? "4. DIAGNÓSTICO TERRITORIAL: ${filterNeighborhood.toUpperCase()}"
                  : "4. DIAGNÓSTICO DE CARÊNCIA TERRITORIAL POR BAIRRO",
            ),
            pw.SizedBox(height: 8),
            if (filterNeighborhood != null)
              _buildSingleNeighborhoodDetails(
                neighborhood: filterNeighborhood,
                civicSummary: civicSummary,
                points: points,
              )
            else
              _buildTerritorialDemandsTable(
                neighborhoodDemands: civicSummary.neighborhoodDemands,
              ),
            pw.SizedBox(height: 14),

            // Nota Técnica e Governança
            _buildGovernanceNotice(),
          ];
        },
      ),
    );

    return doc;
  }


  // Layout Helper Widgets ------------------------------------------------- //


  pw.Widget _buildHeader({
    required DateTime issueDate,
    required String scopeLabel,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: _pdfPrimary, width: 2),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: pw.BoxDecoration(
                        color: _pdfPrimary,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        "EcoMonitor",
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Text(
                      "Município de Aracaju / SE",
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: _pdfTextSecondary,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  "Relatório Ambiental e Territorial de Gestão Cívica",
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: _pdfTextPrimary,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  scopeLabel,
                  style: const pw.TextStyle(
                    fontSize: 9.5,
                    color: _pdfPrimaryDark,
                  ),
                ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                "Emissão Oficial",
                style: const pw.TextStyle(
                  fontSize: 8.5,
                  color: _pdfTextSecondary,
                ),
              ),
              pw.Text(
                _formatDateTime(issueDate),
                style: pw.TextStyle(
                  fontSize: 9.5,
                  fontWeight: pw.FontWeight.bold,
                  color: _pdfTextPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter({
    required pw.Context context,
    required String documentId,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: _pdfOutline, width: 0.8),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Text(
              "EcoMonitor Aracaju · O descarte correto protege o lençol freático e salva vidas. | $documentId",
              style: const pw.TextStyle(
                fontSize: 7.5,
                color: _pdfTextSecondary,
              ),
            ),
          ),
          pw.Text(
            "Página ${context.pageNumber} de ${context.pagesCount}",
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: _pdfPrimaryDark,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSectionTitle(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const pw.BoxDecoration(
        color: _pdfPrimaryTint,
        border: pw.Border(
          left: pw.BorderSide(color: _pdfPrimary, width: 3),
        ),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 10.5,
          fontWeight: pw.FontWeight.bold,
          color: _pdfPrimaryDark,
        ),
      ),
    );
  }

  pw.Widget _buildImpactCardsGrid({
    required int preservedWaterLiters,
    required int preventedMetalsKg,
    required int sharpsSafePoints,
    required int activePoints,
  }) {
    return pw.Row(
      children: [
        _buildMetricBox(
          label: "Água Subterrânea Preservada",
          value: "~${_formatNumber(preservedWaterLiters)} L",
          detail: "Proteção contra descarte incorreto de remédios",
          color: _pdfPrimary,
        ),
        pw.SizedBox(width: 8),
        _buildMetricBox(
          label: "Metais Pesados Mitigados",
          value: "~${_formatNumber(preventedMetalsKg)} kg",
          detail: "Retenção segura de pilhas e acumuladores",
          color: _pdfPrimaryDark,
        ),
        pw.SizedBox(width: 8),
        _buildMetricBox(
          label: "Pontos com Biossegurança",
          value: "$sharpsSafePoints unidades",
          detail: "Proteção contra acidentes com seringas",
          color: _pdfActive,
        ),
        pw.SizedBox(width: 8),
        _buildMetricBox(
          label: "Ecopontos e Unidades Ativas",
          value: "$activePoints locais",
          detail: "Capacidade instalada em operação",
          color: _pdfPrimaryDark,
        ),
      ],
    );
  }

  pw.Widget _buildMetricBox({
    required String label,
    required String value,
    required String detail,
    required PdfColor color,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: _pdfSurfaceSection,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: _pdfOutline, width: 0.8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: const pw.TextStyle(
                fontSize: 8,
                color: _pdfTextSecondary,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              detail,
              style: const pw.TextStyle(
                fontSize: 7,
                color: _pdfTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildInfrastructureTable({
    required int pharmacyActive,
    required int pharmacyTotal,
    required int healthCenterActive,
    required int healthCenterTotal,
    required int ecoPointActive,
    required int ecoPointTotal,
    required int activePoints,
    required int inactivePoints,
    required int totalPoints,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(color: _pdfOutline, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.5),
        1: pw.FlexColumnWidth(1.2),
        2: pw.FlexColumnWidth(1.2),
        3: pw.FlexColumnWidth(1.2),
        4: pw.FlexColumnWidth(3.0),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _pdfPrimaryTint),
          children: [
            _buildTableHeaderCell("Tipo de Estabelecimento"),
            _buildTableHeaderCell("Ativos"),
            _buildTableHeaderCell("Inativos"),
            _buildTableHeaderCell("Total"),
            _buildTableHeaderCell("Resíduos Prioritários"),
          ],
        ),
        _buildTableRow("Farmácias Credenciadas", "$pharmacyActive", "${pharmacyTotal - pharmacyActive}", "$pharmacyTotal", "Remédios vencidos e perfurocortantes"),
        _buildTableRow("Unidades Básicas de Saúde (UBS)", "$healthCenterActive", "${healthCenterTotal - healthCenterActive}", "$healthCenterTotal", "Medicamentos e seringas"),
        _buildTableRow("Ecopontos Municipais", "$ecoPointActive", "${ecoPointTotal - ecoPointActive}", "$ecoPointTotal", "Eletrônicos, pilhas e vidros"),
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _pdfSurfaceSection),
          children: [
            _buildTableCell("Total Geral Consolidado", isBold: true),
            _buildTableCell("$activePoints", isBold: true, color: _pdfActive),
            _buildTableCell("$inactivePoints", isBold: true, color: _pdfInactive),
            _buildTableCell("$totalPoints", isBold: true),
            _buildTableCell("Rede Integrada de Descarte", isBold: true),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildAcceptedMaterialsGrid({
    required int medicines,
    required int batteries,
    required int sharps,
    required int electronics,
    required int glass,
    required int activePoints,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: _pdfSurfaceSection,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: _pdfOutline, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            "Capacidade de Recebimento por Categoria de Resíduo na Rede Ativa:",
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: _pdfTextPrimary,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildWasteBadge("Remédios", medicines, activePoints),
              _buildWasteBadge("Pilhas", batteries, activePoints),
              _buildWasteBadge("Perfurocortantes", sharps, activePoints),
              _buildWasteBadge("Eletrônicos", electronics, activePoints),
              _buildWasteBadge("Vidro", glass, activePoints),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildWasteBadge(String label, int count, int totalActive) {
    final double pct = totalActive > 0 ? (count / totalActive) * 100.0 : 0.0;
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: _pdfOutline, width: 0.5),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 8, color: _pdfTextSecondary),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            "$count locais (${pct.toStringAsFixed(0)}%)",
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: _pdfPrimaryDark,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildCivicDemandOverview({
    required CivicDemandSummary civicSummary,
  }) {
    return pw.Row(
      children: [
        _buildCivicStatusBox("Total Recebido", "${civicSummary.totalSuggestions}", _pdfTextPrimary),
        pw.SizedBox(width: 8),
        _buildCivicStatusBox("Pendentes de Revisão", "${civicSummary.pendingCount}", _pdfWarningText),
        pw.SizedBox(width: 8),
        _buildCivicStatusBox("Em Análise Técnica", "${civicSummary.reviewingCount}", _pdfPrimaryDark),
        pw.SizedBox(width: 8),
        _buildCivicStatusBox("Aprovados / Implantados", "${civicSummary.approvedCount}", _pdfActive),
        pw.SizedBox(width: 8),
        _buildCivicStatusBox("Rejeitados", "${civicSummary.rejectedCount}", _pdfInactive),
      ],
    );
  }

  pw.Widget _buildCivicStatusBox(String title, String count, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: pw.BoxDecoration(
          color: _pdfSurfaceSection,
          borderRadius: pw.BorderRadius.circular(4),
          border: pw.Border.all(color: _pdfOutline, width: 0.6),
        ),
        child: pw.Column(
          children: [
            pw.Text(
              count,
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              title,
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 7.5, color: _pdfTextSecondary),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildSearchStatsTable(List<WasteSearchStat> stats) {
    return pw.Table(
      border: pw.TableBorder.all(color: _pdfOutline, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.0),
        1: pw.FlexColumnWidth(3.0),
        2: pw.FlexColumnWidth(2.0),
        3: pw.FlexColumnWidth(2.0),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _pdfPrimaryTint),
          children: [
            _buildTableHeaderCell("Rank"),
            _buildTableHeaderCell("Categoria de Resíduo"),
            _buildTableHeaderCell("Consultas"),
            _buildTableHeaderCell("% do Interesse"),
          ],
        ),
        for (int i = 0; i < stats.length; i++)
          pw.TableRow(
            children: [
              _buildTableCell("${i + 1}º", isBold: true),
              _buildTableCell(_wasteTypeName(stats[i].type)),
              _buildTableCell("${stats[i].count}"),
              _buildTableCell("${stats[i].percentage.toStringAsFixed(1)}%"),
            ],
          ),
      ],
    );
  }

  pw.Widget _buildTerritorialDemandsTable({
    required List<NeighborhoodCivicDemand> neighborhoodDemands,
  }) {
    if (neighborhoodDemands.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: _pdfSurfaceSection,
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Center(
          child: pw.Text(
            "Nenhuma solicitação cívica registrada até o momento.",
            style: const pw.TextStyle(fontSize: 9, color: _pdfTextSecondary),
          ),
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: _pdfOutline, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.4),
        1: pw.FlexColumnWidth(1.6),
        2: pw.FlexColumnWidth(1.2),
        3: pw.FlexColumnWidth(1.2),
        4: pw.FlexColumnWidth(2.2),
        5: pw.FlexColumnWidth(1.8),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _pdfPrimaryTint),
          children: [
            _buildTableHeaderCell("Bairro"),
            _buildTableHeaderCell("Carência"),
            _buildTableHeaderCell("Pontos Ativos"),
            _buildTableHeaderCell("Pedidos"),
            _buildTableHeaderCell("Mais Demandado"),
            _buildTableHeaderCell("Status"),
          ],
        ),
        for (final NeighborhoodCivicDemand d in neighborhoodDemands)
          pw.TableRow(
            children: [
              _buildTableCell(d.neighborhood, isBold: true),
              _buildShortageCell(d.shortageLevel, d.shortageLevelLabel),
              _buildTableCell("${d.activePointsCount}"),
              _buildTableCell("${d.totalSuggestions}"),
              _buildTableCell(
                d.topRequestedWaste != null
                    ? "${_wasteTypeName(d.topRequestedWaste!)} (${d.wastePercentage(d.topRequestedWaste!).toStringAsFixed(0)}%)"
                    : "-",
              ),
              _buildTableCell("${d.pendingCount} pendente(s)"),
            ],
          ),
      ],
    );
  }

  pw.Widget _buildSingleNeighborhoodDetails({
    required String neighborhood,
    required CivicDemandSummary civicSummary,
    required List<CollectionPoint> points,
  }) {
    final NeighborhoodCivicDemand? demand = civicSummary.demandFor(neighborhood);
    final String target = neighborhood.trim().toLowerCase();
    final List<CollectionPoint> neighborhoodPoints = points
        .where(
          (CollectionPoint p) =>
              CivicDemandSummary.extractNeighborhood(p.address)
                  .trim()
                  .toLowerCase() ==
              target,
        )
        .toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: _pdfSurfaceSection,
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: _pdfOutline, width: 0.8),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    "Localidade Avaliada: $neighborhood",
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: _pdfTextPrimary,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    "Pontos Ativos Instalados: ${neighborhoodPoints.where((CollectionPoint p) => p.isActive).length} | "
                    "Total de Pedidos Cívicos: ${demand?.totalSuggestions ?? 0}",
                    style: const pw.TextStyle(
                      fontSize: 8.5,
                      color: _pdfTextSecondary,
                    ),
                  ),
                ],
              ),
              if (demand != null)
                _buildShortageBadge(demand.shortageLevel, demand.shortageLevelLabel)
              else
                _buildShortageBadge(ShortageLevel.low, "Sem Carência Registrada"),
            ],
          ),
        ),
        pw.SizedBox(height: 10),

        if (demand != null && demand.rankedWastes.isNotEmpty) ...[
          pw.Text(
            "Distribuição de Resíduos Mais Solicitados neste Bairro:",
            style: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
              color: _pdfTextPrimary,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final CivicWasteDemand item in demand.rankedWastes)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(color: _pdfOutline, width: 0.6),
                  ),
                  child: pw.Text(
                    "${_wasteTypeName(item.type)}: ${item.count} pedido(s) (${item.percentage.toStringAsFixed(0)}%)",
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      color: _pdfPrimaryDark,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          pw.SizedBox(height: 12),
        ],

        if (neighborhoodPoints.isNotEmpty) ...[
          pw.Text(
            "Pontos de Coleta Ativos Instalados no Bairro:",
            style: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
              color: _pdfTextPrimary,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Table(
            border: pw.TableBorder.all(color: _pdfOutline, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(3.0),
              1: pw.FlexColumnWidth(3.5),
              2: pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _pdfPrimaryTint),
                children: [
                  _buildTableHeaderCell("Nome do Ponto"),
                  _buildTableHeaderCell("Endereço"),
                  _buildTableHeaderCell("Situação"),
                ],
              ),
              for (final CollectionPoint p in neighborhoodPoints)
                pw.TableRow(
                  children: [
                    _buildTableCell(p.name, isBold: true),
                    _buildTableCell(p.address),
                    _buildTableCell(
                      p.isActive ? "Ativo" : "Inativo",
                      color: p.isActive ? _pdfActive : _pdfInactive,
                    ),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }

  pw.Widget _buildGovernanceNotice() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: _pdfPrimaryTint,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: _pdfPrimary, width: 0.6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            "Diretriz de Gestão e Planejamento Urbano Sustentável",
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: _pdfPrimaryDark,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            "Os dados consolidados neste documento baseiam-se em apontamentos e fiscalizações da população "
            "e cadastros da administração pública municipal. O descarte adequado de medicamentos, pilhas e frascos de vidro "
            "é regulamentado pela Política Nacional de Resíduos Sólidos (Lei 12.305/2010) e visa resguardar o meio ambiente "
            "e os recursos hídricos de Aracaju.",
            style: const pw.TextStyle(fontSize: 7.8, color: _pdfTextSecondary),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTableHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8.5,
          fontWeight: pw.FontWeight.bold,
          color: _pdfPrimaryDark,
        ),
      ),
    );
  }

  pw.TableRow _buildTableRow(
    String col0,
    String col1,
    String col2,
    String col3,
    String col4,
  ) {
    return pw.TableRow(
      children: [
        _buildTableCell(col0),
        _buildTableCell(col1),
        _buildTableCell(col2),
        _buildTableCell(col3),
        _buildTableCell(col4),
      ],
    );
  }

  pw.Widget _buildTableCell(
    String text, {
    bool isBold = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3.5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? _pdfTextPrimary,
        ),
      ),
    );
  }

  pw.Widget _buildShortageCell(ShortageLevel level, String label) {
    final PdfColor color = switch (level) {
      ShortageLevel.high => _pdfWarningText,
      ShortageLevel.medium => _pdfPrimaryDark,
      ShortageLevel.low => _pdfActive,
    };

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3.5),
      child: pw.Text(
        label,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  pw.Widget _buildShortageBadge(ShortageLevel level, String label) {
    final PdfColor bg = switch (level) {
      ShortageLevel.high => _pdfWarningBackground,
      ShortageLevel.medium => _pdfPrimaryTint,
      ShortageLevel.low => _pdfSurfaceSection,
    };
    final PdfColor text = switch (level) {
      ShortageLevel.high => _pdfWarningText,
      ShortageLevel.medium => _pdfPrimaryDark,
      ShortageLevel.low => _pdfActive,
    };

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: text, width: 0.6),
      ),
      child: pw.Text(
        label,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: text,
        ),
      ),
    );
  }


  // Formatting Helpers ---------------------------------------------------- //


  static String _generateDocumentId(DateTime date, String? neighborhood) {
    final String y = date.year.toString();
    final String m = date.month.toString().padLeft(2, "0");
    final String d = date.day.toString().padLeft(2, "0");
    final String suffix = neighborhood != null && neighborhood.isNotEmpty
        ? neighborhood.trim().toUpperCase().replaceAll(" ", "").substring(0, 3)
        : "GERAL";
    return "DOC-EM-AJU-$y$m$d-$suffix";
  }

  static String _formatDateTime(DateTime dt) {
    final DateTime local = dt.toLocal();
    final String day = local.day.toString().padLeft(2, "0");
    final String month = local.month.toString().padLeft(2, "0");
    final String hour = local.hour.toString().padLeft(2, "0");
    final String minute = local.minute.toString().padLeft(2, "0");
    return "$day/$month/${local.year} às $hour:$minute";
  }

  static String _formatNumber(int number) {
    final String str = number.abs().toString();
    final StringBuffer buf = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buf.write(".");
      }
      buf.write(str[i]);
    }
    return buf.toString();
  }

  static String _wasteTypeName(WasteType type) => switch (type) {
    WasteType.medicines => "Remédios",
    WasteType.batteries => "Pilhas e baterias",
    WasteType.sharps => "Seringas e agulhas",
    WasteType.electronics => "Lixo eletrônico",
    WasteType.glass => "Vidro",
  };
}
