import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge/src/features/knowledge/data/knowledge_storage.dart';
import 'package:knowledge/src/features/knowledge/domain/knowledge_models.dart';

void main() {
  test('storage exports and imports board state', () {
    final KnowledgeStorage storage = const KnowledgeStorage();
    final KnowledgeBoardState board = KnowledgeBoardState(
      roots: <KnowledgeNode>[
        KnowledgeNode.create(
          title: 'Biology',
          body: '## Cell theory',
          children: <KnowledgeNode>[
            KnowledgeNode.create(
              title: 'Mitochondria',
              body: 'Powerhouse of the cell',
              isFlashcard: true,
            ),
          ],
        ),
      ],
      expandedNodeIds: <String>{'open-1'},
    );

    final String exported = storage.export(board);
    final KnowledgeBoardState imported = storage.import(exported);

    expect(imported.roots.single.title, 'Biology');
    expect(imported.roots.single.children.single.isFlashcard, isTrue);
    expect(
      imported.roots.single.children.single.body,
      'Powerhouse of the cell',
    );
    expect(imported.expandedNodeIds, contains('open-1'));
  });
}
