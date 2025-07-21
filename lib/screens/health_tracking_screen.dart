import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/health_provider.dart';
import '../models/health_data_model.dart';
import '../utils/database_utils.dart';
import '../utils/app_colors.dart';
import '../utils/theme.dart';
import '../widgets/glass_container.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:intl/intl.dart';

class HealthTrackingScreen extends StatefulWidget {
  const HealthTrackingScreen({super.key});

  @override
  State<HealthTrackingScreen> createState() => _HealthTrackingScreenState();
}

class _HealthTrackingScreenState extends State<HealthTrackingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _valueController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedType = 'heart_rate';
  String _selectedUnit = 'bpm';
  bool _isAddingData = false;

  final Map<String, String> _healthTypes = {
    'heart_rate': 'Heart Rate',
    'blood_pressure_systolic': 'Blood Pressure (Systolic)',
    'blood_pressure_diastolic': 'Blood Pressure (Diastolic)',
    'temperature': 'Temperature',
    'weight': 'Weight',
    'height': 'Height',
    'blood_sugar': 'Blood Sugar',
    'oxygen_saturation': 'Oxygen Saturation',
  };

  final Map<String, String> _units = {
    'heart_rate': 'bpm',
    'blood_pressure_systolic': 'mmHg',
    'blood_pressure_diastolic': 'mmHg',
    'temperature': '°C',
    'weight': 'kg',
    'height': 'cm',
    'blood_sugar': 'mg/dL',
    'oxygen_saturation': '%',
  };

  @override
  void initState() {
    super.initState();
    _loadHealthData();
  }

  @override
  void dispose() {
    _valueController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _loadHealthData() {
    final healthProvider = Provider.of<HealthProvider>(context, listen: false);
    healthProvider.loadHealthDataStream(limit: 50);
    healthProvider.loadHealthSummary();
  }

  void _onTypeChanged(String type) {
    setState(() {
      _selectedType = type;
      _selectedUnit = _units[type] ?? '';
    });
  }

  Future<void> _addHealthData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isAddingData = true;
    });

    try {
      final healthProvider =
          Provider.of<HealthProvider>(context, listen: false);

      final value = double.tryParse(_valueController.text);
      if (value == null) {
        throw Exception('Invalid value');
      }

      // Validate health value
      if (!DatabaseUtils.isValidHealthValue(value, _selectedType)) {
        throw Exception('Value is outside normal range for $_selectedType');
      }

      final healthData = HealthDataModel(
        userId: '', // Will be set by repository
        type: _selectedType,
        value: value,
        unit: _selectedUnit,
        timestamp: DateTime.now(),
        source: 'manual',
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      await healthProvider.addHealthData(healthData);

      // Clear form
      _valueController.clear();
      _notesController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Health data added successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(DatabaseUtils.getErrorMessage(e)),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isAddingData = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Tracking'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Consumer<HealthProvider>(
        builder: (context, healthProvider, child) {
          if (healthProvider.status == HealthDataStatus.loading &&
              healthProvider.healthData.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (healthProvider.status == HealthDataStatus.error) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading health data',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    healthProvider.errorMessage ?? 'Unknown error',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      healthProvider.clearError();
                      _loadHealthData();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Add Health Data Section
                _buildAddHealthDataSection(),
                const SizedBox(height: 24),

                // Health Summary Section
                _buildHealthSummarySection(healthProvider),
                const SizedBox(height: 24),

                // Recent Health Data Section
                _buildRecentHealthDataSection(healthProvider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAddHealthDataSection() {
    return GlassContainer(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Health Data',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),

              // Health Type Dropdown
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Health Metric',
                  border: OutlineInputBorder(),
                ),
                items: _healthTypes.entries.map((entry) {
                  return DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  );
                }).toList(),
                onChanged: (String? value) => _onTypeChanged(value ?? ''),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a health metric';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Value Input
              TextFormField(
                controller: _valueController,
                decoration: InputDecoration(
                  labelText: 'Value',
                  suffixText: _selectedUnit,
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a value';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Notes Input
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Add Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isAddingData ? null : _addHealthData,
                  child: _isAddingData
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add Health Data'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHealthSummarySection(HealthProvider healthProvider) {
    final summary = healthProvider.healthSummary;

    if (summary.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Health Summary',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
          ),
          itemCount: summary.length,
          itemBuilder: (context, index) {
            final type = summary.keys.elementAt(index);
            final data = summary[type];

            return GlassContainer(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _healthTypes[type] ?? type,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Text(
                      DatabaseUtils.formatHealthValue(
                        data['latest'],
                        _units[type] ?? '',
                      ),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "${data['count']} records",
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecentHealthDataSection(HealthProvider healthProvider) {
    final recentData = healthProvider.healthData.take(10).toList();

    if (recentData.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Health Data',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            TextButton(
              onPressed: () {
                // Navigate to detailed health data screen
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: recentData.length,
          itemBuilder: (context, index) {
            final data = recentData[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassContainer(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primaryColor.withOpacity(0.2),
                    child: Icon(
                      _getHealthTypeIcon(data.type),
                      color: AppColors.primaryColor,
                    ),
                  ),
                  title: Text(_healthTypes[data.type] ?? data.type),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DatabaseUtils.formatHealthValue(data.value, data.unit),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        DatabaseUtils.formatTimestamp(data.timestamp),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  trailing: PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editHealthData(data);
                      } else if (value == 'delete') {
                        _deleteHealthData(data);
                      }
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  IconData _getHealthTypeIcon(String type) {
    switch (type) {
      case 'heart_rate':
        return FeatherIcons.heart;
      case 'blood_pressure_systolic':
      case 'blood_pressure_diastolic':
        return FeatherIcons.activity;
      case 'temperature':
        return FeatherIcons.thermometer;
      case 'weight':
        return FeatherIcons.activity;
      case 'height':
        return FeatherIcons.activity;
      case 'blood_sugar':
        return FeatherIcons.droplet;
      case 'oxygen_saturation':
        return FeatherIcons.wind;
      default:
        return FeatherIcons.activity;
    }
  }

  void _editHealthData(HealthDataModel data) {
    // Show edit dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Health Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: data.value.toString(),
              decoration: InputDecoration(
                labelText: 'Value',
                suffixText: data.unit,
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: data.notes,
              decoration: const InputDecoration(
                labelText: 'Notes',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Handle edit
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteHealthData(HealthDataModel data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Health Data'),
        content:
            const Text('Are you sure you want to delete this health data?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final healthProvider =
                    Provider.of<HealthProvider>(context, listen: false);
                await healthProvider.deleteHealthData(data.id!);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Health data deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(DatabaseUtils.getErrorMessage(e)),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
