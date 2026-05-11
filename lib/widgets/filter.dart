import 'package:flutter/material.dart';

class FilterBar extends StatefulWidget {
  final List<String> filters;
  final String? initialFilter;
  final ValueChanged<String>? onFilterChanged;

  const FilterBar({
    super.key,
    required this.filters,
    this.initialFilter,
    this.onFilterChanged,
  });

  @override
  State<FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<FilterBar> {
  late String _activeFilter;

  static const Color _blue = Color(0xFF0084FF);

  @override
  void initState() {
    super.initState();
    _activeFilter = widget.initialFilter ?? widget.filters.first;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: widget.filters.length,
        separatorBuilder: (_, s) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = widget.filters[index];
          final isActive = filter == _activeFilter;

          return GestureDetector(
            onTap: () {
              setState(() => _activeFilter = filter);
              widget.onFilterChanged?.call(filter);
            },
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: ShapeDecoration(
                shape: const StadiumBorder(),
                color: isActive
                    ? _blue
                    : _blue.withValues(alpha: 0.12),
              ),
              child: Text(
                filter,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive ? Colors.white : _blue,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
