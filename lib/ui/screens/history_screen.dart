import 'dart:convert';

import 'package:flutter/material.dart';
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
                  item.deviceId.toLowerCase().contains(query);
            }).toList();

            final bottomInset = MediaQuery.of(context).padding.bottom + 110;
            return SafeArea(
              bottom: false,
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
                                  child: ListTile(
                                    leading: const Icon(Icons.show_chart),
                                    title: Text('Scan ${item.id.substring(0, 8)}'),
                                    subtitle: Text(
                                      'Device ${item.deviceId} • ${item.timestamp}',
                                    ),
                                    trailing: results == null
                                        ? const Text('—')
                                        : Text('${results['value']} ${results['units']}'),
                                    onTap: () => _showDetails(context, item, results),
                                  ),
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
      },
    );
  }

  void _showDetails(
      BuildContext context, Measurement item, Map<String, dynamic>? results) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
      builder: (_) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Scan ${item.id}', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('Device: ${item.deviceId}'),
                Text('Timestamp: ${item.timestamp}'),
                Text('Scan time: ${item.scanTimeMs} ms'),
                if (item.latitude != null && item.longitude != null)
                  Text(
                    'Location: ${item.latitude!.toStringAsFixed(5)}, ${item.longitude!.toStringAsFixed(5)}',
                  ),
                const SizedBox(height: 12),
                if (results != null)
                  Text('Result: ${results['value']} ${results['units']} (${results['label']})'),
              ],
            ),
          ),
        );
      },
    );
  }
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
