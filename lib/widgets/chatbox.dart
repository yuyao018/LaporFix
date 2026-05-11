import 'dart:math' as math;
import 'package:flutter/material.dart';

class ChatBox extends StatefulWidget {
  final ValueChanged<String>? onSend;
  final String hintText;
  final bool showPlusButton;
  final VoidCallback? onUploadImage;
  final VoidCallback? onUploadDoc;

  const ChatBox({
    super.key,
    this.onSend,
    required this.hintText,
    this.showPlusButton = false,
    this.onUploadImage,
    this.onUploadDoc,
  });

  @override
  State<ChatBox> createState() => _ChatBoxState();
}

class _ChatBoxState extends State<ChatBox> {
  final TextEditingController _controller = TextEditingController();
  bool _showUploadOptions = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend?.call(text);
    _controller.clear();
  }

  void _toggleUploadOptions() {
    setState(() => _showUploadOptions = !_showUploadOptions);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    return Container(
      color: const Color(0xFFF3F4F6),
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Upload options tray ────────────────────────────────
          if (widget.showPlusButton && _showUploadOptions)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  _UploadOption(
                    icon: Icons.image_outlined,
                    label: 'Upload Image',
                    onTap: () {
                      setState(() => _showUploadOptions = false);
                      widget.onUploadImage?.call();
                    },
                  ),
                  const SizedBox(width: 12),
                  _UploadOption(
                    icon: Icons.description_outlined,
                    label: 'Upload Doc',
                    onTap: () {
                      setState(() => _showUploadOptions = false);
                      widget.onUploadDoc?.call();
                    },
                  ),
                ],
              ),
            ),

          // ── Input row ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            child: Row(
              children: [
                // ── Plus button ──────────────────────────────────
                if (widget.showPlusButton) ...[
                  GestureDetector(
                    onTap: _toggleUploadOptions,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _showUploadOptions
                            ? const Color(0xFF5F80F8)
                            : const Color(0xFFE5E7EB),
                      ),
                      child: Icon(
                        _showUploadOptions ? Icons.close : Icons.add,
                        color: _showUploadOptions
                            ? Colors.white
                            : const Color(0xFF5F80F8),
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],

                // ── Text field ───────────────────────────────────
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(
                          color: const Color(0xFFD1D5DB), width: 1),
                    ),
                    child: TextField(
                      controller: _controller,
                      onSubmitted: (_) => _handleSend(),
                      style: const TextStyle(
                          fontSize: 14, color: Color(0xFF1A1A2E)),
                      decoration: InputDecoration(
                        hintText: widget.hintText,
                        hintStyle: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 14,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // ── Send button ──────────────────────────────────
                GestureDetector(
                  onTap: _handleSend,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF5F80F8), Color(0xFF1CE6DA)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Transform.rotate(
                        angle: -math.pi / 6,
                        child: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Upload option chip ───────────────────────────────────────────────────────
class _UploadOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _UploadOption({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFD1D5DB), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: const Color(0xFF5F80F8)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
