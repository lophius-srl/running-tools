/// Un élément d'un modèle de checklist.
class TemplateItem {
  const TemplateItem(this.label, {this.mandatory = false});

  final String label;

  /// Matériel obligatoire (trail).
  final bool mandatory;

  Map<String, Object?> toJson() => {'label': label, 'mandatory': mandatory};

  static TemplateItem fromJson(Map<String, Object?> json) => TemplateItem(
    json['label']! as String,
    mandatory: json['mandatory'] as bool? ?? false,
  );
}

/// Modèle réutilisable (route, trail, piste, sortie longue, perso).
class ChecklistTemplate {
  const ChecklistTemplate({
    required this.id,
    required this.name,
    required this.items,
    this.builtIn = false,
  });

  final String id;
  final String name;
  final List<TemplateItem> items;
  final bool builtIn;

  ChecklistTemplate copyWith({
    String? id,
    String? name,
    List<TemplateItem>? items,
  }) => ChecklistTemplate(
    id: id ?? this.id,
    name: name ?? this.name,
    items: items ?? this.items,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'items': [for (final i in items) i.toJson()],
  };

  static ChecklistTemplate? fromJson(Map<String, Object?> json) {
    try {
      return ChecklistTemplate(
        id: json['id']! as String,
        name: json['name']! as String,
        items: [
          for (final i in json['items']! as List)
            TemplateItem.fromJson(i as Map<String, Object?>),
        ],
      );
    } on Object {
      return null;
    }
  }
}

/// Un élément coché ou non d'une checklist de course.
class ChecklistItem {
  const ChecklistItem({
    required this.label,
    this.mandatory = false,
    this.checked = false,
  });

  final String label;
  final bool mandatory;
  final bool checked;

  ChecklistItem withChecked(bool value) =>
      ChecklistItem(label: label, mandatory: mandatory, checked: value);

  Map<String, Object?> toJson() => {
    'label': label,
    'mandatory': mandatory,
    'checked': checked,
  };

  static ChecklistItem fromJson(Map<String, Object?> json) => ChecklistItem(
    label: json['label']! as String,
    mandatory: json['mandatory'] as bool? ?? false,
    checked: json['checked'] as bool? ?? false,
  );
}

/// Heure de rappel, la veille de la course.
typedef ReminderTime = ({int hour, int minute});

/// Checklist d'une course donnée, générée depuis un modèle.
class RaceChecklist {
  const RaceChecklist({
    required this.id,
    required this.raceName,
    required this.raceDate,
    required this.items,
    this.reminder,
    this.courseId,
  });

  /// Nouvelle checklist à partir de [template] (tout décoché).
  factory RaceChecklist.fromTemplate(
    ChecklistTemplate template, {
    required String id,
    required String raceName,
    required DateTime raceDate,
    ReminderTime? reminder,
    String? courseId,
  }) => RaceChecklist(
    id: id,
    raceName: raceName,
    raceDate: raceDate,
    reminder: reminder,
    courseId: courseId,
    items: [
      for (final i in template.items)
        ChecklistItem(label: i.label, mandatory: i.mandatory),
    ],
  );

  final String id;
  final String raceName;
  final DateTime raceDate;
  final List<ChecklistItem> items;
  final ReminderTime? reminder;

  /// Course importée dans le simulateur de parcours, le cas échéant.
  final String? courseId;

  int get checkedCount => items.where((i) => i.checked).length;

  double get progress => items.isEmpty ? 0 : checkedCount / items.length;

  bool get isComplete => items.isNotEmpty && checkedCount == items.length;

  /// Matériel obligatoire encore non coché.
  List<ChecklistItem> get missingMandatory => [
    for (final i in items)
      if (i.mandatory && !i.checked) i,
  ];

  RaceChecklist _with({
    List<ChecklistItem>? items,
    ReminderTime? reminder,
    bool clearReminder = false,
  }) => RaceChecklist(
    id: id,
    raceName: raceName,
    raceDate: raceDate,
    items: items ?? this.items,
    reminder: clearReminder ? null : (reminder ?? this.reminder),
    courseId: courseId,
  );

  RaceChecklist toggle(int index) => _with(
    items: [
      for (final (i, item) in items.indexed)
        i == index ? item.withChecked(!item.checked) : item,
    ],
  );

  RaceChecklist uncheckAll() =>
      _with(items: [for (final i in items) i.withChecked(false)]);

  /// Ajoute un élément ponctuel (vide ou en double : ignoré).
  RaceChecklist addItem(String label) {
    final l = label.trim();
    if (l.isEmpty || items.any((i) => i.label == l)) return this;
    return _with(
      items: [
        ...items,
        ChecklistItem(label: l),
      ],
    );
  }

  RaceChecklist removeItem(int index) =>
      _with(items: [...items]..removeAt(index));

  RaceChecklist withReminder(ReminderTime? value) =>
      value == null ? _with(clearReminder: true) : _with(reminder: value);

  /// Moment du rappel : la veille à l'heure choisie ; `null` sans rappel ou
  /// si ce moment est déjà passé à [now].
  DateTime? reminderAt(DateTime now) {
    final r = reminder;
    if (r == null) return null;
    final eve = DateTime(
      raceDate.year,
      raceDate.month,
      raceDate.day - 1,
      r.hour,
      r.minute,
    );
    return eve.isAfter(now) ? eve : null;
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'raceName': raceName,
    'raceDate': raceDate.toIso8601String(),
    'items': [for (final i in items) i.toJson()],
    if (reminder case final r?)
      'reminder': {'hour': r.hour, 'minute': r.minute},
    'courseId': ?courseId,
  };

  static RaceChecklist? fromJson(Map<String, Object?> json) {
    try {
      final r = json['reminder'] as Map<String, Object?>?;
      return RaceChecklist(
        id: json['id']! as String,
        raceName: json['raceName']! as String,
        raceDate: DateTime.parse(json['raceDate']! as String),
        items: [
          for (final i in json['items']! as List)
            ChecklistItem.fromJson(i as Map<String, Object?>),
        ],
        reminder: r == null
            ? null
            : (hour: r['hour']! as int, minute: r['minute']! as int),
        courseId: json['courseId'] as String?,
      );
    } on Object {
      return null;
    }
  }
}

/// Identifiant numérique stable d'une notification pour une checklist.
int reminderNotificationId(String checklistId) =>
    checklistId.codeUnits.fold(17, (h, c) => (h * 31 + c) & 0x7fffffff);

/// Modèles fournis.
const builtInTemplates = [
  ChecklistTemplate(
    id: 'tpl-route',
    name: 'Course sur route',
    builtIn: true,
    items: [
      TemplateItem('Dossard et épingles'),
      TemplateItem('Puce de chronométrage'),
      TemplateItem('Chaussures de course'),
      TemplateItem('Tenue adaptée à la météo'),
      TemplateItem('Montre chargée'),
      TemplateItem('Gels / ravitaillement'),
      TemplateItem('Crème anti-frottements'),
      TemplateItem('Eau'),
      TemplateItem('Sac de change'),
      TemplateItem('Papiers et carte bancaire'),
    ],
  ),
  ChecklistTemplate(
    id: 'tpl-trail',
    name: 'Trail',
    builtIn: true,
    items: [
      TemplateItem('Réserve d’eau (1 L minimum)', mandatory: true),
      TemplateItem('Réserve alimentaire', mandatory: true),
      TemplateItem('Couverture de survie', mandatory: true),
      TemplateItem('Sifflet', mandatory: true),
      TemplateItem('Téléphone chargé', mandatory: true),
      TemplateItem('Veste imperméable', mandatory: true),
      TemplateItem('Gobelet', mandatory: true),
      TemplateItem('Lampe frontale et piles', mandatory: true),
      TemplateItem('Dossard'),
      TemplateItem('Chaussures de trail'),
      TemplateItem('Bâtons'),
      TemplateItem('Crème anti-frottements'),
    ],
  ),
  ChecklistTemplate(
    id: 'tpl-piste',
    name: 'Test VMA sur piste',
    builtIn: true,
    items: [
      TemplateItem('Téléphone chargé avec Running Tools'),
      TemplateItem('Écouteurs ou enceinte'),
      TemplateItem('Plots ou repères'),
      TemplateItem('Décamètre'),
      TemplateItem('Chaussures légères'),
      TemplateItem('Eau'),
      TemplateItem('Tenue de rechange'),
    ],
  ),
  ChecklistTemplate(
    id: 'tpl-sortie-longue',
    name: 'Sortie longue',
    builtIn: true,
    items: [
      TemplateItem('Gels ou barres'),
      TemplateItem('Eau ou flasques'),
      TemplateItem('Montre chargée'),
      TemplateItem('Téléphone'),
      TemplateItem('Crème anti-frottements'),
      TemplateItem('Casquette et lunettes'),
      TemplateItem('Carte bancaire ou monnaie'),
      TemplateItem('Parcours prévu'),
    ],
  ),
];
