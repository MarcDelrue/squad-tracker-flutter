import 'package:flutter/material.dart';
import 'package:squad_tracker_flutter/providers/squad_service.dart';
import 'package:squad_tracker_flutter/providers/user_service.dart';
import 'package:squad_tracker_flutter/providers/user_squad_session_service.dart';
import 'package:squad_tracker_flutter/widgets/scanner.dart';

class SquadJoinForm extends StatefulWidget {
  const SquadJoinForm({super.key});

  @override
  State<SquadJoinForm> createState() => _SquadJoinFormState();
}

class _SquadJoinFormState extends State<SquadJoinForm> {
  final squadService = SquadService();
  final userSquadSessionService = UserSquadSessionService();
  final userService = UserService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _squadCodeController = TextEditingController();

  String? _squadError; // Store async validation error

  Future<String?> _validateSquadExists(String squadCode) async {
    // Asynchronously check if squad exists
    final squadId = await squadService.squadIdByUuid(squadCode);
    return squadId;
  }

  Future<void> _onSubmit() async {
    // Reset async error
    setState(() {
      _squadError = null;
    });

    if (_formKey.currentState!.validate()) {
      final squadCode = _squadCodeController.text;
      final foundSquadId = await _validateSquadExists(squadCode);

      if (foundSquadId == null) {
        // Update error if squad does not exist
        setState(() {
          _squadError = 'Squad not found';
        });
      } else {
        await userSquadSessionService.joinSquad(
          userService.currentUser!.id,
          foundSquadId,
        );
        Navigator.pop(context);
      }
    }
  }

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
              controller: _squadCodeController,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: 'Squad code',
                suffixIcon: IconButton(
                  onPressed: () async {
                    // final result = await Navigator.push(
                    //   context,
                    //   MaterialPageRoute(
                    //       builder: (context) => const BarcodeScannerSimple()),
                    // );

                    // if (result != null) {
                    //   // Handle the result (the scanned barcode value)
                    //   debugPrint('Scanned barcode: $result');
                    //   _squadCodeController.text = result;
                    //   _onSubmit();
                    // }
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                ),
                errorText: _squadError, // Display async error here
              ),
              validator: (String? value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter some text';
                }
                if (value.length != 6) {
                  return 'Code is 6 characters long';
                }
                return null;
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: ElevatedButton(
                onPressed: _onSubmit,
                child: const Text('Join'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
