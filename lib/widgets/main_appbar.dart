import 'package:flutter/material.dart';
import 'searchbar.dart';
import 'filter.dart';

class MainAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool insight;
  final bool showSearchBar;
  final bool showFilter;
  final bool showBottomContent;
  final List<String>? filterList;
  final Widget? bottomContent;
  final VoidCallback? onInsightTap;
  final ValueChanged<String>? onSearchChanged;
  final ValueChanged<String>? onSearchSubmitted;
  final ValueChanged<String>? onFilterChanged;

  const MainAppBar({
    super.key,
    this.title = "Announcement", // Default title
    this.insight = false,
    this.showSearchBar = false,
    this.showFilter = false,
    this.showBottomContent = false,
    this.filterList,
    this.bottomContent,
    this.onInsightTap,
    this.onSearchChanged,
    this.onSearchSubmitted,
    this.onFilterChanged,
  });

  double get _totalHeight {
    double height = 70.0; // base appbar height
    if (showSearchBar) height += 60.0;
    if (showFilter) height += 64.0; // 40px chip + 12px top + 10px bottom
    if (showBottomContent && bottomContent != null) height += 48.0;
    return height;
  }

  @override
  Widget build(BuildContext context) {
    return PreferredSize(
      preferredSize: Size.fromHeight(_totalHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Top bar row ──────────────────────────────────────────
          Container(
            color: Colors.white,
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 70,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(width: 16),
                    Expanded(
                      child: ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFF5F80F8), Color(0xFF1CE6DA)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ).createShader(bounds),
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 32,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    if (insight)
                      Padding(
                        padding: const EdgeInsets.only(right: 12.0),
                        child: TextButton.icon(
                          onPressed: onInsightTap,
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFFC5CDFF),
                          ),
                          icon: const Icon(Icons.bar_chart, color: Colors.black),
                          label: const Text(
                            'Insights',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ── Search bar ───────────────────────────────────────────
          if (showSearchBar)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: AppSearchBar(
                onChanged: onSearchChanged,
                onSubmitted: onSearchSubmitted,
              ),
            ),

          // ── Filter bar ───────────────────────────────────────────
          if (showFilter)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.only(top: 12, bottom: 10),
              child: FilterBar(
                filters: filterList ?? const ['All', 'To Review', 'In Review', 'Assigned', 'Completed'],
                onFilterChanged: onFilterChanged,
              ),
            ),

          // ── Bottom content ───────────────────────────────────────
          if (showBottomContent && bottomContent != null)
            Container(
              color: Colors.white,
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Center(child: bottomContent!),
            ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(_totalHeight);
}
