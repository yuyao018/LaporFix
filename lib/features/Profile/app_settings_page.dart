import 'package:flutter/material.dart';

import '../../services/app_settings_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/function_appbar.dart';

class AppSettingsPage extends StatefulWidget {
  final VoidCallback? onBack;

  const AppSettingsPage({super.key, this.onBack});

  @override
  State<AppSettingsPage> createState() => _AppSettingsPageState();
}

class _AppSettingsPageState extends State<AppSettingsPage> {
  bool _isSaving = false;

  AppSettingsService get _settings => AppSettingsService.instance;

  Future<void> _updateSetting(String key, Object value) async {
    setState(() => _isSaving = true);
    try {
      await _settings.updateSetting(key, value);
    } catch (e) {
      if (mounted) _showSnackBar('Could not save setting: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _resetSettings() async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset app settings?'),
        content: const Text(
          'Your notification, privacy, and display preferences will return to their defaults.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (shouldReset != true) return;

    setState(() => _isSaving = true);
    try {
      await _settings.reset();
      if (mounted) _showSnackBar('Settings reset.');
    } catch (e) {
      if (mounted) _showSnackBar('Could not reset settings: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FunctionAppBar(title: 'App Settings', onBack: widget.onBack),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppTheme.functionBackground),
        child: AnimatedBuilder(
          animation: _settings,
          builder: (context, _) {
            return Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: _isSaving ? 3 : 0,
                  child: const LinearProgressIndicator(
                    minHeight: 3,
                    color: Colors.white,
                    backgroundColor: Colors.transparent,
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SettingsHeader(isSaving: _isSaving),
                        const SizedBox(height: 14),
                        _SettingsSection(
                          title: 'Notifications',
                          icon: Icons.notifications_active_rounded,
                          children: [
                            _SwitchSettingTile(
                              icon: Icons.priority_high_rounded,
                              title: 'Urgent alerts',
                              subtitle:
                                  'Receive announcement notifications for your area.',
                              value: _settings.urgentAlerts,
                              onChanged: (value) =>
                                  _updateSetting('urgentAlerts', value),
                            ),
                            _SwitchSettingTile(
                              icon: Icons.task_alt_rounded,
                              title: 'Issue status updates',
                              subtitle:
                                  'Receive notifications when your own reports move forward.',
                              value: _settings.statusUpdates,
                              onChanged: (value) =>
                                  _updateSetting('statusUpdates', value),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _SettingsSection(
                          title: 'Privacy',
                          icon: Icons.verified_user_rounded,
                          children: [
                            _SwitchSettingTile(
                              icon: Icons.groups_rounded,
                              title: 'Community profile',
                              subtitle:
                                  'Show your display name on public community activity.',
                              value: _settings.profileVisibleToCommunity,
                              onChanged: (value) => _updateSetting(
                                'profileVisibleToCommunity',
                                value,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _SettingsSection(
                          title: 'App experience',
                          icon: Icons.tune_rounded,
                          children: [
                            _SwitchSettingTile(
                              icon: Icons.speed_rounded,
                              title: 'Low data mode',
                              subtitle: _settings.isCellular
                                  ? 'Reduced media is active while using mobile data.'
                                  : 'Reduce media loading; also turns on automatically for mobile data.',
                              value: _settings.lowDataMode,
                              onChanged: (value) =>
                                  _updateSetting('lowDataMode', value),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: _resetSettings,
                            icon: const Icon(Icons.restart_alt_rounded),
                            label: const Text('Reset App Settings'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(
                                color: Colors.white,
                                width: 1.4,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  final bool isSaving;

  const _SettingsHeader({required this.isSaving});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              gradient: AppTheme.primaryGradientDiagonal,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.settings_suggest_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Personal app setup',
                  style: tt.titleLarge?.copyWith(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isSaving ? 'Saving changes...' : 'Synced to your account',
                  style: tt.bodySmall?.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primaryBlue, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: tt.titleLarge?.copyWith(
                    color: AppTheme.primaryBlue,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) const Divider(height: 1, indent: 48),
          ],
        ],
      ),
    );
  }
}

class _SwitchSettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchSettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icon, color: AppTheme.textSecondary, size: 24),
      title: Text(
        title,
        style: tt.bodyLarge?.copyWith(
          color: AppTheme.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(subtitle, style: tt.bodySmall?.copyWith(fontSize: 13)),
      value: value,
      activeThumbColor: AppTheme.primaryBlue,
      activeTrackColor: AppTheme.primaryBlue.withValues(alpha: 0.28),
      onChanged: onChanged,
    );
  }
}


