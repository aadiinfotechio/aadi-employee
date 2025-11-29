import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';

class EquipmentCheckScreen extends StatefulWidget {
  const EquipmentCheckScreen({super.key});

  @override
  State<EquipmentCheckScreen> createState() => _EquipmentCheckScreenState();
}

class _EquipmentCheckScreenState extends State<EquipmentCheckScreen> {
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();

  List<dynamic> _sites = [];
  List<dynamic> _equipment = [];
  Map<String, dynamic>? _todayStatus;

  String? _selectedSiteId;
  bool _isLoadingSites = true;
  bool _isLoadingEquipment = false;
  bool _isSubmitting = false;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _loadSites();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    final position = await _locationService.getCurrentLocation();
    if (mounted) {
      setState(() {
        _currentPosition = position;
      });
    }
  }

  Future<void> _loadSites() async {
    setState(() => _isLoadingSites = true);
    try {
      final sites = await _apiService.getEquipmentCheckSites();
      if (mounted) {
        setState(() {
          _sites = sites;
          _isLoadingSites = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading sites: $e');
      if (mounted) {
        setState(() => _isLoadingSites = false);
      }
    }
  }

  Future<void> _loadEquipmentForSite(String siteId) async {
    setState(() {
      _isLoadingEquipment = true;
      _selectedSiteId = siteId;
    });

    try {
      final status = await _apiService.getEquipmentTodayStatus(siteId);
      if (mounted) {
        setState(() {
          _todayStatus = status;
          _equipment = status['equipment'] ?? [];
          _isLoadingEquipment = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading equipment: $e');
      if (mounted) {
        setState(() => _isLoadingEquipment = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load equipment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitCheck(dynamic equipment) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _EquipmentCheckDialog(equipment: equipment),
    );

    if (result == null) return;

    setState(() => _isSubmitting = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final employeeId = authProvider.currentUser?.id;

      if (employeeId == null) {
        throw Exception('Employee ID not found');
      }

      await _apiService.submitEquipmentCheck(
        employeeId: employeeId,
        equipmentId: equipment['_id'],
        siteId: _selectedSiteId!,
        status: result['status'],
        accuracyPercentage: result['accuracy'],
        notes: result['notes'],
        issues: result['issues'],
        latitude: _currentPosition?.latitude,
        longitude: _currentPosition?.longitude,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Equipment check submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Reload equipment status
        _loadEquipmentForSite(_selectedSiteId!);
      }
    } catch (e) {
      debugPrint('Error submitting check: $e');
      if (mounted) {
        String errorMessage = e.toString();
        if (errorMessage.contains('Exception:')) {
          errorMessage = errorMessage.replaceAll('Exception:', '').trim();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Site Selector
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Toll Plaza',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (_isLoadingSites)
                const Center(child: CircularProgressIndicator())
              else
                DropdownButtonFormField<String>(
                  value: _selectedSiteId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Choose a toll plaza',
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  items: _sites.map<DropdownMenuItem<String>>((site) {
                    return DropdownMenuItem<String>(
                      value: site['_id'],
                      child: Text(site['name'] ?? 'Unknown Site'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _loadEquipmentForSite(value);
                    }
                  },
                ),
            ],
          ),
        ),

        // Summary Card
        if (_todayStatus != null && _todayStatus!['summary'] != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _SummaryItem(
                      label: 'Total',
                      value: '${_todayStatus!['summary']['total'] ?? 0}',
                      color: Colors.blue,
                    ),
                    _SummaryItem(
                      label: 'Checked',
                      value: '${_todayStatus!['summary']['checked'] ?? 0}',
                      color: Colors.green,
                    ),
                    _SummaryItem(
                      label: 'Pending',
                      value: '${_todayStatus!['summary']['pending'] ?? 0}',
                      color: Colors.orange,
                    ),
                    _SummaryItem(
                      label: 'Complete',
                      value: '${_todayStatus!['summary']['completionPercentage'] ?? 0}%',
                      color: Colors.purple,
                    ),
                  ],
                ),
              ),
            ),
          ),

        const SizedBox(height: 8),

        // Equipment List
        Expanded(
          child: _selectedSiteId == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.precision_manufacturing, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Select a toll plaza to view equipment',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : _isLoadingEquipment
                  ? const Center(child: CircularProgressIndicator())
                  : _equipment.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory_2, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'No equipment found for this site',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => _loadEquipmentForSite(_selectedSiteId!),
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _equipment.length,
                            itemBuilder: (context, index) {
                              final eq = _equipment[index];
                              final isChecked = eq['checkedToday'] == true;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: isChecked ? Colors.green : Colors.orange,
                                    child: Icon(
                                      isChecked ? Icons.check : Icons.pending,
                                      color: Colors.white,
                                    ),
                                  ),
                                  title: Text(
                                    eq['name'] ?? 'Unknown Equipment',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Code: ${eq['equipmentCode'] ?? '-'}'),
                                      Text(
                                        'Type: ${eq['equipmentType'] ?? '-'} | Lane: ${eq['laneNumber'] ?? '-'}',
                                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                      ),
                                      if (isChecked && eq['todayCheck'] != null)
                                        Text(
                                          'Accuracy: ${eq['todayCheck']['accuracyPercentage']}% - ${eq['todayCheck']['status']}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.green[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                    ],
                                  ),
                                  trailing: isChecked
                                      ? const Icon(Icons.check_circle, color: Colors.green)
                                      : ElevatedButton(
                                          onPressed: _isSubmitting ? null : () => _submitCheck(eq),
                                          child: const Text('Check'),
                                        ),
                                  isThreeLine: true,
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

class _EquipmentCheckDialog extends StatefulWidget {
  final dynamic equipment;

  const _EquipmentCheckDialog({required this.equipment});

  @override
  State<_EquipmentCheckDialog> createState() => _EquipmentCheckDialogState();
}

class _EquipmentCheckDialogState extends State<_EquipmentCheckDialog> {
  String _status = 'working';
  double _accuracy = 100;
  final TextEditingController _notesController = TextEditingController();
  final List<String> _selectedIssues = [];

  final List<String> _availableIssues = [
    'Display malfunction',
    'Sensor error',
    'Communication failure',
    'Power issue',
    'Physical damage',
    'Calibration needed',
    'Software glitch',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Check: ${widget.equipment['name']}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Selection
            const Text('Equipment Status:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'working', label: Text('Working')),
                ButtonSegment(value: 'not_working', label: Text('Not Working')),
                ButtonSegment(value: 'needs_maintenance', label: Text('Maintenance')),
              ],
              selected: {_status},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _status = newSelection.first;
                });
              },
            ),
            const SizedBox(height: 16),

            // Accuracy Slider
            const Text('Accuracy Percentage:', style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _accuracy,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    label: '${_accuracy.round()}%',
                    onChanged: (value) {
                      setState(() {
                        _accuracy = value;
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: Text(
                    '${_accuracy.round()}%',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Issues (if not working properly)
            if (_status != 'working') ...[
              const Text('Issues Found:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _availableIssues.map((issue) {
                  final isSelected = _selectedIssues.contains(issue);
                  return FilterChip(
                    label: Text(issue, style: const TextStyle(fontSize: 12)),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedIssues.add(issue);
                        } else {
                          _selectedIssues.remove(issue);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Notes
            const Text('Notes (optional):', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Add any additional notes...',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop({
              'status': _status,
              'accuracy': _accuracy.round(),
              'notes': _notesController.text.trim(),
              'issues': _selectedIssues,
            });
          },
          child: const Text('Submit'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
}
