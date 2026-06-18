import 'package:flutter/material.dart';
import 'package:app_tour_flutter/app_tour_flutter.dart';
import '../services/app_settings_service.dart';

class _StepData {
  final GlobalKey targetKey;
  final String title;
  final String description;
  const _StepData(this.targetKey, this.title, this.description);
}

class AppTour {
  static void start({
    required BuildContext context,
    required GlobalKey homeKey,
    required GlobalKey issueKey,
    required GlobalKey communityKey,
    required GlobalKey profileKey,
    required GlobalKey chatbotKey,
  }) {
    final steps = [
      _StepData(
        homeKey,
        'Welcome to LaporFix!',
        'Your one-stop app for reporting and tracking community issues. Let\'s take a quick tour!',
      ),
      _StepData(
        homeKey,
        'Home',
        'Stay informed with the latest announcements from your local council and community.',
      ),
      _StepData(
        issueKey,
        'Issue Tracker',
        'Report issues like potholes, broken streetlights, or illegal dumping and track their status in real-time.',
      ),
      _StepData(
        communityKey,
        'Community',
        'See what issues your neighbors care about. Vote on community priorities and discuss solutions.',
      ),
      _StepData(
        profileKey,
        'Profile',
        'Manage your account, adjust settings, and review all your reported issues in one place.',
      ),
      _StepData(
        chatbotKey,
        'AI Assistant',
        'Need help? Tap the chat button anytime to ask our AI assistant questions about reporting issues.',
      ),
      _StepData(
        homeKey,
        'You\'re All Set!',
        'Start exploring LaporFix and help make your community better!',
      ),
    ];

    _AppTourOverlay.show(context: context, steps: steps);
  }
}

class _AppTourOverlay {
  static void show({
    required BuildContext context,
    required List<_StepData> steps,
  }) {
    OverlayEntry? entry;
    var currentStep = 0;

    void showStep() {
      if (currentStep >= steps.length) {
        entry?.remove();
        entry = null;
        AppSettingsService.instance.completeAppTour();
        return;
      }

      final step = steps[currentStep];
      final targetContext = step.targetKey.currentContext;
      if (targetContext == null || !targetContext.mounted) {
        entry?.remove();
        entry = null;
        return;
      }

      final renderBox = targetContext.findRenderObject() as RenderBox;
      final position = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;

      const bubbleHeight = 100.0;
      const tooltipGap = 108.0;
      const bubbleWidth = 320.0;
      const highlightPadding = 12.0;
      final screenSize = MediaQuery.of(targetContext).size;
      final statusBarHeight = MediaQuery.of(targetContext).padding.top;
      final safeTopPadding = statusBarHeight + 12.0;

      final showAbove = position.dy > bubbleHeight + tooltipGap;

      final targetCenterX = position.dx + size.width / 2;
      double bubbleLeft = targetCenterX - bubbleWidth / 2;
      bubbleLeft = bubbleLeft.clamp(
        16.0,
        screenSize.width - bubbleWidth - 16.0,
      );

      double bubbleTop = showAbove
          ? position.dy - bubbleHeight - tooltipGap
          : position.dy + size.height + tooltipGap;

      if (showAbove && bubbleTop < safeTopPadding) {
        bubbleTop = position.dy + size.height + tooltipGap;
      } else if (!showAbove && (bubbleTop + bubbleHeight > screenSize.height)) {
        bubbleTop = position.dy - bubbleHeight - tooltipGap;
      }

      final isActuallyAbove = bubbleTop < position.dy;
      final trianglePositionPercentage =
          (targetCenterX - bubbleLeft) / bubbleWidth;

      entry?.remove();
      entry = OverlayEntry(
        builder: (_) => GestureDetector(
          onTap: () {
            currentStep++;
            showStep();
          },
          child: Material(
            color: Colors.grey.withValues(alpha: 0.2),
            child: Stack(
              children: [
                Positioned.fill(
                  child: HoleOverlay(
                    holeRect: Rect.fromLTWH(
                      position.dx - highlightPadding,
                      position.dy - highlightPadding,
                      size.width + highlightPadding * 2,
                      size.height + highlightPadding * 2,
                    ),
                  ),
                ),
                Positioned(
                  top: bubbleTop,
                  left: bubbleLeft,
                  child: CustomSpeechBubble(
                    width: bubbleWidth,
                    title: step.title,
                    description: step.description,
                    isAbove: isActuallyAbove,
                    trianglePositionPercentage: trianglePositionPercentage,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      Overlay.of(context, rootOverlay: true).insert(entry!);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      showStep();
    });
  }
}
