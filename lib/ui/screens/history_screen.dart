import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/storage/data_store.dart';
import '../../domain/measurement.dart';
import '../../domain/spectrum.dart';
import '../../services/app_state.dart';
import '../../services/i18n.dart';
import '../theme/app_theme.dart';
import '../widgets/spectrum_chart.dart';
import 'compare_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _query = '';
  String? _expandedId;
  _HistorySort _sort = _HistorySort.dateDesc;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        return FutureBuilder<List<Measurement>>(
          future: state.dataStore.listMeasurements(),
          builder: (context, snapshot) {
            final items = snapshot.data ?? [];
            final filtered = items.where((item) {
              if (_query.isEmpty) return true;
              final query = _query.toLowerCase();
              return item.id.toLowerCase().contains(query) ||
                  item.deviceId.toLowerCase().contains(query) ||
                  (item.materialName ?? '').toLowerCase().contains(query) ||
                  (item.sampleName ?? '').toLowerCase().contains(query);
            }).toList();
            _sortItems(filtered);

            final bottomInset = MediaQuery.of(context).padding.bottom + 140;
            return Scaffold(
              backgroundColor: Colors.transparent,
              floatingActionButton: FloatingActionButton.extended(
                onPressed: filtered.isEmpty
                    ? null
                    : () => _showCsvExportSheet(filtered),
                icon: const Icon(Icons.file_download_outlined),
                label: Text(t('history.csv')),
              ),
              body: SafeArea(
                bottom: true,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('history.title'),
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: InputDecoration(
                          hintText: t('history.searchHint'),
                          prefixIcon: const Icon(Icons.search),
                        ),
                        onChanged: (value) =>
                            setState(() => _query = value.trim()),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            t('history.sort'),
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<_HistorySort>(
                              initialValue: _sort,
                              items: [
                                DropdownMenuItem(
                                  value: _HistorySort.dateDesc,
                                  child: Text(t('history.sortDateNewest')),
                                ),
                                DropdownMenuItem(
                                  value: _HistorySort.dateAsc,
                                  child: Text(t('history.sortDateOldest')),
                                ),
                                DropdownMenuItem(
                                  value: _HistorySort.nameAsc,
                                  child: Text(t('history.sortNameAz')),
                                ),
                                DropdownMenuItem(
                                  value: _HistorySort.nameDesc,
                                  child: Text(t('history.sortNameZa')),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _sort = value);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: filtered.isEmpty
                            ? _EmptyState(onGoScan: () {})
                            : ListView.separated(
                                padding: EdgeInsets.only(bottom: bottomInset),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final item = filtered[index];
                                  final analyses = _decodeAnalyses(
                                    item.resultsJson,
                                  );
                                  return Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Column(
                                        children: [
                                          ListTile(
                                            leading: const Icon(
                                              Icons.show_chart,
                                            ),
                                            title: Text(
                                              item.sampleName == null ||
                                                      item.sampleName!.isEmpty
                                                  ? '${t('history.scan')} ${item.id.substring(0, 8)}'
                                                  : item.sampleName!,
                                            ),
                                            subtitle: Text(
                                              '${item.materialName ?? t('history.unknownMaterial')} • ${item.timestamp}',
                                            ),
                                            onLongPress: () =>
                                                _showItemActions(item),
                                            onTap: () {
                                              setState(() {
                                                _expandedId =
                                                    _expandedId == item.id
                                                    ? null
                                                    : item.id;
                                              });
                                            },
                                          ),
                                          if (_expandedId == item.id)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                    16,
                                                    0,
                                                    16,
                                                    12,
                                                  ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Divider(height: 12),
                                                  Text('${t('history.scan')} ${item.id}'),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    '${t('history.device')}: ${item.deviceId}',
                                                  ),
                                                  if (item.materialName != null)
                                                    Text(
                                                      '${t('history.material')}: ${item.materialName}',
                                                    ),
                                                  if (item.sampleName != null)
                                                    Text(
                                                      '${t('history.sample')}: ${item.sampleName}',
                                                    ),
                                                  Text(
                                                    '${t('history.timestamp')}: ${item.timestamp}',
                                                  ),
                                                  Text(
                                                    '${t('history.scanTime')}: ${item.scanTimeMs} ms',
                                                  ),
                                                  if (analyses.isNotEmpty) ...[
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      t('history.analysis'),
                                                      style: Theme.of(
                                                        context,
                                                      ).textTheme.labelLarge,
                                                    ),
                                                    const SizedBox(height: 4),
                                                    ...analyses.map((analysis) {
                                                      final diagnostics = analysis
                                                          .diagnosticsSummary;
                                                      final text =
                                                          diagnostics.isEmpty
                                                          ? '${analysis.label}: ${analysis.displayValue}'
                                                          : '${analysis.label}: ${analysis.displayValue} ($diagnostics)';
                                                      return Text(text);
                                                    }),
                                                  ],
                                                  const SizedBox(height: 12),
                                                  // Loaded only when this row is
                                                  // expanded, so the list stays
                                                  // light; collapsing disposes it.
                                                  _HistorySpectrumPreview(
                                                    key: ValueKey(
                                                      'preview_${item.id}',
                                                    ),
                                                    measurementId: item.id,
                                                    dataStore: state.dataStore,
                                                    axisUnit:
                                                        state.spectrumAxisUnit,
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showItemActions(Measurement item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).cardTheme.color,
      builder: (sheetContext) {
        final safeBottom = MediaQuery.of(sheetContext).viewPadding.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + safeBottom + 72),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: Text(t('history.rename')),
                onTap: () => Navigator.pop(sheetContext, 'rename'),
              ),
              ListTile(
                leading: const Icon(Icons.compare_arrows),
                title: Text(t('history.compareWith')),
                onTap: () => Navigator.pop(sheetContext, 'compare'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(t('history.delete')),
                onTap: () => Navigator.pop(sheetContext, 'delete'),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || action == null) {
      return;
    }
    if (action == 'rename') {
      await _renameItem(item);
      return;
    }
    if (action == 'compare') {
      await _pickAndCompare(item);
      return;
    }
    if (action == 'delete') {
      await _deleteItem(item);
    }
  }

  void _sortItems(List<Measurement> items) {
    switch (_sort) {
      case _HistorySort.dateDesc:
        items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        break;
      case _HistorySort.dateAsc:
        items.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        break;
      case _HistorySort.nameAsc:
        items.sort((a, b) => _displayName(a).compareTo(_displayName(b)));
        break;
      case _HistorySort.nameDesc:
        items.sort((a, b) => _displayName(b).compareTo(_displayName(a)));
        break;
    }
  }

  String _displayName(Measurement item) {
    if (item.sampleName != null && item.sampleName!.trim().isNotEmpty) {
      return item.sampleName!.toLowerCase();
    }
    return item.id.toLowerCase();
  }

  Future<void> _showCsvExportSheet(List<Measurement> items) async {
    final selected = <String>{};
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).cardTheme.color,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final allSelected =
                selected.length == items.length && items.isNotEmpty;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                20 + MediaQuery.of(context).viewPadding.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('history.exportCsv'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: allSelected,
                    contentPadding: EdgeInsets.zero,
                    title: Text(t('history.selectAll')),
                    onChanged: (value) {
                      setModalState(() {
                        selected.clear();
                        if (value == true) {
                          selected.addAll(items.map((e) => e.id));
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.45,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final checked = selected.contains(item.id);
                        final label =
                            item.sampleName == null || item.sampleName!.isEmpty
                            ? '${t('history.scan')} ${item.id.substring(0, 8)}'
                            : item.sampleName!;
                        return CheckboxListTile(
                          value: checked,
                          contentPadding: EdgeInsets.zero,
                          title: Text(label),
                          subtitle: Text(item.timestamp.toString()),
                          onChanged: (value) {
                            setModalState(() {
                              if (value == true) {
                                selected.add(item.id);
                              } else {
                                selected.remove(item.id);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: selected.isEmpty
                          ? null
                          : () async {
                              Navigator.pop(sheetContext);
                              final messenger = ScaffoldMessenger.of(
                                this.context,
                              );
                              final chosen = items
                                  .where((e) => selected.contains(e.id))
                                  .toList();
                              final path = await _exportCsv(chosen);
                              if (!mounted) return;
                              messenger
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${t('history.csvSaved')} ${p.basename(path)}',
                                    ),
                                    duration: const Duration(seconds: 5),
                                    action: SnackBarAction(
                                      label: t('common.share'),
                                      onPressed: () => _shareCsv(path),
                                    ),
                                  ),
                                );
                            },
                      icon: const Icon(Icons.ios_share),
                      label: Text(t('history.exportShare')),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<String> _exportCsv(List<Measurement> items) async {
    final dataStore = context.read<AppState>().dataStore;
    final prepared = <Map<String, Object?>>[];
    var maxBands = 0;
    var referenceBands = <double>[];
    final analysisColumns = <String, _CsvAnalysisColumn>{};

    for (final item in items) {
      final analyses = _decodeAnalyses(item.resultsJson);
      for (final analysis in analyses) {
        analysisColumns.putIfAbsent(
          analysis.columnKey,
          () => _CsvAnalysisColumn(
            key: analysis.columnKey,
            header: analysis.columnHeader,
          ),
        );
        if (analysis.hasGh) {
          analysisColumns.putIfAbsent(
            analysis.ghColumnKey,
            () => _CsvAnalysisColumn(
              key: analysis.ghColumnKey,
              header: analysis.ghColumnHeader,
            ),
          );
        }
        if (analysis.hasGhLevel) {
          analysisColumns.putIfAbsent(
            analysis.ghLevelColumnKey,
            () => _CsvAnalysisColumn(
              key: analysis.ghLevelColumnKey,
              header: analysis.ghLevelColumnHeader,
            ),
          );
        }
        if (analysis.hasNh) {
          analysisColumns.putIfAbsent(
            analysis.nhColumnKey,
            () => _CsvAnalysisColumn(
              key: analysis.nhColumnKey,
              header: analysis.nhColumnHeader,
            ),
          );
        }
        if (analysis.hasNhLevel) {
          analysisColumns.putIfAbsent(
            analysis.nhLevelColumnKey,
            () => _CsvAnalysisColumn(
              key: analysis.nhLevelColumnKey,
              header: analysis.nhLevelColumnHeader,
            ),
          );
        }
        if (analysis.hasFossGh) {
          analysisColumns.putIfAbsent(
            analysis.fossGhColumnKey,
            () => _CsvAnalysisColumn(
              key: analysis.fossGhColumnKey,
              header: analysis.fossGhColumnHeader,
            ),
          );
        }
        if (analysis.hasFossGhLevel) {
          analysisColumns.putIfAbsent(
            analysis.fossGhLevelColumnKey,
            () => _CsvAnalysisColumn(
              key: analysis.fossGhLevelColumnKey,
              header: analysis.fossGhLevelColumnHeader,
            ),
          );
        }
        if (analysis.hasFossNh) {
          analysisColumns.putIfAbsent(
            analysis.fossNhColumnKey,
            () => _CsvAnalysisColumn(
              key: analysis.fossNhColumnKey,
              header: analysis.fossNhColumnHeader,
            ),
          );
        }
        if (analysis.hasFossNhLevel) {
          analysisColumns.putIfAbsent(
            analysis.fossNhLevelColumnKey,
            () => _CsvAnalysisColumn(
              key: analysis.fossNhLevelColumnKey,
              header: analysis.fossNhLevelColumnHeader,
            ),
          );
        }
        if (analysis.hasFossQ) {
          analysisColumns.putIfAbsent(
            analysis.fossQColumnKey,
            () => _CsvAnalysisColumn(
              key: analysis.fossQColumnKey,
              header: analysis.fossQColumnHeader,
            ),
          );
        }
        if (analysis.hasFossQLevel) {
          analysisColumns.putIfAbsent(
            analysis.fossQLevelColumnKey,
            () => _CsvAnalysisColumn(
              key: analysis.fossQLevelColumnKey,
              header: analysis.fossQLevelColumnHeader,
            ),
          );
        }
      }

      final spectra = await dataStore.getSpectra(item.id);
      final blob = _pickPreferredSpectrum(spectra);
      final spectrum = blob?.toSpectrum();
      final pairs = <List<double>>[];
      if (spectrum != null && blob != null) {
        final bandCount = math.min(
          blob.length,
          math.min(spectrum.x.length, spectrum.y.length),
        );
        for (var i = 0; i < bandCount; i += 1) {
          final wavelengthNm = _toNmFromCmInv(spectrum.x[i]);
          if (wavelengthNm == null) {
            continue;
          }
          final reflectance = spectrum.y[i];
          if (!reflectance.isFinite) {
            continue;
          }
          pairs.add([wavelengthNm, reflectance]);
        }
        pairs.sort((a, b) => a[0].compareTo(b[0]));
      }
      final wavelengths = pairs.map((e) => e[0]).toList(growable: false);
      final reflectances = pairs.map((e) => e[1]).toList(growable: false);
      final bandCount = wavelengths.length;
      if (bandCount > maxBands) {
        maxBands = bandCount;
        referenceBands = wavelengths;
      }
      prepared.add({
        'item': item,
        'analyses': analyses,
        'sampleType': _sampleType(blob),
        'commonWave': _commonWaveLabel(item.paramsJson),
        'wavelengths': wavelengths,
        'reflectances': reflectances,
        'bandCount': bandCount,
      });
    }

    final header = <String>[
      'Sample Type',
      'Sample Name',
      'Material Name',
      'Device Id',
      'Created At (UTC)',
      'Scan Time',
      'Common Wave Number',
      'Latitude',
      'Longitude',
      'Analysis Summary',
    ];
    for (final column in analysisColumns.values) {
      header.add(column.header);
    }
    for (var i = 0; i < maxBands; i += 1) {
      if (i < referenceBands.length) {
        header.add(referenceBands[i].toStringAsFixed(3));
      } else {
        header.add('');
      }
    }
    final fileName =
        'history_export_${DateTime.now().millisecondsSinceEpoch}.csv';
    final docsDir = await getApplicationDocumentsDirectory();
    final filePath = p.join(docsDir.path, fileName);
    final sink = File(filePath).openWrite();
    try {
      // UTF-8 BOM so Excel/Sheets auto-detect encoding and don't mangle
      // non-ASCII characters (Korean material names, em-dashes, etc.).
      sink.write('﻿');
      sink.writeln(header.map(_csv).join(','));
      for (final entry in prepared) {
        final item = entry['item'] as Measurement;
        final analyses = entry['analyses'] as List<_HistoryAnalysis>;
        final summary = _analysisSummary(analyses);
        final sampleType = entry['sampleType'] as String? ?? 'Spectrum';
        final commonWave = entry['commonWave'] as String? ?? '';
        final reflectances = entry['reflectances'] as List<double>;
        final bandCount = entry['bandCount'] as int;

        final values = <String>[
          sampleType,
          item.sampleName ?? '',
          item.materialName ?? '',
          item.deviceId,
          _formatUtc(item.timestamp),
          _formatScanTimeSeconds(item.scanTimeMs),
          commonWave,
          item.latitude?.toString() ?? '',
          item.longitude?.toString() ?? '',
          summary,
        ];

        for (final column in analysisColumns.values) {
          values.add(_analysisValueForColumn(analyses, column.key));
        }

        for (var i = 0; i < maxBands; i += 1) {
          values.add(
            i < bandCount ? reflectances[i].toStringAsFixed(6) : '',
          );
        }

        sink.writeln(values.map(_csv).join(','));
      }
    } finally {
      await sink.close();
    }
    return filePath;
  }

  Future<void> _shareCsv(String path) async {
    try {
      // Some receiver apps (especially messengers like KakaoTalk/LINE) ignore
      // the file attachment when EXTRA_TEXT is present — they treat the share
      // as a text-only message. Send only the file with an explicit MIME type
      // so Drive/Files/Gmail etc. all consistently get the attachment.
      await Share.shareXFiles(
        [XFile(path, mimeType: 'text/csv', name: p.basename(path))],
        subject: 'Spectra CSV export',
      );
    } on PlatformException catch (error) {
      debugPrint('Share sheet failed: $error');
    }
  }

  List<_HistoryAnalysis> _decodeAnalyses(String? resultsJson) {
    if (resultsJson == null || resultsJson.trim().isEmpty) {
      return const <_HistoryAnalysis>[];
    }

    try {
      final decoded = jsonDecode(resultsJson);
      if (decoded is Map<String, dynamic>) {
        final analyses = decoded['analyses'];
        if (analyses is List) {
          return analyses
              .whereType<Map>()
              .map(
                (map) =>
                    _HistoryAnalysis.fromMap(Map<String, dynamic>.from(map)),
              )
              .toList(growable: false);
        }
        if (decoded.containsKey('label') || decoded.containsKey('value')) {
          return <_HistoryAnalysis>[_HistoryAnalysis.fromMap(decoded)];
        }
      }
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map(
              (map) => _HistoryAnalysis.fromMap(Map<String, dynamic>.from(map)),
            )
            .toList(growable: false);
      }
    } catch (_) {
      return const <_HistoryAnalysis>[];
    }

    return const <_HistoryAnalysis>[];
  }

  String _analysisSummary(List<_HistoryAnalysis> analyses) {
    if (analyses.isEmpty) {
      return '';
    }
    return analyses
        .map((analysis) => '${analysis.label}: ${analysis.displayValue}')
        .join(', ');
  }

  String _analysisValueForColumn(
    List<_HistoryAnalysis> analyses,
    String columnKey,
  ) {
    for (final analysis in analyses) {
      final value = analysis.valueForColumn(columnKey);
      if (value != null) {
        return value;
      }
    }
    return '';
  }

  String _formatUtc(DateTime timestamp) {
    final utc = timestamp.toUtc();
    return DateFormat('d MMM yyyy, h:mm a').format(utc);
  }

  String _formatScanTimeSeconds(int scanTimeMs) {
    final seconds = scanTimeMs / 1000.0;
    if (seconds == seconds.roundToDouble()) {
      return seconds.toStringAsFixed(0);
    }
    return seconds.toStringAsFixed(3);
  }

  String _sampleType(SpectrumBlob? blob) {
    if (blob == null) {
      return 'Spectrum';
    }
    if (blob.kind == 'raw') {
      return 'Spectrum';
    }
    if (blob.kind == 'background') {
      return 'Background';
    }
    return blob.kind;
  }

  String _commonWaveLabel(String paramsJson) {
    try {
      final map = jsonDecode(paramsJson) as Map<String, dynamic>;
      final raw = map['commonWavNum'];
      if (raw is! num) {
        return '';
      }
      switch (raw.toInt()) {
        case 1:
          return '65 pts';
        case 2:
          return '129 pts';
        case 3:
          return '257 pts';
        case 4:
          return '513 pts';
        case 5:
          return '1024 pts';
        case 6:
          return '2048 pts';
        case 7:
          return '4096 pts';
        default:
          return '';
      }
    } catch (_) {
      return '';
    }
  }

  SpectrumBlob? _pickPreferredSpectrum(List<SpectrumBlob> spectra) {
    if (spectra.isEmpty) {
      return null;
    }
    for (final blob in spectra) {
      if (blob.kind == 'raw') {
        return blob;
      }
    }
    return spectra.first;
  }

  double? _toNmFromCmInv(double wavenumber) {
    if (!wavenumber.isFinite || wavenumber <= 100) {
      return null;
    }
    return 10000000.0 / wavenumber;
  }

  String _csv(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  Future<void> _pickAndCompare(Measurement primary) async {
    final all = await context.read<AppState>().dataStore.listMeasurements();
    final candidates = all.where((m) => m.id != primary.id).toList();
    if (!mounted) return;
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('history.noCompare'))),
      );
      return;
    }
    final picked = await showModalBottomSheet<Measurement>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.7,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('history.pickCompare'),
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    itemCount: candidates.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final m = candidates[i];
                      final title = [m.materialName, m.sampleName]
                          .whereType<String>()
                          .where((s) => s.isNotEmpty)
                          .join(' / ');
                      return ListTile(
                        title: Text(
                          title.isEmpty
                              ? m.id.substring(0, 8)
                              : title,
                        ),
                        subtitle: Text('${m.timestamp}'),
                        onTap: () => Navigator.pop(sheetContext, m),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || picked == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CompareScreen(left: primary, right: picked),
      ),
    );
  }

  Future<void> _renameItem(Measurement item) async {
    final controller = TextEditingController(text: item.sampleName ?? '');
    final dataStore = context.read<AppState>().dataStore;
    final renamed = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(t('history.rename')),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(labelText: t('common.name')),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(t('common.cancel')),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: Text(t('common.save')),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (!mounted || renamed == null) {
      return;
    }
    await dataStore.renameMeasurementSampleName(item.id, renamed);
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _deleteItem(Measurement item) async {
    final dataStore = context.read<AppState>().dataStore;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(t('history.delete')),
          content: Text(t('history.deleteConfirm')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(t('common.cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(t('common.delete')),
            ),
          ],
        );
      },
    );
    if (shouldDelete != true || !mounted) {
      return;
    }
    await dataStore.deleteMeasurement(item.id);
    if (!mounted) {
      return;
    }
    setState(() {
      if (_expandedId == item.id) {
        _expandedId = null;
      }
    });
  }
}

class _HistoryAnalysis {
  const _HistoryAnalysis({
    required this.modelId,
    required this.modelName,
    required this.label,
    required this.displayValue,
    required this.units,
    required this.primaryValue,
    required this.ghLabel,
    required this.nhLabel,
    required this.fossGhLabel,
    required this.fossNhLabel,
    required this.fossQLabel,
    this.ghLevel,
    this.nhLevel,
    this.ghDisplayValue,
    this.nhDisplayValue,
    this.fossGhLevel,
    this.fossNhLevel,
    this.fossQLevel,
    this.fossGhDisplayValue,
    this.fossNhDisplayValue,
    this.fossQDisplayValue,
  });

  final String modelId;
  final String modelName;
  final String label;
  final String displayValue;
  final String units;
  final String primaryValue;
  final String ghLabel;
  final String nhLabel;
  final String fossGhLabel;
  final String fossNhLabel;
  final String fossQLabel;
  final String? ghLevel;
  final String? nhLevel;
  final String? ghDisplayValue;
  final String? nhDisplayValue;
  final String? fossGhLevel;
  final String? fossNhLevel;
  final String? fossQLevel;
  final String? fossGhDisplayValue;
  final String? fossNhDisplayValue;
  final String? fossQDisplayValue;

  String get columnKey {
    if (modelId.isNotEmpty) {
      return modelId;
    }
    final raw = '$label|$modelName';
    return raw.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
  }

  String get columnHeader {
    if (modelName.isNotEmpty) {
      return '$label ($modelName)';
    }
    return label;
  }

  bool get hasGh => ghDisplayValue != null && ghDisplayValue!.trim().isNotEmpty;

  bool get hasNh => nhDisplayValue != null && nhDisplayValue!.trim().isNotEmpty;

  String get ghColumnKey => '${columnKey}__gh';

  String get nhColumnKey => '${columnKey}__nh';

  String get ghLevelColumnKey => '${columnKey}__gh_level';

  String get nhLevelColumnKey => '${columnKey}__nh_level';

  String get fossGhColumnKey => '${columnKey}__foss_gh';

  String get fossNhColumnKey => '${columnKey}__foss_nh';

  String get fossQColumnKey => '${columnKey}__foss_q';

  String get fossGhLevelColumnKey => '${columnKey}__foss_gh_level';

  String get fossNhLevelColumnKey => '${columnKey}__foss_nh_level';

  String get fossQLevelColumnKey => '${columnKey}__foss_q_level';

  String get ghColumnHeader {
    final context = modelName.isNotEmpty ? modelName : label;
    return '$ghLabel ($context)';
  }

  String get nhColumnHeader {
    final context = modelName.isNotEmpty ? modelName : label;
    return '$nhLabel ($context)';
  }

  String get ghLevelColumnHeader {
    final context = modelName.isNotEmpty ? modelName : label;
    return '$ghLabel Level ($context)';
  }

  String get nhLevelColumnHeader {
    final context = modelName.isNotEmpty ? modelName : label;
    return '$nhLabel Level ($context)';
  }

  String get fossGhColumnHeader {
    final context = modelName.isNotEmpty ? modelName : label;
    return '$fossGhLabel ($context)';
  }

  String get fossNhColumnHeader {
    final context = modelName.isNotEmpty ? modelName : label;
    return '$fossNhLabel ($context)';
  }

  String get fossQColumnHeader {
    final context = modelName.isNotEmpty ? modelName : label;
    return '$fossQLabel ($context)';
  }

  String get fossGhLevelColumnHeader {
    final context = modelName.isNotEmpty ? modelName : label;
    return '$fossGhLabel Level ($context)';
  }

  String get fossNhLevelColumnHeader {
    final context = modelName.isNotEmpty ? modelName : label;
    return '$fossNhLabel Level ($context)';
  }

  String get fossQLevelColumnHeader {
    final context = modelName.isNotEmpty ? modelName : label;
    return '$fossQLabel Level ($context)';
  }

  bool get hasGhLevel => ghLevel != null && ghLevel!.trim().isNotEmpty;

  bool get hasNhLevel => nhLevel != null && nhLevel!.trim().isNotEmpty;

  bool get hasFossGh =>
      fossGhDisplayValue != null && fossGhDisplayValue!.trim().isNotEmpty;

  bool get hasFossNh =>
      fossNhDisplayValue != null && fossNhDisplayValue!.trim().isNotEmpty;

  bool get hasFossQ =>
      fossQDisplayValue != null && fossQDisplayValue!.trim().isNotEmpty;

  bool get hasFossGhLevel =>
      fossGhLevel != null && fossGhLevel!.trim().isNotEmpty;

  bool get hasFossNhLevel =>
      fossNhLevel != null && fossNhLevel!.trim().isNotEmpty;

  bool get hasFossQLevel => fossQLevel != null && fossQLevel!.trim().isNotEmpty;

  String get diagnosticsSummary {
    final parts = <String>[];
    if (hasGh) {
      final level = hasGhLevel ? ' [${ghLevel!}]' : '';
      parts.add('$ghLabel: ${ghDisplayValue!}$level');
    }
    if (hasNh) {
      final level = hasNhLevel ? ' [${nhLevel!}]' : '';
      parts.add('$nhLabel: ${nhDisplayValue!}$level');
    }
    if (hasFossGh) {
      final level = hasFossGhLevel ? ' [${fossGhLevel!}]' : '';
      parts.add('$fossGhLabel: ${fossGhDisplayValue!}$level');
    }
    if (hasFossNh) {
      final level = hasFossNhLevel ? ' [${fossNhLevel!}]' : '';
      parts.add('$fossNhLabel: ${fossNhDisplayValue!}$level');
    }
    if (hasFossQ) {
      final level = hasFossQLevel ? ' [${fossQLevel!}]' : '';
      parts.add('$fossQLabel: ${fossQDisplayValue!}$level');
    }
    return parts.join(', ');
  }

  String? valueForColumn(String key) {
    if (key == columnKey) {
      return displayValue;
    }
    if (hasGh && key == ghColumnKey) {
      return ghDisplayValue;
    }
    if (hasNh && key == nhColumnKey) {
      return nhDisplayValue;
    }
    if (hasGhLevel && key == ghLevelColumnKey) {
      return ghLevel;
    }
    if (hasNhLevel && key == nhLevelColumnKey) {
      return nhLevel;
    }
    if (hasFossGh && key == fossGhColumnKey) {
      return fossGhDisplayValue;
    }
    if (hasFossNh && key == fossNhColumnKey) {
      return fossNhDisplayValue;
    }
    if (hasFossQ && key == fossQColumnKey) {
      return fossQDisplayValue;
    }
    if (hasFossGhLevel && key == fossGhLevelColumnKey) {
      return fossGhLevel;
    }
    if (hasFossNhLevel && key == fossNhLevelColumnKey) {
      return fossNhLevel;
    }
    if (hasFossQLevel && key == fossQLevelColumnKey) {
      return fossQLevel;
    }
    return null;
  }

  factory _HistoryAnalysis.fromMap(Map<String, dynamic> map) {
    final labelRaw = (map['label']?.toString() ?? '').trim();
    final label = labelRaw.isEmpty ? 'Result' : labelRaw;
    final units = (map['units']?.toString() ?? '').trim();

    final numericValue = map['numericValue'] is num
        ? (map['numericValue'] as num).toDouble()
        : map['value'] is num
        ? (map['value'] as num).toDouble()
        : null;
    final displayRaw = (map['displayValue']?.toString() ?? '').trim();
    final fallbackRaw = (map['value']?.toString() ?? '').trim();

    final displayValue = displayRaw.isNotEmpty
        ? displayRaw
        : numericValue != null
        ? _formatNumeric(numericValue, units)
        : (fallbackRaw.isNotEmpty ? fallbackRaw : '—');

    final primaryValue = numericValue != null
        ? numericValue.toStringAsFixed(2)
        : (fallbackRaw.isNotEmpty ? fallbackRaw : displayValue);

    final ghLabelRaw = (map['ghLabel']?.toString() ?? 'GH').trim();
    final nhLabelRaw = (map['nhLabel']?.toString() ?? 'NH').trim();
    final fossGhLabelRaw = (map['fossGhLabel']?.toString() ?? 'GH').trim();
    final fossNhLabelRaw = (map['fossNhLabel']?.toString() ?? 'NH').trim();
    final ghLevelRaw = (map['ghLevel']?.toString() ?? '').trim();
    final nhLevelRaw = (map['nhLevel']?.toString() ?? '').trim();
    final fossGhLevelRaw = (map['fossGhLevel']?.toString() ?? '').trim();
    final fossNhLevelRaw = (map['fossNhLevel']?.toString() ?? '').trim();
    final ghNumeric = map['gh'] is num ? (map['gh'] as num).toDouble() : null;
    final nhNumeric = map['nh'] is num ? (map['nh'] as num).toDouble() : null;
    final fossGhNumeric = map['fossGh'] is num
        ? (map['fossGh'] as num).toDouble()
        : null;
    final fossNhNumeric = map['fossNh'] is num
        ? (map['fossNh'] as num).toDouble()
        : null;
    final ghDisplayRaw = (map['ghDisplayValue']?.toString() ?? '').trim();
    final nhDisplayRaw = (map['nhDisplayValue']?.toString() ?? '').trim();
    final fossGhDisplayRaw = (map['fossGhDisplayValue']?.toString() ?? '')
        .trim();
    final fossNhDisplayRaw = (map['fossNhDisplayValue']?.toString() ?? '')
        .trim();
    final ghDecimalsRaw = (map['ghDecimals'] as num?)?.toInt() ?? 3;
    final nhDecimalsRaw = (map['nhDecimals'] as num?)?.toInt() ?? 3;
    final fossGhDecimalsRaw = (map['fossGhDecimals'] as num?)?.toInt() ?? 3;
    final fossNhDecimalsRaw = (map['fossNhDecimals'] as num?)?.toInt() ?? 3;
    final ghDecimals = ghDecimalsRaw < 0
        ? 0
        : (ghDecimalsRaw > 6 ? 6 : ghDecimalsRaw);
    final nhDecimals = nhDecimalsRaw < 0
        ? 0
        : (nhDecimalsRaw > 6 ? 6 : nhDecimalsRaw);
    final fossGhDecimals = fossGhDecimalsRaw < 0
        ? 0
        : (fossGhDecimalsRaw > 6 ? 6 : fossGhDecimalsRaw);
    final fossNhDecimals = fossNhDecimalsRaw < 0
        ? 0
        : (fossNhDecimalsRaw > 6 ? 6 : fossNhDecimalsRaw);

    final ghDisplayValue = ghDisplayRaw.isNotEmpty
        ? ghDisplayRaw
        : ghNumeric?.toStringAsFixed(ghDecimals);
    final nhDisplayValue = nhDisplayRaw.isNotEmpty
        ? nhDisplayRaw
        : nhNumeric?.toStringAsFixed(nhDecimals);
    final fossGhDisplayValue = fossGhDisplayRaw.isNotEmpty
        ? fossGhDisplayRaw
        : fossGhNumeric?.toStringAsFixed(fossGhDecimals);
    final fossNhDisplayValue = fossNhDisplayRaw.isNotEmpty
        ? fossNhDisplayRaw
        : fossNhNumeric?.toStringAsFixed(fossNhDecimals);

    final mergedGhDisplayValue = ghDisplayValue ?? fossGhDisplayValue;
    final mergedNhDisplayValue = nhDisplayValue ?? fossNhDisplayValue;
    final mergedGhLevel = ghLevelRaw.isNotEmpty
        ? ghLevelRaw
        : (fossGhLevelRaw.isEmpty ? null : fossGhLevelRaw);
    final mergedNhLevel = nhLevelRaw.isNotEmpty
        ? nhLevelRaw
        : (fossNhLevelRaw.isEmpty ? null : fossNhLevelRaw);

    return _HistoryAnalysis(
      modelId: (map['modelId']?.toString() ?? '').trim(),
      modelName: (map['modelName']?.toString() ?? '').trim(),
      label: label,
      displayValue: displayValue,
      units: units,
      primaryValue: primaryValue,
      ghLabel: ghLabelRaw.isEmpty ? 'GH' : ghLabelRaw,
      nhLabel: nhLabelRaw.isEmpty ? 'NH' : nhLabelRaw,
      fossGhLabel: _normalizeDiagnosticLabel(fossGhLabelRaw, fallback: 'GH'),
      fossNhLabel: _normalizeDiagnosticLabel(fossNhLabelRaw, fallback: 'NH'),
      fossQLabel: 'Q',
      ghLevel: mergedGhLevel,
      nhLevel: mergedNhLevel,
      ghDisplayValue: mergedGhDisplayValue,
      nhDisplayValue: mergedNhDisplayValue,
      fossGhLevel: null,
      fossNhLevel: null,
      fossQLevel: null,
      fossGhDisplayValue: null,
      fossNhDisplayValue: null,
      fossQDisplayValue: null,
    );
  }

  static String _formatNumeric(double value, String units) {
    final number = value.toStringAsFixed(2);
    if (units.isEmpty) {
      return number;
    }
    if (units == '%') {
      return '$number%';
    }
    return '$number $units';
  }

  static String _normalizeDiagnosticLabel(
    String value, {
    required String fallback,
  }) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return fallback;
    }
    final normalized = trimmed.toLowerCase().replaceAll(' ', '');
    if (normalized == 'f-gh') {
      return 'GH';
    }
    if (normalized == 'f-nh') {
      return 'NH';
    }
    return trimmed;
  }
}

class _CsvAnalysisColumn {
  const _CsvAnalysisColumn({required this.key, required this.header});

  final String key;
  final String header;
}

enum _HistorySort { dateDesc, dateAsc, nameAsc, nameDesc }

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onGoScan});

  final VoidCallback onGoScan;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_graph, size: 40, color: AppTheme.muted),
              const SizedBox(height: 12),
              Text(
                t('history.noScans'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                t('history.noScansBody'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Spectrum chart shown inside an expanded History row. Its spectra are read
/// from the database only when this widget mounts (i.e. when the row is
/// expanded), so the list never pre-loads every measurement's blobs. The
/// averaged 'raw' trace is the main line; individual 'scan_NN' repeats render
/// as background overlays. No legend (the row is narrow).
class _HistorySpectrumPreview extends StatefulWidget {
  const _HistorySpectrumPreview({
    super.key,
    required this.measurementId,
    required this.dataStore,
    required this.axisUnit,
  });

  final String measurementId;
  final DataStore dataStore;
  final String axisUnit;

  @override
  State<_HistorySpectrumPreview> createState() =>
      _HistorySpectrumPreviewState();
}

class _HistorySpectrumPreviewState extends State<_HistorySpectrumPreview> {
  late final Future<_PreviewData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_PreviewData> _load() async {
    try {
      final blobs = await widget.dataStore.getSpectra(widget.measurementId);
      if (blobs.isEmpty) {
        return const _PreviewData(main: null, overlays: <Spectrum>[]);
      }
      SpectrumBlob? raw;
      final scans = <SpectrumBlob>[];
      for (final blob in blobs) {
        if (blob.kind == 'raw') {
          raw ??= blob;
        } else if (blob.kind.startsWith('scan')) {
          scans.add(blob);
        }
      }
      final mainBlob = raw ?? blobs.first;
      scans.sort((a, b) => a.kind.compareTo(b.kind));
      return _PreviewData(
        main: mainBlob.toSpectrum(),
        overlays: [for (final s in scans) s.toSpectrum()],
      );
    } catch (_) {
      return const _PreviewData(main: null, overlays: <Spectrum>[]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_PreviewData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 120,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final data = snapshot.data;
        final main = data?.main;
        if (main == null || main.length == 0) {
          return const SizedBox.shrink();
        }
        return SpectrumChart(
          spectrum: main,
          title: '',
          axisUnit: widget.axisUnit,
          simplified: true,
          overlays: data!.overlays,
        );
      },
    );
  }
}

class _PreviewData {
  const _PreviewData({required this.main, required this.overlays});

  final Spectrum? main;
  final List<Spectrum> overlays;
}
