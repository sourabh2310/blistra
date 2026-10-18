class AiDraft {
  AiDraft(this.json);
  final Map<String, dynamic> json;
  String get id => json['id'] as String;
  int get revision => (json['revision'] as num).toInt();
  String get label => json['label'] as String;
  String get module => json['module'] as String;
  String get effect => json['effect'] as String;
  String get state => json['state'] as String;
  String get timezone => json['timezone'] as String;
  Map<String, dynamic> get data =>
      Map<String, dynamic>.from(json['data'] as Map);
  Map<String, dynamic> get errors =>
      Map<String, dynamic>.from(json['errors'] as Map? ?? {});
  List<Map<String, dynamic>> get fields => (json['fields'] as List)
      .map((f) => Map<String, dynamic>.from(f as Map))
      .toList();
  bool get expired =>
      DateTime.tryParse(json['expiresAt'] as String? ?? '')
          ?.isBefore(DateTime.now()) ??
      true;
  bool get pending => state == 'PENDING' && !expired;
  bool get ready => pending && errors.isEmpty;
}

class AiEntryReply {
  AiEntryReply(Map<String, dynamic> json)
    : reply = json['reply'] as String,
      draft = json['draft'] is Map
          ? AiDraft(Map<String, dynamic>.from(json['draft'] as Map))
          : null,
      uploadDocument = json['uploadDocument'] == true;
  final String reply;
  final AiDraft? draft;
  final bool uploadDocument;
}
