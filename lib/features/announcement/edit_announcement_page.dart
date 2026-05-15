import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../../widgets/function_appbar.dart';
import '../../widgets/button.dart';
import '../../theme/app_theme.dart';
import 'colours.dart';

class EditAnnouncementPage extends StatefulWidget {
  final String docId;

  const EditAnnouncementPage({super.key, required this.docId});

  @override
  State<EditAnnouncementPage> createState() => _EditAnnouncementPageState();
}

class _EditAnnouncementPageState extends State<EditAnnouncementPage> {
  final _titleController = TextEditingController();
  final _captionController = TextEditingController();

  String _selectedColour = 'green';
  String _selectedAudience = 'all';
  String _selectedLocation = '';
  bool _isLoading = true;
  bool _isSaving = false;

  // Existing attachments from Firestore
  List<Map<String, dynamic>> _existingAttachments = [];
  // New attachments to upload
  final List<_NewAttachment> _newAttachments = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final doc = await FirebaseFirestore.instance
        .collection('announcements')
        .doc(widget.docId)
        .get();

    if (doc.exists && mounted) {
      final data = doc.data()!;
      final target = data['target'] as Map<String, dynamic>? ?? {};
      final location = target['location'] as Map<String, dynamic>? ?? {};
      final attachments = (data['attachments'] as List<dynamic>?) ?? [];

      setState(() {
        _titleController.text = data['title'] ?? '';
        _captionController.text = data['caption'] ?? '';
        _selectedColour = data['colour'] ?? 'green';
        _selectedAudience = target['audience'] ?? 'all';
        _selectedLocation = location['full'] ?? '';
        _existingAttachments =
            attachments.map((a) => Map<String, dynamic>.from(a as Map)).toList();
        _isLoading = false;
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Attachment picking ─────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null && mounted) {
        setState(() {
          _newAttachments.add(_NewAttachment(
            file: File(image.path),
            name: image.name,
            type: 'image',
          ));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image pick error: $e')),
        );
      }
    }
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result != null && result.files.single.path != null && mounted) {
        setState(() {
          _newAttachments.add(_NewAttachment(
            file: File(result.files.single.path!),
            name: result.files.single.name,
            type: 'document',
          ));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Document pick error: $e')),
        );
      }
    }
  }

  Future<void> _pickVideo() async {
    try {
      final picker = ImagePicker();
      final video = await picker.pickVideo(source: ImageSource.gallery);
      if (video != null && mounted) {
        setState(() {
          _newAttachments.add(_NewAttachment(
            file: File(video.path),
            name: video.name,
            type: 'video',
          ));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Video pick error: $e')),
        );
      }
    }
  }

  void _removeExistingAttachment(int index) {
    setState(() => _existingAttachments.removeAt(index));
  }

  void _removeNewAttachment(int index) {
    setState(() => _newAttachments.removeAt(index));
  }

  // ── Location picker ────────────────────────────────────────────────────────

  Future<void> _showLocationPicker() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _LocationSearchSheet(),
    );

    if (result != null && mounted) {
      setState(() => _selectedLocation = result);
    }
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final caption = _captionController.text.trim();

    if (title.isEmpty || caption.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and caption cannot be empty.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Upload new attachments
      final List<Map<String, String>> uploadedNew = [];
      for (final attachment in _newAttachments) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('announcements')
            .child('${DateTime.now().millisecondsSinceEpoch}_${attachment.name}');
        await ref.putFile(attachment.file);
        final url = await ref.getDownloadURL();
        uploadedNew.add({
          'url': url,
          'name': attachment.name,
          'type': attachment.type,
        });
      }

      // Combine existing + new attachments
      final allAttachments = [
        ..._existingAttachments,
        ...uploadedNew,
      ];

      // Parse location
      final locationParts = _selectedLocation.split(', ');
      final area = locationParts.isNotEmpty ? locationParts[0] : '';
      final city = locationParts.length > 1 ? locationParts[1] : '';
      final state = locationParts.length > 2 ? locationParts[2] : '';

      await FirebaseFirestore.instance
          .collection('announcements')
          .doc(widget.docId)
          .update({
        'title': title,
        'caption': caption,
        'colour': _selectedColour,
        'attachments': allAttachments,
        'target': {
          'audience': _selectedAudience,
          'location': {
            'area': area,
            'city': city,
            'state': state,
            'full': _selectedLocation,
          },
        },
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Announcement updated.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    if (_isLoading) {
      return Scaffold(
        appBar: const FunctionAppBar(title: 'Edit Announcement'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final audienceOptions = ['everyone', 'admin', 'residents'];

    return Scaffold(
      appBar: const FunctionAppBar(title: 'Edit Announcement'),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.white,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Title & Caption ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFD1D5DB)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _titleController,
                      style: tt.titleLarge,
                      decoration: InputDecoration(
                        hintText: 'Title',
                        hintStyle:
                            tt.titleLarge?.copyWith(color: AppTheme.textSecondary),
                        border: InputBorder.none,
                      ),
                    ),
                    const Divider(height: 1),
                    TextField(
                      controller: _captionController,
                      style: tt.bodyLarge?.copyWith(fontSize: 16),
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Caption',
                        hintStyle:
                            tt.bodyMedium?.copyWith(color: AppTheme.textSecondary),
                        border: InputBorder.none,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Attachments ──
              Row(
                children: [
                  Text('Attach', style: tt.titleLarge?.copyWith(fontSize: 16)),
                  const SizedBox(width: 4),
                  const Text('📎', style: TextStyle(fontSize: 16)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _ChipOption(label: 'Image', onTap: _pickImage),
                  const SizedBox(width: 8),
                  _ChipOption(label: 'Document', onTap: _pickDocument),
                  const SizedBox(width: 8),
                  _ChipOption(label: 'Video', onTap: _pickVideo),
                ],
              ),

              // Existing attachments
              if (_existingAttachments.isNotEmpty) ...[
                const SizedBox(height: 12),
                ..._existingAttachments.asMap().entries.map((entry) {
                  final i = entry.key;
                  final a = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          a['type'] == 'image'
                              ? Icons.image
                              : a['type'] == 'video'
                                  ? Icons.videocam
                                  : Icons.description,
                          color: AppTheme.primaryBlue,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            a['name'] ?? 'File',
                            style: tt.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _removeExistingAttachment(i),
                          child: const Icon(Icons.close, size: 18, color: Colors.red),
                        ),
                      ],
                    ),
                  );
                }),
              ],

              // New attachments
              if (_newAttachments.isNotEmpty) ...[
                const SizedBox(height: 8),
                ..._newAttachments.asMap().entries.map((entry) {
                  final i = entry.key;
                  final a = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          a.type == 'image'
                              ? Icons.image
                              : a.type == 'video'
                                  ? Icons.videocam
                                  : Icons.description,
                          color: AppTheme.primaryBlue,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${a.name} (new)',
                            style: tt.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _removeNewAttachment(i),
                          child: const Icon(Icons.close, size: 18, color: Colors.red),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              const SizedBox(height: 24),

              // ── Mention / Audience ──
              Row(
                children: [
                  Text('Mention', style: tt.titleLarge?.copyWith(fontSize: 16)),
                  const SizedBox(width: 4),
                  const Text('💬', style: TextStyle(fontSize: 16)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: audienceOptions.map((option) {
                  final isSelected = _selectedAudience == option;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedAudience = option),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryBlue
                              : AppTheme.surfaceGrey,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primaryBlue
                                : const Color(0xFFD1D5DB),
                          ),
                        ),
                        child: Text(
                          option[0].toUpperCase() + option.substring(1),
                          style: TextStyle(
                            fontSize: 14,
                            color:
                                isSelected ? Colors.white : AppTheme.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // ── Location ──
              Row(
                children: [
                  Text('Location', style: tt.titleLarge?.copyWith(fontSize: 16)),
                  const SizedBox(width: 4),
                  const Text('📌', style: TextStyle(fontSize: 16)),
                ],
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _showLocationPicker,
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFD1D5DB)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedLocation.isEmpty
                              ? 'Select location'
                              : _selectedLocation,
                          style: TextStyle(
                            fontSize: 16,
                            color: _selectedLocation.isEmpty
                                ? AppTheme.textSecondary
                                : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Colour ──
              Row(
                children: [
                  Text('Colour', style: tt.titleLarge?.copyWith(fontSize: 16)),
                  const SizedBox(width: 4),
                  const Text('💡', style: TextStyle(fontSize: 16)),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFD1D5DB)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedColour,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down),
                    items: AnnouncementColours.names.map((c) {
                      return DropdownMenuItem(
                        value: c,
                        child: Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: AnnouncementColours.get(c).border,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(c[0].toUpperCase() + c.substring(1)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedColour = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ── Save button ──
              _isSaving
                  ? const Center(child: CircularProgressIndicator())
                  : PrimaryButton(
                      label: 'Save Changes',
                      onPressed: _save,
                    ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// New Attachment model
// ─────────────────────────────────────────────────────────────────────────────

class _NewAttachment {
  final File file;
  final String name;
  final String type;

  _NewAttachment({required this.file, required this.name, required this.type});
}

// ─────────────────────────────────────────────────────────────────────────────
// Chip Option
// ─────────────────────────────────────────────────────────────────────────────

class _ChipOption extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _ChipOption({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceGrey,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFD1D5DB)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Location Search Bottom Sheet (Nominatim)
// ─────────────────────────────────────────────────────────────────────────────

class _LocationSearchSheet extends StatefulWidget {
  const _LocationSearchSheet();

  @override
  State<_LocationSearchSheet> createState() => _LocationSearchSheetState();
}

class _LocationSearchSheetState extends State<_LocationSearchSheet> {
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
            final city = address['city'] ??
                address['town'] ??
                address['county'] ??
                '';
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
              Text('Select Location', style: tt.titleLarge),
              const SizedBox(height: 4),
              Text('Search any location in Malaysia', style: tt.bodySmall),
              const SizedBox(height: 12),
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
                        title: Text(formatted,
                            style: tt.bodySmall
                                ?.copyWith(color: AppTheme.textPrimary)),
                        subtitle: Text(
                          result['display'],
                          style: tt.bodySmall?.copyWith(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.pop(context, formatted),
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
