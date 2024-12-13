import 'package:flutter/foundation.dart';
import 'package:squad_tracker_flutter/models/users_model.dart' as users_model;
import 'package:supabase_flutter/supabase_flutter.dart';

class UserService extends ChangeNotifier {
  // Singleton setup for UserService
  static final UserService _singleton = UserService._internal();
  factory UserService() => _singleton;
  UserService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  // Nullable current user, initialized only when needed
  users_model.User? _currentUser;
  users_model.User? get currentUser => _currentUser;

  set currentUser(users_model.User? value) {
    _currentUser = value;
    notifyListeners();
  }

  /// Fetches the current user's information from Supabase and sets [_currentUser].
  Future<void> setUserInfo() async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('id', _supabase.auth.currentUser!.id)
          .single();

      currentUser = users_model.User(
        id: response['id'] as String,
        username: response['username'] as String?,
        full_name: response['full_name'] as String?,
        avatar_url: response['avatar_url'] as String?,
        main_role: response['main_role'] as String?,
        main_color: response['main_color'] as String?,
      );
    } catch (e) {
      debugPrint("Failed to set user info: $e");
    }
  }

  /// Updates the user's data in Supabase and refreshes [_currentUser].
  Future<void> updateUser(users_model.User updatedUserData) async {
    try {
      await _supabase
          .from('users')
          .upsert(updatedUserData.toJson())
          .select()
          .single();

      currentUser = updatedUserData;
    } catch (e) {
      debugPrint("Failed to update user info: $e");
    }
  }

  hasBasicInfo() {
    return _currentUser?.username != null &&
        _currentUser?.main_role != null &&
        _currentUser?.main_color != null;
  }
}
