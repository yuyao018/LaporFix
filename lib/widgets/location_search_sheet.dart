import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';

/// Reusable bottom sheet for searching a Malaysian location via Nominatim.
/// Returns a [Map] with keys: `full`, `area`, `state`.
/// Usage:
/// ```dart
///   final result = await showModalBottomSheet<Map<String, String>>(
///     context: context,
///     isScrollControlled: true,
///     shape: const RoundedRectangleBorder(
///       borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
///     ),
///     builder: (_) => const LocationSearchSheet(),
///   );
/// ```
class LocationSearchSheet extends StatefulWidget {
  const LocationSearchSheet({super.key});

  @override
  State<LocationSearchSheet> createState() => _LocationSearchSheetState();
}

class _LocationSearchSheetState extends State<LocationSearchSheet> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;
  String _errorMsg = '';
  DateTime _lastSearch = DateTime.now();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().length < 3) {
      setState(() {
        _results = [];
        _errorMsg = '';
      });
      return;
    }

    // Nominatim rate limit: 1 request per second
    final now = DateTime.now();
    final diff = now.difference(_lastSearch).inMilliseconds;
    if (diff < 1000) {
      await Future.delayed(Duration(milliseconds: 1000 - diff));
    }
    _lastSearch = DateTime.now();

    setState(() {
      _isLoading = true;
      _errorMsg = '';
    });

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query.trim())}'
        '&countrycodes=my'
        '&format=json'
        '&addressdetails=1'
        '&limit=10',
      );

      final response = await http.get(uri, headers: {
        'User-Agent': 'LaporFix/1.0 (student project)',
      });

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _results = data.map((item) {
            final address = item['address'] as Map<String, dynamic>? ?? {};
            final suburb = address['suburb'] ??
                address['village'] ??
                address['town'] ??
                address['city_district'] ??
                '';
            final city =
                address['city'] ?? address['town'] ?? address['county'] ?? '';
            final state = address['state'] ?? '';

            return {
              'display': item['display_name'] ?? '',
              'suburb': suburb,
              'city': city,
              'state': state,
            };
          }).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMsg = 'Search failed. Try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = 'Network error: $e';
          _isLoading = false;
        });
      }
    }
  }

  String _formatLocation(Map<String, dynamic> result) {
    final parts = <String>[];
    if (result['suburb'].toString().isNotEmpty) parts.add(result['suburb']);
    if (result['city'].toString().isNotEmpty &&
        result['city'] != result['suburb']) {
      parts.add(result['city']);
    }
    if (result['state'].toString().isNotEmpty) parts.add(result['state']);
    return parts.isNotEmpty ? parts.join(', ') : result['display'];
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Select Your Location', style: tt.titleLarge),
              const SizedBox(height: 4),
              Text('Search any location in Malaysia', style: tt.bodySmall),
              const SizedBox(height: 12),

              // Search field
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceGrey,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD1D5DB)),
                ),
                child: TextField(
                  controller: _searchController,
                  onSubmitted: _search,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(fontSize: 16),
                  decoration: const InputDecoration(
                    hintText: 'Type location and press Enter...',
                    hintStyle: TextStyle(color: AppTheme.textSecondary),
                    prefixIcon:
                        Icon(Icons.search, color: AppTheme.textSecondary),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_errorMsg.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_errorMsg,
                      style: tt.bodySmall?.copyWith(color: Colors.red)),
                )
              else if (_results.isEmpty && _searchController.text.length >= 3)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No results found.', style: tt.bodySmall),
                )
              else
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final result = _results[index];
                      final formatted = _formatLocation(result);
                      return ListTile(
                        leading: const Icon(Icons.location_on_outlined,
                            color: AppTheme.primaryBlue),
                        title: Text(
                          formatted,
                          style:
                              tt.bodySmall?.copyWith(color: AppTheme.textPrimary),
                        ),
                        subtitle: Text(
                          result['display'],
                          style: tt.bodySmall?.copyWith(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          final area = result['suburb'].toString().isNotEmpty
                              ? result['suburb']
                              : result['city'];
                          Navigator.pop(context, {
                            'full': formatted,
                            'area': area.toString(),
                            'state': result['state'].toString(),
                          });
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
