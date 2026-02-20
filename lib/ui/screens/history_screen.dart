import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../domain/measurement.dart';
import '../../services/app_state.dart';
import '../theme/app_theme.dart';

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
                onPressed: filtered.isEmpty ? null : () => _showCsvExportSheet(filtered),
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('CSV'),
              ),
              body: SafeArea(
                bottom: true,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('History', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 6),
                    Text('Review your recent scans.',
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search by device or session',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) => setState(() => _query = value.trim()),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text('Sort', style: Theme.of(context).textTheme.labelLarge),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<_HistorySort>(
                            initialValue: _sort,
                            items: const [
                              DropdownMenuItem(
                                value: _HistorySort.dateDesc,
                                child: Text('Date (newest)'),
                              ),
                              DropdownMenuItem(
                                value: _HistorySort.dateAsc,
                                child: Text('Date (oldest)'),
                              ),
                              DropdownMenuItem(
                                value: _HistorySort.nameAsc,
                                child: Text('Name (A-Z)'),
                              ),
                              DropdownMenuItem(
                                value: _HistorySort.nameDesc,
                                child: Text('Name (Z-A)'),
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
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final item = filtered[index];
                                final results = item.resultsJson == null
                                    ? null
                                    : jsonDecode(item.resultsJson!) as Map<String, dynamic>;
                                return Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Column(
                                      children: [
                                        ListTile(
                                          leading: const Icon(Icons.show_chart),
                                          title: Text(
                                            item.sampleName == null || item.sampleName!.isEmpty
                                                ? 'Scan ${item.id.substring(0, 8)}'
                                                : item.sampleName!,
                                          ),
                                          subtitle: Text(
                                            '${item.materialName ?? 'Unknown material'} • ${item.timestamp}',
                                          ),
                                          trailing: results == null
                                              ? const Text('—')
                                              : Text('${results['value']} ${results['units']}'),
                                          onLongPress: () => _showItemActions(item),
                                          onTap: () {
                                            setState(() {
                                              _expandedId = _expandedId == item.id ? null : item.id;
                                            });
                                          },
                                        ),
                                        if (_expandedId == item.id)
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Divider(height: 12),
                                                Text('Scan ${item.id}'),
                                                const SizedBox(height: 6),
                                                Text('Device: ${item.deviceId}'),
                                                if (item.materialName != null)
                                                  Text('Material: ${item.materialName}'),
                                                if (item.sampleName != null)
                                                  Text('Sample: ${item.sampleName}'),
                                                Text('Timestamp: ${item.timestamp}'),
                                                Text('Scan time: ${item.scanTimeMs} ms'),
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
                title: const Text('Rename'),
                onTap: () => Navigator.pop(sheetContext, 'rename'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete'),
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
            final allSelected = selected.length == items.length && items.isNotEmpty;
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
                  Text('Export CSV', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: allSelected,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Select all'),
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
                        final label = item.sampleName == null || item.sampleName!.isEmpty
                            ? 'Scan ${item.id.substring(0, 8)}'
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
                              final messenger = ScaffoldMessenger.of(this.context);
                              final chosen = items.where((e) => selected.contains(e.id)).toList();
                              final path = await _exportCsv(chosen);
                              if (!mounted) return;
                              messenger
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  SnackBar(
                                    content: Text('CSV exported: $path'),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                            },
                      icon: const Icon(Icons.download),
                      label: const Text('Export selected'),
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
    final rows = <String>[];
    final prepared = <Map<String, Object?>>[];
    var maxBands = 0;
    var referenceBands = <double>[];

    for (final item in items) {
      final result = item.resultsJson == null
          ? null
          : jsonDecode(item.resultsJson!) as Map<String, dynamic>;
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
        'result': result,
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
      'Device Temperature',
      'Latitude',
      'Longitude',
      'Analysis Value',
      'Analysis Units',
    ];
    for (var i = 0; i < maxBands; i += 1) {
      if (i < referenceBands.length) {
        header.add(_csv(referenceBands[i].toStringAsFixed(3)));
      } else {
        header.add(_csv(''));
      }
    }
    rows.add(header.join(','));

    for (final entry in prepared) {
      final item = entry['item'] as Measurement;
      final result = entry['result'] as Map<String, dynamic>?;
      final sampleType = entry['sampleType'] as String? ?? 'Spectrum';
      final commonWave = entry['commonWave'] as String? ?? '';
      final reflectances = entry['reflectances'] as List<double>;
      final bandCount = entry['bandCount'] as int;

      final line = <String>[
        _csv(sampleType),
        _csv(item.sampleName ?? ''),
        _csv(item.materialName ?? ''),
        _csv(item.deviceId),
        _csv(_formatUtc(item.timestamp)),
        _csv(_formatScanTimeSeconds(item.scanTimeMs)),
        _csv(commonWave),
        _csv(''),
        _csv(item.latitude?.toString() ?? ''),
        _csv(item.longitude?.toString() ?? ''),
        _csv(result?['value']?.toString() ?? ''),
        _csv(result?['units']?.toString() ?? ''),
      ];

      for (var i = 0; i < maxBands; i += 1) {
        if (i < bandCount) {
          line.add(_csv(reflectances[i].toStringAsFixed(6)));
        } else {
          line.add(_csv(''));
        }
      }

      rows.add(line.join(','));
    }
    final fileName = 'history_export_${DateTime.now().millisecondsSinceEpoch}.csv';
    final content = rows.join('\n');

    final preferredDir = await _resolveCsvDirectory();
    final preferredPath = p.join(preferredDir.path, fileName);
    try {
      final file = File(preferredPath);
      await file.writeAsString(content);
      return preferredPath;
    } catch (_) {
      final fallbackDir = await getApplicationDocumentsDirectory();
      final fallbackPath = p.join(fallbackDir.path, fileName);
      final fallbackFile = File(fallbackPath);
      await fallbackFile.writeAsString(content);
      return fallbackPath;
    }
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

  Future<Directory> _resolveCsvDirectory() async {
    if (Platform.isAndroid) {
      final publicDownload = Directory('/storage/emulated/0/Download');
      if (await publicDownload.exists()) {
        return publicDownload;
      }
      final external = await getExternalStorageDirectories(
        type: StorageDirectory.downloads,
      );
      if (external != null && external.isNotEmpty) {
        return external.first;
      }
    }
    return getApplicationDocumentsDirectory();
  }

  String _csv(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  Future<void> _renameItem(Measurement item) async {
    final controller = TextEditingController(text: item.sampleName ?? '');
    final dataStore = context.read<AppState>().dataStore;
    final renamed = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Rename'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (!mounted || renamed == null) {
      return;
    }
    await dataStore.renameMeasurementSampleName(
          item.id,
          renamed,
        );
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
          title: const Text('Delete'),
          content: const Text('Delete this scan record?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
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

enum _HistorySort {
  dateDesc,
  dateAsc,
  nameAsc,
  nameDesc,
}

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
              Text('No scans yet', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text('Capture your first scan from the Scan tab.',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
