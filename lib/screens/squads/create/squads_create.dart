import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/main.dart';
import 'package:squad_tracker_flutter/providers/squad_service.dart';
import 'package:squad_tracker_flutter/providers/user_squad_session_service.dart';
import 'package:squad_tracker_flutter/l10n/gen/app_localizations.dart';

class SquadCreateScreen extends StatelessWidget {
  const SquadCreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.createSquadTitle),
        ),
        body: const SquadForm());
  }
}

class SquadForm extends StatefulWidget {
  const SquadForm({super.key});

  @override
  State<SquadForm> createState() => _SquadFormState();
}

class _SquadFormState extends State<SquadForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _squadNameController = TextEditingController();
  final squadService = SquadService();
  final userSquadSessionService = UserSquadSessionService();

  @override
  Widget build(BuildContext context) {
    return Form(
        key: _formKey,
        child: Container(
          margin: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextFormField(
                controller: _squadNameController,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: AppLocalizations.of(context)!.squadNameHint,
                ),
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return AppLocalizations.of(context)!.userNameValidation;
                  }
                  return null;
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: ElevatedButton(
                  onPressed: () async {
                    // Validate will return true if the form is valid, or false if
                    // the form is invalid.
                    if (_formKey.currentState!.validate()) {
                      final squadName = _squadNameController.text;
                      final newSquad =
                          await squadService.createSquad(squadName);
                      await userSquadSessionService.createUserSquadSession(
                          userId: supabase.auth.currentSession!.user.id,
                          squadId: newSquad!.id.toString(),
                          isHost: true);
                      Navigator.pop(context);
                    }
                  },
                  child: Text(AppLocalizations.of(context)!.submit),
                ),
              ),
            ],
          ),
        ));
  }
}
