import 'package:flutter/material.dart';

/// Readable before registration and available again from Help.
class PolicyScreen extends StatelessWidget {
  const PolicyScreen({super.key, required this.privacy});
  final bool privacy;
  static const version = '2026-10-17';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(privacy ? 'Privacy Policy' : 'Terms')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: SelectableText(
        privacy ? _privacy : _terms,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
      ),
    ),
  );

  static const _privacy = '''Privacy Policy — version $version

Blistra stores the account details and records you provide, including optional health, medicine, diet, habit, planning, financial and document data, to operate the features you choose.

Personal records are accessed through your signed-in account. Accepted friends can see the expenses you share and the names/usernames of participants. Accepted group members can read the group's ledger, including expenses they did not split. Invitees can see the group name, currency and owner identity before joining. Shared descriptions and notes are visible to the people with ledger access; avoid putting private health or identity information in them.

Data is processed on the configured backend, database and file-storage services. Verification codes use the configured email/SMS provider. This service is not end-to-end encrypted: authorized service operators may have technical access to stored data.

Native devices use secure credential storage where available. When it is unavailable, and on web, sessions are held in memory. Downloaded files may be handed to another app you select; that app can keep its own copy. Notification content can appear on your lock screen unless you enable content hiding.

You can correct or remove records and delete your account in Privacy & data. Shared expenses and settlement history remain for other participants under a deleted identity; their descriptions and notes can still contain information originally entered by participants. File erasure may be delayed while failed storage operations retry. Backup retention depends on the service deployment.

Use the support contact in Help & support for data questions. Do not upload important originals until the service operator has confirmed durable storage and backups. Keep your own copies.
''';

  static const _terms = '''Terms — version $version

Blistra is a personal recordkeeping and organization tool. Provide information you are entitled to use and protect your account credentials. Do not use the service to abuse others, upload malicious files, or access another person's private records.

Health, diet and medicine features organize your entries. They do not diagnose conditions, prescribe treatment or replace professional care. Reminders depend on this device, notification permissions, battery settings and regularly refreshing the app. They are not guaranteed emergency or medication-delivery systems.

Financial entries and settlements are user-recorded information, not payment processing or proof that money changed hands. Shared expense participants may see the records and retained history described in the Privacy Policy. Resolve payment disagreements directly with the participants.

The service is under development. Features and availability may change. Keep independent copies of important information. You may stop using the service and request account deletion from Privacy & data. Contact the support address in Help & support about problems or data requests.

Read the Privacy Policy before creating an account. These terms do not remove rights that apply under the law where you live.
''';
}
