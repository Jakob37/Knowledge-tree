import 'dart:math';

class KnowledgeNode {
  KnowledgeNode({
    required this.id,
    required this.title,
    required this.body,
    required this.children,
    required this.isFlashcard,
    this.reviewStep = 0,
    this.reviewCount = 0,
    this.nextReviewAt,
    this.lastReviewedAt,
  });

  factory KnowledgeNode.create({
    required String title,
    String body = '',
    bool isFlashcard = false,
    List<KnowledgeNode> children = const <KnowledgeNode>[],
  }) {
    return KnowledgeNode(
      id: _createNodeId(),
      title: title,
      body: body,
      children: List<KnowledgeNode>.from(children),
      isFlashcard: isFlashcard,
      nextReviewAt: isFlashcard ? DateTime.now().toUtc() : null,
    );
  }

  factory KnowledgeNode.fromJson(Map<String, dynamic> json) {
    final List<dynamic> childJson =
        json['children'] as List<dynamic>? ?? <dynamic>[];
    return KnowledgeNode(
      id: (json['id'] as String?)?.trim().isNotEmpty == true
          ? json['id'] as String
          : _createNodeId(),
      title: (json['title'] as String? ?? '').trim(),
      body: (json['body'] as String? ?? '').trim(),
      children: childJson
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (Map<dynamic, dynamic> child) =>
                KnowledgeNode.fromJson(Map<String, dynamic>.from(child)),
          )
          .toList(growable: false),
      isFlashcard: json['isFlashcard'] as bool? ?? false,
      reviewStep: json['reviewStep'] as int? ?? 0,
      reviewCount: json['reviewCount'] as int? ?? 0,
      nextReviewAt: _readDateTime(json['nextReviewAt']),
      lastReviewedAt: _readDateTime(json['lastReviewedAt']),
    );
  }

  final String id;
  final String title;
  final String body;
  final List<KnowledgeNode> children;
  final bool isFlashcard;
  final int reviewStep;
  final int reviewCount;
  final DateTime? nextReviewAt;
  final DateTime? lastReviewedAt;

  KnowledgeNode copyWith({
    String? id,
    String? title,
    String? body,
    List<KnowledgeNode>? children,
    bool? isFlashcard,
    int? reviewStep,
    int? reviewCount,
    DateTime? nextReviewAt,
    bool clearNextReviewAt = false,
    DateTime? lastReviewedAt,
    bool clearLastReviewedAt = false,
  }) {
    return KnowledgeNode(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      children: children ?? this.children,
      isFlashcard: isFlashcard ?? this.isFlashcard,
      reviewStep: reviewStep ?? this.reviewStep,
      reviewCount: reviewCount ?? this.reviewCount,
      nextReviewAt: clearNextReviewAt
          ? null
          : nextReviewAt ?? this.nextReviewAt,
      lastReviewedAt: clearLastReviewedAt
          ? null
          : lastReviewedAt ?? this.lastReviewedAt,
    );
  }

  bool get isDue {
    if (!isFlashcard) {
      return false;
    }
    final DateTime? dueAt = nextReviewAt;
    if (dueAt == null) {
      return true;
    }
    return !dueAt.isAfter(DateTime.now().toUtc());
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'body': body,
      'children': children.map((KnowledgeNode node) => node.toJson()).toList(),
      'isFlashcard': isFlashcard,
      'reviewStep': reviewStep,
      'reviewCount': reviewCount,
      'nextReviewAt': nextReviewAt?.toIso8601String(),
      'lastReviewedAt': lastReviewedAt?.toIso8601String(),
    };
  }

  static DateTime? _readDateTime(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(value)?.toUtc();
  }
}

class KnowledgeBoardState {
  KnowledgeBoardState({required this.roots, required this.expandedNodeIds});

  factory KnowledgeBoardState.initial() {
    final KnowledgeNode trees = KnowledgeNode.create(
      title: 'Knowledge tree',
      body: '# Knowledge tree\n\nCapture branches and leaves in one place.',
      children: <KnowledgeNode>[
        KnowledgeNode.create(
          title: 'Inbox leaves',
          body:
              '- Quick facts\n- Questions worth answering\n- Raw notes to sort later',
        ),
        KnowledgeNode.create(
          title: 'Active recall',
          body:
              'Flashcard nodes reuse the same tree. Title = prompt, body = answer.',
          isFlashcard: true,
        ),
      ],
    );
    final KnowledgeNode organization = KnowledgeNode.create(
      title: 'Organization ideas',
      body:
          '## Patterns\n\n- Group by subject\n- Split broad topics into sub-branches\n- Drag notes deeper when they become more specific',
      children: <KnowledgeNode>[
        KnowledgeNode.create(
          title: 'Expand, then reorganize',
          body:
              'Open a subtree before dropping a node into it so deeper placement stays visible.',
        ),
      ],
    );
    return KnowledgeBoardState(
      roots: <KnowledgeNode>[trees, organization],
      expandedNodeIds: <String>{trees.id, organization.id},
    );
  }

  factory KnowledgeBoardState.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rootJson =
        json['roots'] as List<dynamic>? ?? <dynamic>[];
    final List<dynamic> expandedJson =
        json['expandedNodeIds'] as List<dynamic>? ?? <dynamic>[];

    return KnowledgeBoardState(
      roots: rootJson
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (Map<dynamic, dynamic> item) =>
                KnowledgeNode.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
      expandedNodeIds: expandedJson.whereType<String>().toSet(),
    );
  }

  final List<KnowledgeNode> roots;
  final Set<String> expandedNodeIds;

  KnowledgeBoardState copyWith({
    List<KnowledgeNode>? roots,
    Set<String>? expandedNodeIds,
  }) {
    return KnowledgeBoardState(
      roots: roots ?? this.roots,
      expandedNodeIds: expandedNodeIds ?? this.expandedNodeIds,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'roots': roots.map((KnowledgeNode node) => node.toJson()).toList(),
      'expandedNodeIds': expandedNodeIds.toList()..sort(),
    };
  }
}

enum FlashcardReviewOutcome { forgot, hard, good, easy }

class FlashcardReviewResult {
  const FlashcardReviewResult({
    required this.reviewStep,
    required this.reviewCount,
    required this.nextReviewAt,
    required this.lastReviewedAt,
  });

  final int reviewStep;
  final int reviewCount;
  final DateTime nextReviewAt;
  final DateTime lastReviewedAt;
}

FlashcardReviewResult applyFlashcardOutcome(
  KnowledgeNode node,
  FlashcardReviewOutcome outcome,
) {
  final DateTime now = DateTime.now().toUtc();
  late final int nextStep;
  late final Duration interval;

  switch (outcome) {
    case FlashcardReviewOutcome.forgot:
      nextStep = 0;
      interval = const Duration(hours: 8);
      break;
    case FlashcardReviewOutcome.hard:
      nextStep = max(0, node.reviewStep);
      interval = Duration(days: _intervalDaysForStep(max(0, node.reviewStep)));
      break;
    case FlashcardReviewOutcome.good:
      nextStep = node.reviewStep + 1;
      interval = Duration(days: _intervalDaysForStep(nextStep));
      break;
    case FlashcardReviewOutcome.easy:
      nextStep = node.reviewStep + 2;
      interval = Duration(days: _intervalDaysForStep(nextStep + 1));
      break;
  }

  return FlashcardReviewResult(
    reviewStep: nextStep,
    reviewCount: node.reviewCount + 1,
    nextReviewAt: now.add(interval),
    lastReviewedAt: now,
  );
}

int _intervalDaysForStep(int step) {
  const List<int> schedule = <int>[1, 2, 4, 7, 14, 30, 60];
  if (step < schedule.length) {
    return schedule[step];
  }
  return schedule.last + ((step - schedule.length + 1) * 30);
}

String _createNodeId() {
  final DateTime now = DateTime.now().toUtc();
  final int randomValue = Random().nextInt(1 << 32);
  return '${now.microsecondsSinceEpoch.toRadixString(16)}-'
      '${randomValue.toRadixString(16)}';
}

class VisibleKnowledgeNode {
  const VisibleKnowledgeNode({
    required this.node,
    required this.depth,
    required this.hasChildren,
  });

  final KnowledgeNode node;
  final int depth;
  final bool hasChildren;
}
