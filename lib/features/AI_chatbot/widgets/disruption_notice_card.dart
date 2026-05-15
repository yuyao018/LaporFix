import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import '../models/disruption_notice.dart';

class DisruptionNoticeCard extends StatelessWidget {
  final DisruptionNotice notice;

  const DisruptionNoticeCard({super.key, required this.notice});

  static const Color _innerBorderGrey = Color(0xFFD1D5DB);
  static const Color _stepLineGrey = Color(0xFFB0B8C4);
  static const Color _repairingYellow = Color(0xFFF5C518);
  static const Color _restoringGrey = Color(0xFF9CA3AF);

  _DisruptionStyle get _style => _DisruptionStyle.forType(notice.type);

  String _formatRestoration(DateTime dateTime) {
    final datePart = DateFormat('d MMMM y').format(dateTime);
    final timePart = DateFormat('h.mm a').format(dateTime);
    return '$datePart, $timePart';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final headerStyle = textTheme.titleLarge?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: AppTheme.textPrimary,
    );
    final labelStyle = textTheme.bodyLarge?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.bold,
      color: AppTheme.textPrimary,
    );
    final valueStyle = textTheme.bodyMedium?.copyWith(
      fontSize: 14,
      height: 1.45,
      color: AppTheme.textSecondary,
    );
    final stepLabelStyle = textTheme.bodySmall?.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppTheme.textPrimary,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _style.borderColor, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_style.icon, color: _style.iconColor, size: 26),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_style.headerLabel, style: headerStyle),
              ),
            ],
          ),
          if (notice.title.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              notice.title,
              style: textTheme.bodyLarge?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _innerBorderGrey, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusStepper(
                  status: notice.status,
                  labelStyle: stepLabelStyle,
                ),
                const SizedBox(height: 16),
                Text('Estimated Restoration:', style: labelStyle),
                const SizedBox(height: 4),
                Text(
                  _formatRestoration(notice.estimatedRestoration),
                  style: valueStyle?.copyWith(color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 12),
                Text('Reason:', style: labelStyle),
                const SizedBox(height: 4),
                Text(notice.reason, style: valueStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DisruptionStyle {
  final String headerLabel;
  final IconData icon;
  final Color iconColor;
  final Color borderColor;

  const _DisruptionStyle({
    required this.headerLabel,
    required this.icon,
    required this.iconColor,
    required this.borderColor,
  });

  factory _DisruptionStyle.forType(DisruptionType type) => switch (type) {
        DisruptionType.water => const _DisruptionStyle(
              headerLabel: 'Upcoming Water Cut',
              icon: Icons.water_drop,
              iconColor: Color(0xFF7EC8E3),
              borderColor: Color(0xFF5DD5F5),
            ),
        DisruptionType.power => const _DisruptionStyle(
              headerLabel: 'Upcoming Power Cut',
              icon: Icons.bolt,
              iconColor: Color(0xFFF59E0B),
              borderColor: Color(0xFFFBBF24),
            ),
        DisruptionType.road => const _DisruptionStyle(
              headerLabel: 'Upcoming Road Maintenance',
              icon: Icons.construction,
              iconColor: Color(0xFFEA580C),
              borderColor: Color(0xFFFB923C),
            ),
      };
}

class _StatusStepper extends StatelessWidget {
  final MaintenanceStatus status;
  final TextStyle? labelStyle;

  const _StatusStepper({
    required this.status,
    required this.labelStyle,
  });

  @override
  Widget build(BuildContext context) {
    final isRepairing = status == MaintenanceStatus.repairing;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepColumn(
          label: 'Repairing',
          labelStyle: labelStyle,
          node: _StepNode(
            color: DisruptionNoticeCard._repairingYellow,
            icon: isRepairing ? Icons.hourglass_empty : null,
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 16, left: 4, right: 4),
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: DisruptionNoticeCard._stepLineGrey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        _StepColumn(
          label: 'Restoring',
          labelStyle: labelStyle,
          node: const _StepNode(
            color: DisruptionNoticeCard._restoringGrey,
          ),
        ),
      ],
    );
  }
}

class _StepColumn extends StatelessWidget {
  final String label;
  final TextStyle? labelStyle;
  final Widget node;

  const _StepColumn({
    required this.label,
    required this.labelStyle,
    required this.node,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        node,
        const SizedBox(height: 6),
        Text(label, style: labelStyle, textAlign: TextAlign.center),
      ],
    );
  }
}

class _StepNode extends StatelessWidget {
  final Color color;
  final IconData? icon;

  const _StepNode({
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child:
          icon != null ? Icon(icon, color: Colors.white, size: 20) : null,
    );
  }
}
