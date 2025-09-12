import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/main.dart';
import 'package:squad_tracker_flutter/providers/roles_service.dart';
import 'package:squad_tracker_flutter/providers/user_service.dart';
import 'package:squad_tracker_flutter/screens/login/login_form.dart';
import 'package:squad_tracker_flutter/utils/colors_option.dart';
import 'package:squad_tracker_flutter/widgets/color_picker.dart';
import 'package:squad_tracker_flutter/widgets/snack_bar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:squad_tracker_flutter/models/users_model.dart' as users_model;
import 'package:squad_tracker_flutter/l10n/gen/app_localizations.dart';
import 'package:squad_tracker_flutter/providers/locale_provider.dart';
import 'package:provider/provider.dart';

class UserScreen extends StatefulWidget {
  const UserScreen({super.key});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final rolesService = RolesService();
  final userService = UserService();

  String? _userMainRoleController;
  List<String> _rolesController = [];
  ColorOption _selectedColorOption = colorOptions.first;

  // String? _avatarUrl;
  var _loading = true;

  /// Called once a user id is received within `onAuthenticated()`
  Future<void> _getProfile() async {
    setState(() {
      _loading = true;
    });

    try {
      final userId = supabase.auth.currentSession!.user.id;
      final data =
          await supabase.from('users').select().eq('id', userId).single();
      _usernameController.text = (data['username'] ?? '') as String;
      _userMainRoleController = (data['main_role']);
      if (data['main_color'] != null && data['main_color'] is String) {
        _selectedColorOption = colorOptions.firstWhere(
          (option) => option.color == hexToColor(data['main_color']),
          orElse: () =>
              colorOptions.first, // Fallback to first color if not found
        );
      }
      // _avatarUrl = (data['avatar_url'] ?? '') as String;
    } on PostgrestException catch (error) {
      if (mounted) context.showSnackBar(error.message, isError: true);
    } catch (error) {
      if (mounted) {
        context.showSnackBar(
            AppLocalizations.of(context)!.unexpectedRetrieveProfile,
            isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _getRoles() async {
    try {
      setState(() {
        _rolesController = rolesService.roles;
      });
    } catch (error) {
      if (mounted) {
        context.showSnackBar('Unexpected error occurred while retrieving roles',
            isError: true);
      }
    }
  }

  /// Called when user taps `Update` button
  Future<void> _updateProfile() async {
    setState(() {
      _loading = true;
    });

    // Only validate form if we're updating from the form (not from color picker)
    if (_formKey.currentState != null && !_formKey.currentState!.validate()) {
      setState(() {
        _loading = false;
      });
      return;
    }

    final user = supabase.auth.currentUser;
    final updates = users_model.User(
      id: user!.id,
      username: _usernameController.text.trim(),
      main_role: _userMainRoleController,
      main_color: colorToHex(_selectedColorOption.color),
    );

    try {
      // Use only the userService to avoid double updates
      await userService.updateUser(updates);
      setState(() {
        _loading = false;
      });
      if (mounted) {
        context.showSnackBar(AppLocalizations.of(context)!.profileUpdated);
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        context.showSnackBar(error.message, isError: true);
      }
      setState(() {
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        context.showSnackBar(
          AppLocalizations.of(context)!.unexpectedUpdateProfile,
          isError: true,
        );
      }
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _signOut() async {
    final l10n = AppLocalizations.of(context)!;
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmSignOutTitle),
        content: Text(l10n.confirmSignOutBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.signOut),
          ),
        ],
      ),
    );

    if (shouldSignOut == true) {
      try {
        await supabase.auth.signOut();
      } on AuthException catch (error) {
        if (mounted) context.showSnackBar(error.message, isError: true);
      } catch (error) {
        if (mounted) {
          context.showSnackBar(l10n.unexpectedSignOut, isError: true);
        }
      } finally {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginForm()),
          );
        }
      }
    }
  }

  void _showColorPickerModal() {
    showDialog(
      context: context,
      builder: (context) => ColorPickerModal(
        initialColor: _selectedColorOption.color,
        onColorSelected: (selectedColor) {
          setState(() {
            _selectedColorOption = colorOptions.firstWhere(
              (option) => option.color == selectedColor,
              orElse: () =>
                  colorOptions.first, // Fallback to first color if not found
            );
          });
          _updateProfile();
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _getProfile();
    _getRoles();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
        appBar: AppBar(
          title: Text(l10n.userScreenTitle),
          actions: [
            PopupMenuButton<String>(
              tooltip: l10n.language,
              onSelected: (value) {
                final provider = context.read<LocaleProvider>();
                if (value == 'en') {
                  provider.setLocale(const Locale('en'));
                } else if (value == 'fr') {
                  provider.setLocale(const Locale('fr'));
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'en',
                  child: Text(l10n.english),
                ),
                PopupMenuItem<String>(
                  value: 'fr',
                  child: Text(l10n.french),
                ),
              ],
              icon: const Icon(Icons.language),
            )
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(labelText: l10n.userNameLabel),
                validator: (value) =>
                    value!.isEmpty ? l10n.userNameValidation : null,
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: '',
                  border: OutlineInputBorder(),
                ),
                hint: Text(l10n.selectRoleLabel),
                initialValue: _userMainRoleController,
                items: _rolesController.map((role) {
                  return DropdownMenuItem<String>(
                    value: role,
                    child: Text(role),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _userMainRoleController = newValue;
                  });
                },
                validator: (value) =>
                    value == null ? l10n.selectRoleValidation : null,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Text(l10n.yourColor),
                  const SizedBox(width: 8),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _selectedColorOption.color,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _selectedColorOption.name,
                    style: TextStyle(color: _selectedColorOption.color),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.color_lens),
                    onPressed: _showColorPickerModal,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: _loading ? null : _updateProfile,
                child: Text(_loading ? l10n.saving : l10n.update),
              ),
              const SizedBox(height: 18),
              TextButton(onPressed: _signOut, child: Text(l10n.signOut)),
            ],
          ),
        ));
  }
}
