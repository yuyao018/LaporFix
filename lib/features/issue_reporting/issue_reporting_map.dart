import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:group2_urbanfix/theme/app_theme.dart';
import 'package:group2_urbanfix/widgets/function_appbar.dart';
import 'package:group2_urbanfix/features/issue_reporting/viewmodels/issue_reporting_view_model.dart';

class IssueReportingMap extends StatefulWidget {
  final IssueReportingViewModel viewModel;

  const IssueReportingMap({super.key, required this.viewModel});

  @override
  State<IssueReportingMap> createState() => _IssueReportingMapState();
}

class _IssueReportingMapState extends State<IssueReportingMap> {
  late final IssueReportingViewModel viewModel;
  // Controls OpenStreetMap camera movement
  final MapController _mapController = MapController();
  // Controls search field focus state
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _addressDetailsFocusNode = FocusNode();
  final FocusNode _additionalNotesFocusNode = FocusNode();

  bool _isFormVisible = false;
  Timer? _searchDebounce;
  Timer? _reverseGeocodeDebounce;
  bool _isReverseGeocoding = false;

  // Initialize map location and retrieve the user's current location if needed
  @override
  void initState() {
    super.initState();
    viewModel = widget.viewModel;

    if (viewModel.report.latitude != null &&
        viewModel.report.longitude != null) {
      viewModel.currentPosition = LatLng(
        viewModel.report.latitude!,
        viewModel.report.longitude!,
      );
    }

    if (viewModel.addressController.text.isEmpty) {
      viewModel.getCurrentLocation().then((_) {
        if (mounted) {
          _mapController.move(viewModel.currentPosition, 15.0);
          setState(() {}); // Refresh UI to synchronize map and marker position
        }
      });
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _reverseGeocodeDebounce?.cancel();
    _searchFocusNode.dispose();
    _addressDetailsFocusNode.dispose();
    _additionalNotesFocusNode.dispose();
    _mapController.dispose(); // Release resources to prevent memory leaks
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final isKeyboardVisible = keyboardInset > 0;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: FunctionAppBar(
        title: 'Create Report',
        onBack: () {
          if (_isFormVisible) {
            setState(() {
              _isFormVisible = false;
            });
          } else {
            Navigator.pop(context);
          }
        },
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.functionBackground),
        child: SafeArea(
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + keyboardInset),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFEDF8F8),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  // --- MAP AREA SECTION ---
                  Expanded(
                    flex: _isFormVisible ? (isKeyboardVisible ? 6 : 12) : 100,
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(24),
                          topRight: const Radius.circular(24),
                          bottomLeft: Radius.circular(_isFormVisible ? 0 : 24),
                          bottomRight: Radius.circular(_isFormVisible ? 0 : 24),
                        ),
                      ),
                      child: Stack(
                        children: [
                          FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: viewModel.currentPosition,
                              initialZoom: 15.0,
                              interactionOptions: InteractionOptions(
                                flags: _isFormVisible
                                    ? InteractiveFlag.none
                                    : InteractiveFlag.all,
                              ),
                              onPositionChanged: (camera, hasGesture) {
                                if (_isFormVisible) return;
                                if (hasGesture) {
                                  viewModel.updateMapLocation(camera.center);
                                  viewModel.clearSuggestions();
                                  setState(() {});

                                  // Debounce reverse geocode — fires 800ms after dragging stops
                                  _reverseGeocodeDebounce?.cancel();
                                  _reverseGeocodeDebounce = Timer(
                                    const Duration(milliseconds: 800),
                                    () async {
                                      if (!mounted) return;
                                      setState(() => _isReverseGeocoding = true);
                                      final address = await viewModel
                                          .locationService
                                          .getAddress(
                                            camera.center.latitude,
                                            camera.center.longitude,
                                          );
                                      if (!mounted) return;
                                      viewModel.addressController.text = address;
                                      viewModel.setAddress(address);
                                      setState(() => _isReverseGeocoding = false);
                                    },
                                  );
                                }
                              },
                              onTap: (_, _) {
                                if (_isFormVisible) {
                                  return; // Disable map interaction while the form is displayed
                                }
                                _searchFocusNode.unfocus();
                                setState(() {
                                  viewModel.clearSuggestions();
                                });
                              },
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.group2.urbanfix',
                              ),
                            ],
                          ),

                          // Center Marker Pointer
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 32.0),
                              child: Icon(
                                Icons.location_on,
                                size: 42.0,
                                color: Colors.redAccent.shade700,
                              ),
                            ),
                          ),

                          // Top Floating Search Bar & Auto-Suggestions Overlay
                          Positioned(
                            top: 16,
                            left: 16,
                            right: 16,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius:
                                        viewModel.searchSuggestions.isNotEmpty
                                        ? const BorderRadius.only(
                                            topLeft: Radius.circular(12),
                                            topRight: Radius.circular(12),
                                          )
                                        : BorderRadius.circular(12),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: TextField(
                                    controller: viewModel.addressController,
                                    focusNode: _searchFocusNode,
                                    enabled: !_isFormVisible,
                                    style: TextStyle(
                                      // Reduce font size when the form is visible
                                      fontSize: _isFormVisible ? 15.0 : 16.0,
                                      color: _isFormVisible
                                          ? Colors.grey[600]
                                          : Colors.black87,
                                    ),
                                    onChanged: (value) {
                                      viewModel.setAddress(value);
                                      _searchDebounce?.cancel();
                                      _searchDebounce = Timer(
                                        const Duration(milliseconds: 500),
                                        () {
                                          viewModel.searchAddress(value).then((_) {
                                            if (mounted) setState(() {});
                                          });
                                        },
                                      );
                                    },
                                    decoration: InputDecoration(
                                      hintText: 'Enter location here...',
                                      hintStyle: const TextStyle(
                                        fontSize: 15,
                                        color: Colors.grey,
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.search,
                                        color: Colors.grey,
                                        size: 22,
                                      ),
                                      // Reduce font size when the form is visible
                                      suffixIcon: _isFormVisible
                                          ? null
                                          : (_isReverseGeocoding || viewModel.isSearching
                                                ? const Padding(
                                                    padding: EdgeInsets.all(
                                                      12.0,
                                                    ),
                                                    child: SizedBox(
                                                      width: 16,
                                                      height: 16,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                          ),
                                                    ),
                                                  )
                                                : viewModel
                                                      .addressController
                                                      .text
                                                      .isNotEmpty
                                                ? IconButton(
                                                    icon: const Icon(
                                                      Icons.clear,
                                                      color: Colors.grey,
                                                      size: 18,
                                                    ),
                                                    onPressed: () {
                                                      viewModel
                                                          .addressController
                                                          .clear();
                                                      viewModel.setAddress('');
                                                      viewModel
                                                          .clearSuggestions();
                                                      setState(() {});
                                                    },
                                                  )
                                                : null),
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                    ),
                                  ),
                                ),

                                // Display search suggestions returned by Nominatim
                                if (viewModel.searchSuggestions.isNotEmpty)
                                  Material(
                                    color: Colors.transparent,
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        maxHeight: 220,
                                      ),
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.only(
                                          bottomLeft: Radius.circular(12),
                                          bottomRight: Radius.circular(12),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black12,
                                            blurRadius: 4,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: ListView.separated(
                                        shrinkWrap: true,
                                        padding: EdgeInsets.zero,
                                        physics: const ClampingScrollPhysics(),
                                        itemCount:
                                            viewModel.searchSuggestions.length,
                                        separatorBuilder: (_, _) =>
                                            const Divider(
                                              height: 1,
                                              color: Color(0xFFEFEFEF),
                                            ),
                                        itemBuilder: (context, index) {
                                          final suggestion = viewModel
                                              .searchSuggestions[index];
                                          return ListTile(
                                            dense: true,
                                            leading: const Icon(
                                              Icons.location_on_outlined,
                                              color: Colors.grey,
                                              size: 18,
                                            ),
                                            title: Text(
                                              suggestion['display_name'] ?? '',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            onTap: () {
                                              final double lat = double.parse(
                                                suggestion['lat'].toString(),
                                              );
                                              final double lon = double.parse(
                                                suggestion['lon'].toString(),
                                              );
                                              final targetLatLng = LatLng(
                                                lat,
                                                lon,
                                              );

                                              _searchFocusNode.unfocus();
                                              viewModel.updateMapLocation(
                                                targetLatLng,
                                              );
                                              viewModel.addressController.text =
                                                  suggestion['display_name'] ?? '';
                                              viewModel.setAddress(
                                                suggestion['display_name'] ?? '',
                                              );
                                              viewModel.clearSuggestions();
                                              setState(() {});

                                              // Move camera after the frame rebuilds
                                              WidgetsBinding.instance
                                                  .addPostFrameCallback((_) {
                                                _mapController.move(
                                                  targetLatLng,
                                                  16.0,
                                                );
                                              });
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // Proceed to address details and notes section
                          if (!_isFormVisible)
                            Positioned(
                              bottom: 24,
                              left: 16,
                              right: 16,
                              child: SizedBox(
                                height: 48,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.accentBlue,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () {
                                    _searchFocusNode.unfocus();
                                    setState(() {
                                      _isFormVisible = true;
                                    });
                                  },
                                  child: Text(
                                    'Next',
                                    style: AppTheme.appTextTheme.labelLarge
                                        ?.copyWith(
                                          fontSize: 16,
                                          color: Colors.white,
                                        ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Details form section
                  if (_isFormVisible)
                    Expanded(
                      flex: isKeyboardVisible ? 17 : 11,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Address Details (Optional)',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller:
                                          viewModel.addressDetailsController,
                                      focusNode: _addressDetailsFocusNode,
                                      textInputAction: TextInputAction.next,
                                      style: const TextStyle(
                                        fontSize: 14.0,
                                        color: Colors.black87,
                                      ),
                                      onTap: () {
                                        final fieldContext =
                                            _addressDetailsFocusNode.context;
                                        if (fieldContext != null) {
                                          Scrollable.ensureVisible(
                                            fieldContext,
                                            duration: const Duration(
                                              milliseconds: 250,
                                            ),
                                            curve: Curves.easeOut,
                                            alignment: 0.2,
                                          );
                                        }
                                      },
                                      onSubmitted: (_) {
                                        _additionalNotesFocusNode
                                            .requestFocus();
                                      },
                                      onChanged: viewModel.updateAddressDetails,
                                      decoration: InputDecoration(
                                        hintText: 'e.g., Block A, Unit 12',
                                        hintStyle: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                        ),
                                        filled: true,
                                        fillColor: Colors.white,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 12,
                                            ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Colors.black12,
                                            width: 1,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Colors.black26,
                                            width: 1.2,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    const Text(
                                      'Additional Notes (Optional)',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller:
                                          viewModel.additionalNotesController,
                                      focusNode: _additionalNotesFocusNode,
                                      maxLines: 5,
                                      textInputAction: TextInputAction.done,
                                      style: const TextStyle(
                                        fontSize: 14.0,
                                        color: Colors.black87,
                                      ),
                                      onTap: () {
                                        final fieldContext =
                                            _additionalNotesFocusNode.context;
                                        if (fieldContext != null) {
                                          Scrollable.ensureVisible(
                                            fieldContext,
                                            duration: const Duration(
                                              milliseconds: 250,
                                            ),
                                            curve: Curves.easeOut,
                                            alignment: 0.1,
                                          );
                                        }
                                      },
                                      // Update additional notes in the ViewModel
                                      onChanged: (value) => viewModel
                                          .updateAdditionalNotes(value),
                                      decoration: InputDecoration(
                                        hintText:
                                            'Enter more information here...',
                                        hintStyle: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                        ),
                                        filled: true,
                                        fillColor: Colors.white,
                                        contentPadding: const EdgeInsets.all(
                                          14,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Colors.black12,
                                            width: 1,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Colors.black26,
                                            width: 1.2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.accentBlue,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () async {
                                  FocusScope.of(context).unfocus();
                                  await viewModel.submitReport(context);
                                },
                                child: Text(
                                  'Submit Report',
                                  style: AppTheme.appTextTheme.labelLarge
                                      ?.copyWith(
                                        fontSize: 16,
                                        color: Colors.white,
                                      ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
