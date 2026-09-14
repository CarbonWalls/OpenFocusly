class Prefs {
  Prefs();

  String theme = 'system';
  String lang = 'it';
  bool vibration = true;
  bool sound = false;
  double? goalV, goalM;
  String notesFolder = '';
  String notesFolderUri = '';
  String notificationSound = '';

  Map<String, dynamic> toJson() => {
        'theme': theme,
        'lang': lang,
        'vib': vibration,
        'sound': sound,
        'ggV': goalV,
        'ggM': goalM,
        'notesFolder': notesFolder,
        'notesFolderUri': notesFolderUri,
        'notifSound': notificationSound,
      };

  factory Prefs.fromJson(Map<String, dynamic> j) {
    final p = Prefs();
    p.theme = j['theme'] as String? ?? 'system';
    p.lang = j['lang'] as String? ?? 'it';
    p.vibration = j['vib'] as bool? ?? true;
    p.sound = j['sound'] as bool? ?? false;
    p.goalV = (j['ggV'] as num?)?.toDouble();
    p.goalM = (j['ggM'] as num?)?.toDouble();
    p.notesFolder = j['notesFolder'] as String? ?? '';
    p.notesFolderUri = j['notesFolderUri'] as String? ?? '';
    p.notificationSound = j['notifSound'] as String? ?? '';
    return p;
  }
}
