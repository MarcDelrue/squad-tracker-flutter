import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:squad_tracker_flutter/models/squad_model.dart';
import 'package:squad_tracker_flutter/l10n/app_localizations.dart';

class UserAddButton extends StatelessWidget {
  final Squad squad;

  const UserAddButton({super.key, required this.squad});

  void _showSquadUuidModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allow the modal to be scrollable
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            top: 16.0,
            bottom: 16.0 +
                MediaQuery.of(context).padding.bottom, // Add safe area padding
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppLocalizations.of(context)!.inviteToSquadTitle,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 10),
                Text(
                  AppLocalizations.of(context)!.inviteToSquadBody,
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
                            SnackBar(
                              content: Text(AppLocalizations.of(context)!
                                  .squadCodeCopied),
                            ),
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
                  child: Text(AppLocalizations.of(context)!.close),
                ),
                // Add extra bottom padding for better spacing
                const SizedBox(height: 32),
              ],
            ),
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
        title: Text(
          AppLocalizations.of(context)!.addNewMember,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        onTap: () => _showSquadUuidModal(context),
      ),
    );
  }
}
