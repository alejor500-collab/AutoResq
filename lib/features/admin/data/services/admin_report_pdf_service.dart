import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class AdminReportPdfService {
  const AdminReportPdfService();

  Future<void> openReportPdf({
    required Map<String, dynamic> reportData,
    required String appName,
    String? adminName,
  }) async {
    final bytes = await generateReportPdf(
      reportData: reportData,
      appName: appName,
      adminName: adminName,
    );
    final fileName = _buildFileName(reportData['report_type']?.toString());
    await Printing.layoutPdf(
      name: fileName,
      onLayout: (_) async => bytes,
    );
  }

  Future<Uint8List> generateReportPdf({
    required Map<String, dynamic> reportData,
    required String appName,
    String? adminName,
  }) async {
    final rows = List<Map<String, dynamic>>.from(
      (reportData['rows'] as List? ?? const []).map(
        (item) => Map<String, dynamic>.from(item as Map),
      ),
    );
    if (rows.isEmpty) {
      throw StateError('No existen datos para exportar en el reporte.');
    }

    final summary = Map<String, dynamic>.from(
      reportData['summary'] as Map? ?? const <String, dynamic>{},
    );
    final filters = Map<String, dynamic>.from(
      reportData['filters'] as Map? ?? const <String, dynamic>{},
    );
    final reportTitle = reportData['report_type']?.toString() ?? 'Reporte';
    final columns = _columnsFor(reportTitle);
    final pageFormat = _isWideReport(columns.length)
        ? PdfPageFormat.a4.landscape
        : PdfPageFormat.a4;

    final regularFont = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();
    final logo = await _loadLogoOrNull();
    final generatedAt = _formatDateTime(
      reportData['generated_at']?.toString(),
    );

    final document = pw.Document(
      title: '$appName - $reportTitle',
      author: adminName ?? appName,
      subject: 'Reporte administrativo',
      creator: appName,
    );

    document.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 40),
          theme: pw.ThemeData.withFont(
            base: regularFont,
            bold: boldFont,
          ),
        ),
        header: (context) => _buildHeader(
          logo: logo,
          appName: appName,
          reportTitle: reportTitle,
          generatedAt: generatedAt,
          adminName: adminName,
          isFirstPage: context.pageNumber == 1,
        ),
        footer: _buildFooter,
        build: (_) => [
          _buildExecutiveSummary(summary, rows.length),
          if (filters.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            _buildFiltersBlock(filters),
          ],
          pw.SizedBox(height: 18),
          _buildSectionTitle('Detalle principal'),
          pw.SizedBox(height: 10),
          _buildMainTable(columns, rows),
        ],
      ),
    );

    return document.save();
  }

  Future<pw.MemoryImage?> _loadLogoOrNull() async {
    try {
      final data = await rootBundle.load('assets/images/autoresq_logo.png');
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  String _buildFileName(String? reportType) {
    final slug = (reportType ?? 'reporte')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    return 'autoresq_${slug.isEmpty ? 'reporte' : slug}_$stamp.pdf';
  }

  String _formatDateTime(String? raw) {
    final date = DateTime.tryParse(raw ?? '');
    final value = date ?? DateTime.now();
    return DateFormat('dd/MM/yyyy HH:mm').format(value.toLocal());
  }

  bool _isWideReport(int columnCount) => columnCount >= 7;

  pw.Widget _buildHeader({
    required pw.MemoryImage? logo,
    required String appName,
    required String reportTitle,
    required String generatedAt,
    required String? adminName,
    required bool isFirstPage,
  }) {
    return pw.Container(
      margin: pw.EdgeInsets.only(bottom: isFirstPage ? 18 : 10),
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFDCE4F2), width: 1),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 62,
            height: 62,
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF5F8FD),
              borderRadius: pw.BorderRadius.circular(16),
            ),
            child: logo != null
                ? pw.Image(logo, fit: pw.BoxFit.contain)
                : pw.Center(
                    child: pw.Text(
                      appName,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromInt(0xFF17233F),
                      ),
                    ),
                  ),
          ),
          pw.SizedBox(width: 14),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  appName,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xFF17233F),
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  reportTitle,
                  style: pw.TextStyle(
                    fontSize: 21,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xFF2350D8),
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _metaText('Generado: $generatedAt'),
                    if (adminName != null && adminName.trim().isNotEmpty)
                      _metaText('Administrador: ${adminName.trim()}'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _metaText(String text) {
    return pw.Text(
      text,
      style: const pw.TextStyle(
        fontSize: 9.5,
        color: PdfColor.fromInt(0xFF5D6777),
      ),
    );
  }

  pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColor.fromInt(0xFFE4EAF4), width: 1),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Reporte generado automáticamente por AutoResQ',
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColor.fromInt(0xFF707785),
            ),
          ),
          pw.Text(
            'Página ${context.pageNumber}',
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColor.fromInt(0xFF707785),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildExecutiveSummary(
    Map<String, dynamic> summary,
    int totalRows,
  ) {
    final cards = <Map<String, String>>[
      {'title': 'Total de registros', 'value': totalRows.toString()},
      ..._flattenSummary(summary),
    ].take(6).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Resumen ejecutivo'),
        pw.SizedBox(height: 10),
        pw.Wrap(
          spacing: 10,
          runSpacing: 10,
          children: cards.map((item) {
            return pw.Container(
              width: 160,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF7F9FD),
                borderRadius: pw.BorderRadius.circular(14),
                border: pw.Border.all(color: PdfColor.fromInt(0xFFDCE5F1)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    item['title'] ?? '',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColor.fromInt(0xFF6A7280),
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    item['value'] ?? '',
                    maxLines: 3,
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(0xFF17233F),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  List<Map<String, String>> _flattenSummary(Map<String, dynamic> summary) {
    final items = <Map<String, String>>[];
    summary.forEach((key, value) {
      if (value == null) return;
      if (value is Map && value.isEmpty) return;
      if (value is List && value.isEmpty) return;
      items.add({
        'title': _humanizeKey(key),
        'value': _summaryValue(value),
      });
    });
    return items;
  }

  String _summaryValue(dynamic value) {
    if (value is num) {
      return value is double ? value.toStringAsFixed(2) : value.toString();
    }
    if (value is Map) {
      return value.entries.map((e) => '${e.key}: ${e.value}').join(' | ');
    }
    if (value is List) {
      return value.take(3).map((item) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          final label = map['label']?.toString() ??
              map['nombre']?.toString() ??
              map['especialidad']?.toString() ??
              map['title']?.toString() ??
              'item';
          final count = map['count']?.toString();
          final rating = map['calificacion_promedio']?.toString();
          if (count != null) return '$label ($count)';
          if (rating != null) return '$label ($rating)';
          return label;
        }
        return item.toString();
      }).join(' | ');
    }
    return value.toString();
  }

  pw.Widget _buildFiltersBlock(Map<String, dynamic> filters) {
    final entries = filters.entries.where((entry) {
      final value = entry.value;
      if (value == null) return false;
      if (value is Map) return value.isNotEmpty;
      if (value is String) return value.trim().isNotEmpty;
      return true;
    }).toList();
    if (entries.isEmpty) return pw.SizedBox.shrink();

    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFFAFBFD),
        borderRadius: pw.BorderRadius.circular(16),
        border: pw.Border.all(color: PdfColor.fromInt(0xFFE5EBF5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Filtros aplicados',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromInt(0xFF182744),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Wrap(
            spacing: 8,
            runSpacing: 8,
            children: entries.map((entry) {
              return pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFF1F5FB),
                  borderRadius: pw.BorderRadius.circular(999),
                ),
                child: pw.Text(
                  '${_humanizeKey(entry.key)}: ${_filterValue(entry.value)}',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColor.fromInt(0xFF475264),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _filterValue(dynamic value) {
    if (value is Map) {
      return value.entries
          .map((e) => '${_humanizeKey(e.key)} ${_formatMaybeDate(e.value)}')
          .join(' - ');
    }
    return _formatMaybeDate(value);
  }

  String _formatMaybeDate(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return value?.toString() ?? '';
    return DateFormat('dd/MM/yyyy').format(parsed.toLocal());
  }

  pw.Widget _buildSectionTitle(String title) {
    return pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: 14,
        fontWeight: pw.FontWeight.bold,
        color: PdfColor.fromInt(0xFF17233F),
      ),
    );
  }

  pw.Widget _buildMainTable(
    List<_PdfColumn> columns,
    List<Map<String, dynamic>> rows,
  ) {
    final data = rows.map((row) {
      return columns.map((column) {
        final maxLength = column.flex <= 1.0 ? 24 : 42;
        return _truncate(row[column.key], max: maxLength);
      }).toList();
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: columns.map((column) => column.label).toList(),
      data: data,
      headerDecoration: const pw.BoxDecoration(
        color: PdfColor.fromInt(0xFF2350D8),
      ),
      headerStyle: pw.TextStyle(
        color: PdfColors.white,
        fontWeight: pw.FontWeight.bold,
        fontSize: 9.4,
      ),
      cellStyle: const pw.TextStyle(
        fontSize: 8.5,
        color: PdfColor.fromInt(0xFF1F2B3F),
      ),
      cellAlignments: {
        for (var i = 0; i < columns.length; i++) i: pw.Alignment.centerLeft,
      },
      columnWidths: {
        for (var i = 0; i < columns.length; i++)
          i: pw.FlexColumnWidth(columns[i].flex),
      },
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFE6EBF4), width: .5),
        ),
      ),
      oddRowDecoration: const pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFF9FBFE),
      ),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 7),
      border: null,
    );
  }

  List<_PdfColumn> _columnsFor(String reportTitle) {
    switch (reportTitle) {
      case 'Usuarios':
        return const [
          _PdfColumn('nombre', 'Nombre', 1.4),
          _PdfColumn('correo', 'Correo', 1.8),
          _PdfColumn('rol', 'Rol', 1.0),
          _PdfColumn('estado_cuenta', 'Estado', 1.1),
          _PdfColumn('fecha_registro', 'Registro', 1.2),
          _PdfColumn('ultimo_acceso', 'Último acceso', 1.2),
        ];
      case 'Técnicos':
        return const [
          _PdfColumn('nombre', 'Nombre', 1.4),
          _PdfColumn('correo', 'Correo', 1.8),
          _PdfColumn('especialidad', 'Especialidad', 1.2),
          _PdfColumn('estado_aprobacion', 'Aprobación', 1.1),
          _PdfColumn('disponibilidad', 'Disponibilidad', 1.1),
          _PdfColumn('servicios_atendidos', 'Servicios', 0.9),
          _PdfColumn('calificacion_promedio', 'Rating', 0.9),
          _PdfColumn('ubicacion_aproximada', 'Ubicación', 1.4),
        ];
      case 'Solicitudes':
        return const [
          _PdfColumn('id_solicitud', 'Código', 0.9),
          _PdfColumn('conductor_solicitante', 'Conductor', 1.2),
          _PdfColumn('tecnico_asignado', 'Técnico', 1.2),
          _PdfColumn('tipo_problema_vehicular', 'Problema', 1.2),
          _PdfColumn('estado_solicitud', 'Estado', 0.9),
          _PdfColumn('fecha_creacion', 'Creación', 1.1),
          _PdfColumn('fecha_aceptacion', 'Aceptación', 1.1),
          _PdfColumn('fecha_cierre', 'Cierre', 1.0),
          _PdfColumn('tiempo_respuesta_minutos', 'Resp. min', 0.8),
          _PdfColumn('ubicacion_zona', 'Zona', 1.1),
          _PdfColumn('cuota_referencial', 'Cuota', 0.8),
          _PdfColumn('metodo_pago', 'Pago', 0.9),
        ];
      case 'Calificaciones':
        return const [
          _PdfColumn('usuario_que_califica', 'Califica', 1.2),
          _PdfColumn('usuario_calificado', 'Calificado', 1.2),
          _PdfColumn('rol_usuario_calificado', 'Rol', 0.9),
          _PdfColumn('puntuacion', 'Puntuación', 0.8),
          _PdfColumn('comentario', 'Comentario', 2.0),
          _PdfColumn('fecha', 'Fecha', 1.0),
        ];
      case 'Desempeño operativo':
        return const [
          _PdfColumn('title', 'Indicador', 1.4),
          _PdfColumn('value', 'Valor', 1.0),
          _PdfColumn('subtitle', 'Detalle', 2.0),
        ];
      case 'Diagnósticos IA':
        return const [
          _PdfColumn('descripcion_conductor', 'Descripción', 1.8),
          _PdfColumn('diagnostico_generado_ia', 'Diagnóstico IA', 2.0),
          _PdfColumn('categoria_detectada', 'Categoría', 1.0),
          _PdfColumn('especialidad_sugerida', 'Especialidad', 1.1),
          _PdfColumn('cuota_referencial_sugerida', 'Cuota', 0.9),
          _PdfColumn('solicitud_asociada', 'Solicitud', 0.9),
          _PdfColumn('fecha_generacion', 'Fecha', 1.0),
        ];
      default:
        return const [
          _PdfColumn('title', 'Dato', 1.2),
          _PdfColumn('value', 'Valor', 1.8),
        ];
    }
  }

  String _truncate(dynamic value, {int max = 42}) {
    final text = value?.toString() ?? '—';
    final compact = text.replaceAll('\n', ' ').trim();
    if (compact.isEmpty) return '—';
    if (compact.length <= max) return compact;
    return '${compact.substring(0, max - 1)}…';
  }

  String _humanizeKey(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}

class _PdfColumn {
  final String key;
  final String label;
  final double flex;

  const _PdfColumn(this.key, this.label, this.flex);
}
