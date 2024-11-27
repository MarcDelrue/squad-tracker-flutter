import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:squad_tracker_flutter/models/squad_model.dart';

class UserAddButton extends StatelessWidget {
  final Squad squad;

  const UserAddButton({super.key, required this.squad});

  void _showSquadUuidModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Invite to Squad',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 10),
              Text(
                'Share this code with users to join the squad:',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 10),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min, // Center the Row
                  children: [
                    SelectableText(
                      squad.uuid,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: squad.uuid));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Squad code copied to clipboard')),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              QrImageView(
                data: squad.uuid,
                backgroundColor: Colors.white,
                version: QrVersions.auto,
                size: 200.0,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: const Icon(
          Icons.person_add,
          color: Colors.green,
        ),
        title: const Text(
          'Add New Member',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        onTap: () => _showSquadUuidModal(context),
      ),
    );
  }
}
