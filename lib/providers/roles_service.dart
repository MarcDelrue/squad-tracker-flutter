import 'package:supabase_flutter/supabase_flutter.dart';

class RolesService {
  static final RolesService _singleton = RolesService._internal();
  factory RolesService() {
    return _singleton;
  }
  RolesService._internal();

  late List<String> roles;

  final SupabaseClient supabase = Supabase.instance.client;

  Future<void> getAndStoreRoles() async {
    final data = await supabase.from('roles').select('name');
    roles = (data as List).map((item) => item['name'] as String).toList();
  }
}
