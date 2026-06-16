import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../../widgets/function_appbar.dart';
import '../../widgets/button.dart';
import '../../theme/app_theme.dart';
import 'colours.dart';

class CreateAnnouncementPage extends StatefulWidget {
  const CreateAnnouncementPage({super.key});

  @override
  State<CreateAnnouncementPage> createState() => _CreateAnnouncementPageState();
}

class _CreateAnnouncementPageState extends State<CreateAnnouncementPage> {
  final _titleController = TextEditingController();
  final _captionController = TextEditingController();

  String _selectedAudience = 'all';
  String _selectedLocation = '';
  String _selectedColour = 'green';
  bool _isSubmitting = false;

  // Attachments
  final List<_Attachment> _attachments = [];

  final List<String> _audienceOptions = ['Everyone', 'Admin', 'Residents'];
  final List<String> _colourOptions = AnnouncementColours.names;

  @override
  void dispose() {
    _titleController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  // ── Attachment picking ─────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null && mounted) {
        setState(() {
          _attachments.add(
            _Attachment(
              file: File(image.path),
              name: image.name,
              type: AttachmentType.image,
            ),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Image pick error: $e')));
      }
    }
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result != null && result.files.single.path != null && mounted) {
        setState(() {
          _attachments.add(
            _Attachment(
              file: File(result.files.single.path!),
              name: result.files.single.name,
              type: AttachmentType.document,
            ),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Document pick error: $e')));
      }
    }
  }

  Future<void> _pickVideo() async {
    try {
      final picker = ImagePicker();
      final video = await picker.pickVideo(source: ImageSource.gallery);
      if (video != null && mounted) {
        setState(() {
          _attachments.add(
            _Attachment(
              file: File(video.path),
              name: video.name,
              type: AttachmentType.video,
            ),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Video pick error: $e')));
      }
    }
  }

  void _removeAttachment(int index) {
    setState(() => _attachments.removeAt(index));
  }

  // ── Upload attachments to Firebase Storage ─────────────────────────────────

  Future<List<Map<String, String>>> _uploadAttachments() async {
    final List<Map<String, String>> uploaded = [];

    for (final attachment in _attachments) {
      final ref = FirebaseStorage.instance
          .ref()
          .child('announcements')
          .child('${DateTime.now().millisecondsSinceEpoch}_${attachment.name}');

      await ref.putFile(attachment.file);
      final url = await ref.getDownloadURL();

      uploaded.add({
        'url': url,
        'name': attachment.name,
        'type': attachment.type.name,
      });
    }

    return uploaded;
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

  // ── Submit ─────────────────────────────────────────────────────────────────

  Future<void> _submitPost() async {
    final title = _titleController.text.trim();
    final caption = _captionController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a title.')));
      return;
    }

    if (caption.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a caption.')));
      return;
    }

    if (_selectedLocation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a location.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      // Upload attachments if any
      List<Map<String, String>> attachmentUrls = [];
      if (_attachments.isNotEmpty) {
        attachmentUrls = await _uploadAttachments();
      }

      // Parse location parts
      final locationParts = _selectedLocation.split(', ');
      final area = locationParts.isNotEmpty ? locationParts[0] : '';
      final city = locationParts.length > 1 ? locationParts[1] : '';
      final state = locationParts.length > 2 ? locationParts[2] : '';

      await FirebaseFirestore.instance.collection('announcements').add({
        'title': title,
        'caption': caption,
        'colour': _selectedColour,
        'announcerID': user?.uid ?? 'adminid',
        'createdAt': FieldValue.serverTimestamp(),
        'fcmSent': false,
        'isDeleted': false,
        'attachments': attachmentUrls,
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

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const _SuccessScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: const FunctionAppBar(title: 'Create New Post'),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppTheme.functionBackground,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Title & Caption input ──
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _titleController,
                        style: tt.titleLarge?.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter your title',
                          hintStyle: tt.titleLarge?.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textSecondary,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const Divider(height: 24, color: Color(0xFFE5E7EB)),
                      TextField(
                        controller: _captionController,
                        style: tt.bodyMedium?.copyWith(fontSize: 16),
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: 'Enter your captions..',
                          hintStyle: tt.bodyMedium?.copyWith(
                            fontSize: 16,
                            color: AppTheme.textSecondary,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Attach section ──
                Row(
                  children: [
                    Text(
                      'Attach',
                      style: tt.titleMedium?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('🔗', style: TextStyle(fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _ChipOption(label: 'Image', onTap: _pickImage),
                    const SizedBox(width: 12),
                    _ChipOption(label: 'Document', onTap: _pickDocument),
                    const SizedBox(width: 12),
                    _ChipOption(label: 'Video', onTap: _pickVideo),
                  ],
                ),

                // ── Attachment previews ──
                if (_attachments.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ..._attachments.asMap().entries.map((entry) {
                    final i = entry.key;
                    final a = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            a.type == AttachmentType.image
                                ? Icons.image
                                : a.type == AttachmentType.video
                                ? Icons.videocam
                                : Icons.description,
                            color: AppTheme.primaryBlue,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              a.name,
                              style: tt.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _removeAttachment(i),
                            child: const Icon(
                              Icons.close,
                              size: 18,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 24),

                // ── Mention / Audience section ──
                Row(
                  children: [
                    Text(
                      'Mention',
                      style: tt.titleMedium?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('💬', style: TextStyle(fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  children: _audienceOptions.map((option) {
                    final value = option.toLowerCase();
                    final isSelected = _selectedAudience == value;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedAudience = value),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryBlue
                              : const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          option,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // ── Location picker ──
                Row(
                  children: [
                    Text(
                      'Location',
                      style: tt.titleMedium?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('📍', style: TextStyle(fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _showLocationPicker,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
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
                              fontWeight: FontWeight.w500,
                              color: _selectedLocation.isEmpty
                                  ? AppTheme.textSecondary
                                  : AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.keyboard_arrow_down,
                          color: AppTheme.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Colour dropdown ──
                Row(
                  children: [
                    Text(
                      'Colour',
                      style: tt.titleMedium?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('💡', style: TextStyle(fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedColour,
                      isExpanded: true,
                      icon: const Icon(
                        Icons.keyboard_arrow_down,
                        color: AppTheme.textSecondary,
                      ),
                      items: _colourOptions.map((c) {
                        return DropdownMenuItem(
                          value: c,
                          child: Row(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: _getColourPreview(c),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                c[0].toUpperCase() + c.substring(1),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
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

                // ── Submit button ──
                _isSubmitting
                    ? const Center(child: CircularProgressIndicator())
                    : PrimaryButton(label: 'Submit', onPressed: _submitPost),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getColourPreview(String colour) {
    return AnnouncementColours.get(colour).border;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Attachment model
// ─────────────────────────────────────────────────────────────────────────────

enum AttachmentType { image, document, video }

class _Attachment {
  final File file;
  final String name;
  final AttachmentType type;

  _Attachment({required this.file, required this.name, required this.type});
}

// ─────────────────────────────────────────────────────────────────────────────
// Chip Option (for Attach section)
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Location Search Bottom Sheet (OpenStreetMap Nominatim)
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

  // Debounce timer to avoid spamming the API
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
        '&limit=10'
        '&viewbox=99.0,7.5,120.0,0.5'
        '&bounded=1',
      );

      final response = await http.get(
        uri,
        headers: {'User-Agent': 'LaporFix/1.0 (student project)'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _results = data.map((item) {
            final address = item['address'] as Map<String, dynamic>? ?? {};
            // Build a readable display name from address parts
            final suburb =
                address['suburb'] ??
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
              // Handle bar
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
                    prefixIcon: Icon(
                      Icons.search,
                      color: AppTheme.textSecondary,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Loading / Error / Results
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_errorMsg.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _errorMsg,
                    style: tt.bodySmall?.copyWith(color: Colors.red),
                  ),
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
                        leading: const Icon(
                          Icons.location_on_outlined,
                          color: AppTheme.primaryBlue,
                        ),
                        title: Text(
                          formatted,
                          style: tt.bodySmall?.copyWith(
                            color: AppTheme.textPrimary,
                          ),
                        ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Success Screen
// ─────────────────────────────────────────────────────────────────────────────

class _SuccessScreen extends StatelessWidget {
  const _SuccessScreen();

  @override
  Widget build(BuildContext context) {
    Future.delayed(const Duration(seconds: 2), () {
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    });

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppTheme.functionBackground),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(40),
            margin: const EdgeInsets.symmetric(horizontal: 40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF4CAF50),
                  size: 80,
                ),
                const SizedBox(height: 16),
                Text(
                  'Announcement\nposted!',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontSize: 22),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
