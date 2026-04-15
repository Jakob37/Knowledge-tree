import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app_version.dart';
import '../../knowledge/data/knowledge_backup_preferences.dart';
import '../../knowledge/data/knowledge_backup_service.dart';
import '../../knowledge/data/knowledge_storage.dart';
import '../../knowledge/domain/knowledge_models.dart';

class KnowledgePage extends StatefulWidget {
  const KnowledgePage({super.key});

  @override
  State<KnowledgePage> createState() => _KnowledgePageState();
}

class _KnowledgePageState extends State<KnowledgePage> {
  final KnowledgeStorage _storage = const KnowledgeStorage();
  final KnowledgeBackupService _backupService = const KnowledgeBackupService();
  final KnowledgeBackupPreferences _backupPreferences =
      const KnowledgeBackupPreferences();

  KnowledgeBoardState _board = KnowledgeBoardState.initial();
  bool _isLoading = true;
  bool _automaticBackupsEnabled = true;
  bool _autosavePaused = false;
  String? _selectedNodeId;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _loadBoard();
  }

  Future<void> _loadBoard() async {
    final KnowledgeLoadResult loadResult = await _storage.load();
    final bool automaticBackupsEnabled = await _backupPreferences
        .loadAutomaticBackupsEnabled();
    KnowledgeBoardState board = KnowledgeBoardState.initial();
    String? statusMessage;
    bool autosavePaused = false;

    if (loadResult.isSuccess) {
      board = loadResult.state!;
    } else if (loadResult.isFailure) {
      autosavePaused = true;
      statusMessage =
          'Saved data could not be read. Autosave is paused until you import or edit.';
    }

    setState(() {
      _board = board;
      _automaticBackupsEnabled = automaticBackupsEnabled;
      _autosavePaused = autosavePaused;
      _selectedNodeId = _deriveSelectedNodeId(board);
      _statusMessage = statusMessage;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final List<VisibleKnowledgeNode> visibleNodes = _visibleNodes();
    final int flashcardCount = _countFlashcards(_board.roots);
    final int dueFlashcardCount = _collectDueFlashcards(_board.roots).length;
    final KnowledgeNode? selectedNode = _selectedNode();
    final bool isWide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Knowledge'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Review flashcards',
            onPressed: dueFlashcardCount == 0 ? null : _startReview,
            icon: Badge.count(
              count: dueFlashcardCount,
              isLabelVisible: dueFlashcardCount > 0,
              child: const Icon(Icons.style_outlined),
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openNodeEditor(parentId: _selectedNodeId),
        icon: const Icon(Icons.add),
        label: Text(_selectedNodeId == null ? 'Add root' : 'Add child'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            children: <Widget>[
              if (_statusMessage != null) ...<Widget>[
                _StatusBanner(
                  message: _statusMessage!,
                  onDismiss: () => setState(() => _statusMessage = null),
                ),
                const SizedBox(height: 12),
              ],
              _SummaryStrip(
                rootCount: _board.roots.length,
                nodeCount: _countNodes(_board.roots),
                flashcardCount: flashcardCount,
                dueFlashcardCount: dueFlashcardCount,
                automaticBackupsEnabled: _automaticBackupsEnabled,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Expanded(
                            flex: 7,
                            child: _buildTreePane(visibleNodes),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 5,
                            child: _buildDetailPane(selectedNode),
                          ),
                        ],
                      )
                    : Column(
                        children: <Widget>[
                          Expanded(
                            flex: 6,
                            child: _buildTreePane(visibleNodes),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            flex: 5,
                            child: _buildDetailPane(selectedNode),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTreePane(List<VisibleKnowledgeNode> visibleNodes) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD9CDB7)),
      ),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Tree',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton.icon(
                  onPressed: _addRootNode,
                  icon: const Icon(Icons.account_tree_outlined),
                  label: const Text('Root node'),
                ),
              ],
            ),
          ),
          _RootDropZone(onAccept: _moveNodeToRoot),
          const SizedBox(height: 12),
          Expanded(
            child: visibleNodes.isEmpty
                ? const Center(child: Text('No knowledge nodes yet.'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: visibleNodes.length,
                    separatorBuilder: (BuildContext context, int index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (BuildContext context, int index) {
                      final VisibleKnowledgeNode visibleNode =
                          visibleNodes[index];
                      final KnowledgeNode node = visibleNode.node;
                      final bool isSelected = node.id == _selectedNodeId;
                      final bool isExpanded = _board.expandedNodeIds.contains(
                        node.id,
                      );

                      return _KnowledgeNodeCard(
                        node: node,
                        depth: visibleNode.depth,
                        isExpanded: isExpanded,
                        isSelected: isSelected,
                        hasChildren: visibleNode.hasChildren,
                        canMoveUp: _canMoveWithinSiblings(node.id, -1),
                        canMoveDown: _canMoveWithinSiblings(node.id, 1),
                        onTap: () => setState(() => _selectedNodeId = node.id),
                        onToggleExpanded: visibleNode.hasChildren
                            ? () => _toggleExpanded(node.id)
                            : null,
                        onAcceptDrop: (String draggedId) =>
                            _moveNodeUnderTarget(draggedId, node.id),
                        onAddChild: () => _openNodeEditor(parentId: node.id),
                        onEdit: () => _openNodeEditor(existingNodeId: node.id),
                        onDelete: () => _deleteNode(node.id),
                        onPromote: () => _promoteNode(node.id),
                        onMoveUp: () => _moveWithinSiblings(node.id, -1),
                        onMoveDown: () => _moveWithinSiblings(node.id, 1),
                        onToggleFlashcard: () => _toggleFlashcard(node.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailPane(KnowledgeNode? node) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFFF8F3EA), Color(0xFFE8F0EC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD9CDB7)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: node == null
            ? const Center(
                child: Text(
                  'Select a node to inspect its notes and flashcard state.',
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          node.title.isEmpty ? 'Untitled node' : node.title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Edit node',
                        onPressed: () =>
                            _openNodeEditor(existingNodeId: node.id),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _Pill(
                        label:
                            '${node.children.length} child'
                            '${node.children.length == 1 ? '' : 'ren'}',
                      ),
                      _Pill(
                        label: node.isFlashcard
                            ? 'Flashcard'
                            : 'Reference note',
                        foreground: node.isFlashcard
                            ? const Color(0xFF0F5D57)
                            : const Color(0xFF5F5645),
                        background: node.isFlashcard
                            ? const Color(0xFFD9F0EA)
                            : const Color(0xFFECE4D8),
                      ),
                      if (node.isFlashcard)
                        _Pill(
                          label: node.isDue
                              ? 'Due now'
                              : 'Due ${_formatDue(node.nextReviewAt)}',
                          foreground: node.isDue
                              ? const Color(0xFF7A2517)
                              : const Color(0xFF23414F),
                          background: node.isDue
                              ? const Color(0xFFFADFD8)
                              : const Color(0xFFDCECF7),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Markdown-like view',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      child: SelectableText(
                        node.body.isEmpty ? 'No note body yet.' : node.body,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.45,
                          color: const Color(0xFF21302D),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      FilledButton.icon(
                        onPressed: () => _openNodeEditor(parentId: node.id),
                        icon: const Icon(Icons.subdirectory_arrow_right),
                        label: const Text('Add child'),
                      ),
                      OutlinedButton.icon(
                        onPressed: node.isFlashcard ? _startReview : null,
                        icon: const Icon(Icons.auto_stories_outlined),
                        label: const Text('Review due cards'),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _openSettings() async {
    final String? action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SwitchListTile(
                value: _automaticBackupsEnabled,
                title: const Text('Automatic JSON backups'),
                subtitle: const Text('Store rolling local snapshots.'),
                onChanged: (bool value) {
                  Navigator.of(context).pop();
                  _setAutomaticBackupsEnabled(value);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_all_outlined),
                title: const Text('Copy export JSON'),
                onTap: () => Navigator.of(context).pop('copy-export'),
              ),
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Import from pasted JSON'),
                onTap: () => Navigator.of(context).pop('import-json'),
              ),
              ListTile(
                leading: const Icon(Icons.restore_outlined),
                title: const Text('Restore automatic backup'),
                onTap: () => Navigator.of(context).pop('restore-backup'),
              ),
              ListTile(
                leading: const Icon(Icons.open_in_new_outlined),
                title: Text('Version $kKnowledgeVersionLabel'),
                subtitle: const Text('Open changelog on GitHub'),
                onTap: () => Navigator.of(context).pop('open-changelog'),
              ),
              if (Theme.of(context).platform == TargetPlatform.android ||
                  Theme.of(context).platform == TargetPlatform.iOS)
                const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    switch (action) {
      case 'copy-export':
        await _copyExportJson();
        break;
      case 'import-json':
        await _importFromPastedJson();
        break;
      case 'restore-backup':
        await _restoreAutomaticBackup();
        break;
      case 'open-changelog':
        await _openChangelog();
        break;
      case null:
        break;
    }
  }

  Future<void> _copyExportJson() async {
    await Clipboard.setData(ClipboardData(text: _storage.export(_board)));
    _showMessage('Board JSON copied to clipboard.');
  }

  Future<void> _importFromPastedJson() async {
    final TextEditingController controller = TextEditingController();
    final String? rawJson = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Import board JSON'),
          content: TextField(
            controller: controller,
            minLines: 8,
            maxLines: 16,
            decoration: const InputDecoration(
              hintText: 'Paste exported JSON here',
              border: OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Import'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (rawJson == null || rawJson.trim().isEmpty) {
      return;
    }

    try {
      final KnowledgeBoardState importedBoard = _storage.import(rawJson);
      await _replaceBoard(importedBoard, message: 'Imported board data.');
    } catch (error) {
      _showMessage('Import failed: $error');
    }
  }

  Future<void> _restoreAutomaticBackup() async {
    final List<KnowledgeBackupEntry> backups = await _backupService
        .listBackups();
    if (!mounted) {
      return;
    }
    if (backups.isEmpty) {
      _showMessage('No automatic backups are available yet.');
      return;
    }

    final KnowledgeBackupEntry? backup = await showDialog<KnowledgeBackupEntry>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Restore backup'),
          content: SizedBox(
            width: 420,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: backups.length,
              separatorBuilder: (BuildContext context, int index) =>
                  const Divider(height: 1),
              itemBuilder: (BuildContext context, int index) {
                final KnowledgeBackupEntry backup = backups[index];
                return ListTile(
                  title: Text(_formatTimestamp(backup.savedAt)),
                  subtitle: Text(backup.fileName),
                  onTap: () => Navigator.of(context).pop(backup),
                );
              },
            ),
          ),
        );
      },
    );

    if (backup == null) {
      return;
    }

    try {
      final String rawJson = await _backupService.readBackup(backup.id);
      final KnowledgeBoardState restoredBoard = _storage.import(rawJson);
      await _replaceBoard(
        restoredBoard,
        message:
            'Restored automatic backup from ${_formatTimestamp(backup.savedAt)}.',
      );
    } catch (error) {
      _showMessage('Automatic backup restore failed: $error');
    }
  }

  Future<void> _openChangelog() async {
    final Uri uri = Uri.parse(kKnowledgeChangelogUrl);
    final bool launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      _showMessage('Could not open the changelog link.');
    }
  }

  Future<void> _setAutomaticBackupsEnabled(bool enabled) async {
    await _backupPreferences.saveAutomaticBackupsEnabled(enabled);
    setState(() {
      _automaticBackupsEnabled = enabled;
    });
    await _persistBoard(forceBackup: enabled);
    _showMessage(
      enabled ? 'Automatic backups enabled.' : 'Automatic backups disabled.',
    );
  }

  Future<void> _replaceBoard(
    KnowledgeBoardState board, {
    required String message,
  }) async {
    setState(() {
      _board = board;
      _selectedNodeId = _deriveSelectedNodeId(board);
      _statusMessage = null;
      _autosavePaused = false;
    });
    await _persistBoard(forceBackup: true);
    _showMessage(message);
  }

  Future<void> _persistBoard({bool forceBackup = false}) async {
    if (_autosavePaused) {
      return;
    }

    await _storage.save(_board);
    if (_automaticBackupsEnabled) {
      await _backupService.saveAutomaticBackup(
        _storage.export(_board),
        force: forceBackup,
      );
    }
  }

  Future<void> _mutateBoard(
    KnowledgeBoardState Function(KnowledgeBoardState state) transform,
  ) async {
    final KnowledgeBoardState nextBoard = transform(_board);
    if (_selectedNodeId != null &&
        !_containsNode(nextBoard.roots, _selectedNodeId!)) {
      _selectedNodeId = _deriveSelectedNodeId(nextBoard);
    }
    setState(() {
      _board = nextBoard;
      _statusMessage = null;
      _autosavePaused = false;
    });
    await _persistBoard();
  }

  Future<void> _addRootNode() async {
    await _openNodeEditor(parentId: null);
  }

  Future<void> _openNodeEditor({
    String? parentId,
    String? existingNodeId,
  }) async {
    final KnowledgeNode? existingNode = existingNodeId == null
        ? null
        : _findNode(_board.roots, existingNodeId);
    final _NodeEditorResult? result =
        await showModalBottomSheet<_NodeEditorResult>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (BuildContext context) {
            return _NodeEditorSheet(existingNode: existingNode);
          },
        );

    if (result == null) {
      return;
    }

    if (existingNode != null) {
      await _mutateBoard((KnowledgeBoardState state) {
        return state.copyWith(
          roots: _mapNodeList(
            state.roots,
            existingNode.id,
            (KnowledgeNode node) => node.copyWith(
              title: result.title,
              body: result.body,
              isFlashcard: result.isFlashcard,
              clearNextReviewAt: !result.isFlashcard,
              clearLastReviewedAt: !result.isFlashcard,
              nextReviewAt: result.isFlashcard
                  ? node.nextReviewAt ?? DateTime.now().toUtc()
                  : null,
            ),
          ),
        );
      });
      _showMessage('Updated "${result.title}".');
      return;
    }

    final KnowledgeNode newNode = KnowledgeNode.create(
      title: result.title,
      body: result.body,
      isFlashcard: result.isFlashcard,
    );

    await _mutateBoard((KnowledgeBoardState state) {
      if (parentId == null) {
        return state.copyWith(roots: <KnowledgeNode>[...state.roots, newNode]);
      }
      return state.copyWith(
        roots: _mapNodeList(
          state.roots,
          parentId,
          (KnowledgeNode node) => node.copyWith(
            children: <KnowledgeNode>[...node.children, newNode],
          ),
        ),
        expandedNodeIds: <String>{...state.expandedNodeIds, parentId},
      );
    });
    setState(() {
      _selectedNodeId = newNode.id;
    });
    _showMessage('Added "${result.title}".');
  }

  Future<void> _deleteNode(String nodeId) async {
    final KnowledgeNode? node = _findNode(_board.roots, nodeId);
    if (node == null) {
      return;
    }

    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Delete node'),
              content: Text('Delete "${node.title}" and its subtree?'),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    await _mutateBoard((KnowledgeBoardState state) {
      final List<KnowledgeNode> updatedRoots = _removeNode(state.roots, nodeId);
      final Set<String> expandedNodeIds = Set<String>.from(
        state.expandedNodeIds,
      )..remove(nodeId);
      return state.copyWith(
        roots: updatedRoots,
        expandedNodeIds: expandedNodeIds,
      );
    });
    _showMessage('Deleted "${node.title}".');
  }

  void _toggleExpanded(String nodeId) {
    final Set<String> expandedNodeIds = Set<String>.from(
      _board.expandedNodeIds,
    );
    if (!expandedNodeIds.add(nodeId)) {
      expandedNodeIds.remove(nodeId);
    }
    setState(() {
      _board = _board.copyWith(expandedNodeIds: expandedNodeIds);
    });
    _persistBoard();
  }

  Future<void> _toggleFlashcard(String nodeId) async {
    final KnowledgeNode? node = _findNode(_board.roots, nodeId);
    if (node == null) {
      return;
    }

    await _mutateBoard((KnowledgeBoardState state) {
      return state.copyWith(
        roots: _mapNodeList(
          state.roots,
          nodeId,
          (KnowledgeNode target) => target.copyWith(
            isFlashcard: !target.isFlashcard,
            clearNextReviewAt: target.isFlashcard,
            clearLastReviewedAt: target.isFlashcard,
            nextReviewAt: target.isFlashcard ? null : DateTime.now().toUtc(),
          ),
        ),
      );
    });
  }

  Future<void> _promoteNode(String nodeId) async {
    final _DetachedNode? detached = _detachNode(_board.roots, nodeId);
    if (detached == null || detached.parentId == null) {
      return;
    }

    await _mutateBoard((KnowledgeBoardState state) {
      final _DetachedNode? current = _detachNode(state.roots, nodeId);
      if (current == null || current.parentId == null) {
        return state;
      }

      final _ParentLocation? parentLocation = _findParentLocation(
        current.roots,
        current.parentId!,
      );
      if (parentLocation == null) {
        return state.copyWith(
          roots: <KnowledgeNode>[...current.roots, current.node],
        );
      }

      final List<KnowledgeNode> nextSiblings = List<KnowledgeNode>.from(
        parentLocation.siblings,
      );
      nextSiblings.insert(parentLocation.index + 1, current.node);
      return state.copyWith(
        roots: parentLocation.parentId == null
            ? nextSiblings
            : _replaceChildren(
                current.roots,
                parentLocation.parentId!,
                nextSiblings,
              ),
      );
    });
  }

  Future<void> _moveNodeToRoot(String nodeId) async {
    final _DetachedNode? detached = _detachNode(_board.roots, nodeId);
    if (detached == null || detached.parentId == null) {
      return;
    }

    await _mutateBoard((KnowledgeBoardState state) {
      final _DetachedNode? current = _detachNode(state.roots, nodeId);
      if (current == null || current.parentId == null) {
        return state;
      }
      return state.copyWith(
        roots: <KnowledgeNode>[...current.roots, current.node],
      );
    });
  }

  Future<void> _moveNodeUnderTarget(String draggedId, String targetId) async {
    if (draggedId == targetId) {
      return;
    }
    final KnowledgeNode? dragged = _findNode(_board.roots, draggedId);
    if (dragged == null || _containsNode(dragged.children, targetId)) {
      return;
    }

    await _mutateBoard((KnowledgeBoardState state) {
      final _DetachedNode? detached = _detachNode(state.roots, draggedId);
      if (detached == null) {
        return state;
      }

      return state.copyWith(
        roots: _mapNodeList(
          detached.roots,
          targetId,
          (KnowledgeNode target) => target.copyWith(
            children: <KnowledgeNode>[...target.children, detached.node],
          ),
        ),
        expandedNodeIds: <String>{...state.expandedNodeIds, targetId},
      );
    });

    if (_selectedNodeId != draggedId) {
      setState(() {
        _selectedNodeId = draggedId;
      });
    }
  }

  bool _canMoveWithinSiblings(String nodeId, int delta) {
    final _ParentLocation? location = _findParentLocationForNode(
      _board.roots,
      nodeId,
    );
    if (location == null) {
      return false;
    }
    final int nextIndex = location.index + delta;
    return nextIndex >= 0 && nextIndex < location.siblings.length;
  }

  Future<void> _moveWithinSiblings(String nodeId, int delta) async {
    if (!_canMoveWithinSiblings(nodeId, delta)) {
      return;
    }

    await _mutateBoard((KnowledgeBoardState state) {
      final _ParentLocation? location = _findParentLocationForNode(
        state.roots,
        nodeId,
      );
      if (location == null) {
        return state;
      }

      final List<KnowledgeNode> reordered = List<KnowledgeNode>.from(
        location.siblings,
      );
      final KnowledgeNode node = reordered.removeAt(location.index);
      reordered.insert(location.index + delta, node);

      return state.copyWith(
        roots: location.parentId == null
            ? reordered
            : _replaceChildren(state.roots, location.parentId!, reordered),
      );
    });
  }

  Future<void> _startReview() async {
    final List<KnowledgeNode> dueNodes = _collectDueFlashcards(_board.roots);
    if (dueNodes.isEmpty) {
      _showMessage('No flashcards are due right now.');
      return;
    }

    int index = 0;
    while (mounted && index < dueNodes.length) {
      if (!mounted) {
        return;
      }
      final KnowledgeNode latestNode =
          _findNode(_board.roots, dueNodes[index].id) ?? dueNodes[index];
      final FlashcardReviewOutcome? outcome =
          await showDialog<FlashcardReviewOutcome>(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return _FlashcardReviewDialog(
                node: latestNode,
                position: index + 1,
                total: dueNodes.length,
              );
            },
          );

      if (outcome == null) {
        break;
      }

      final FlashcardReviewResult result = applyFlashcardOutcome(
        latestNode,
        outcome,
      );
      await _mutateBoard((KnowledgeBoardState state) {
        return state.copyWith(
          roots: _mapNodeList(
            state.roots,
            latestNode.id,
            (KnowledgeNode node) => node.copyWith(
              reviewStep: result.reviewStep,
              reviewCount: result.reviewCount,
              nextReviewAt: result.nextReviewAt,
              lastReviewedAt: result.lastReviewedAt,
            ),
          ),
        );
      });
      index += 1;
    }
  }

  List<VisibleKnowledgeNode> _visibleNodes() {
    final List<VisibleKnowledgeNode> visible = <VisibleKnowledgeNode>[];

    void walk(List<KnowledgeNode> nodes, int depth) {
      for (final KnowledgeNode node in nodes) {
        visible.add(
          VisibleKnowledgeNode(
            node: node,
            depth: depth,
            hasChildren: node.children.isNotEmpty,
          ),
        );
        if (_board.expandedNodeIds.contains(node.id)) {
          walk(node.children, depth + 1);
        }
      }
    }

    walk(_board.roots, 0);
    return visible;
  }

  KnowledgeNode? _selectedNode() {
    final String? selectedNodeId = _selectedNodeId;
    if (selectedNodeId == null) {
      return null;
    }
    return _findNode(_board.roots, selectedNodeId);
  }

  String? _deriveSelectedNodeId(KnowledgeBoardState board) {
    if (_selectedNodeId != null &&
        _containsNode(board.roots, _selectedNodeId!)) {
      return _selectedNodeId;
    }
    if (board.roots.isEmpty) {
      return null;
    }
    return board.roots.first.id;
  }

  int _countNodes(List<KnowledgeNode> nodes) {
    int count = 0;
    for (final KnowledgeNode node in nodes) {
      count += 1 + _countNodes(node.children);
    }
    return count;
  }

  int _countFlashcards(List<KnowledgeNode> nodes) {
    int count = 0;
    for (final KnowledgeNode node in nodes) {
      if (node.isFlashcard) {
        count += 1;
      }
      count += _countFlashcards(node.children);
    }
    return count;
  }

  List<KnowledgeNode> _collectDueFlashcards(List<KnowledgeNode> nodes) {
    final List<KnowledgeNode> dueNodes = <KnowledgeNode>[];
    for (final KnowledgeNode node in nodes) {
      if (node.isDue) {
        dueNodes.add(node);
      }
      dueNodes.addAll(_collectDueFlashcards(node.children));
    }
    return dueNodes;
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.rootCount,
    required this.nodeCount,
    required this.flashcardCount,
    required this.dueFlashcardCount,
    required this.automaticBackupsEnabled,
  });

  final int rootCount;
  final int nodeCount;
  final int flashcardCount;
  final int dueFlashcardCount;
  final bool automaticBackupsEnabled;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: <Widget>[
        _MetricCard(label: 'Roots', value: '$rootCount'),
        _MetricCard(label: 'Nodes', value: '$nodeCount'),
        _MetricCard(label: 'Flashcards', value: '$flashcardCount'),
        _MetricCard(label: 'Due now', value: '$dueFlashcardCount'),
        _MetricCard(
          label: 'Backups',
          value: automaticBackupsEnabled ? 'On' : 'Off',
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD9CDB7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: const Color(0xFF6C6558)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: const Color(0xFF18312D)),
          ),
        ],
      ),
    );
  }
}

class _KnowledgeNodeCard extends StatelessWidget {
  const _KnowledgeNodeCard({
    required this.node,
    required this.depth,
    required this.isExpanded,
    required this.isSelected,
    required this.hasChildren,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onTap,
    required this.onAcceptDrop,
    required this.onAddChild,
    required this.onEdit,
    required this.onDelete,
    required this.onPromote,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onToggleFlashcard,
    this.onToggleExpanded,
  });

  final KnowledgeNode node;
  final int depth;
  final bool isExpanded;
  final bool isSelected;
  final bool hasChildren;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onTap;
  final ValueChanged<String> onAcceptDrop;
  final VoidCallback onAddChild;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPromote;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onToggleFlashcard;
  final VoidCallback? onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final Color accent = node.isFlashcard
        ? const Color(0xFF1F6B66)
        : const Color(0xFF6D644E);

    return Padding(
      padding: EdgeInsets.only(left: depth * 18.0),
      child: LongPressDraggable<String>(
        data: node.id,
        feedback: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: _dragPreview(accent),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.35, child: _dragPreview(accent)),
        child: DragTarget<String>(
          onWillAcceptWithDetails: (DragTargetDetails<String> details) {
            return details.data != node.id;
          },
          onAcceptWithDetails: (DragTargetDetails<String> details) {
            onAcceptDrop(details.data);
          },
          builder:
              (
                BuildContext context,
                List<String?> candidateData,
                List<dynamic> rejectedData,
              ) {
                final bool isDropHover = candidateData.isNotEmpty;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFE6F0EC)
                        : Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDropHover
                          ? const Color(0xFF0E5E56)
                          : isSelected
                          ? const Color(0xFF0E5E56)
                          : const Color(0xFFD9CDB7),
                      width: isDropHover || isSelected ? 2 : 1,
                    ),
                  ),
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(18),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: onToggleExpanded,
                            icon: Icon(
                              hasChildren
                                  ? isExpanded
                                        ? Icons.expand_more
                                        : Icons.chevron_right
                                  : Icons.drag_indicator,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        node.title.isEmpty
                                            ? 'Untitled node'
                                            : node.title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              color: const Color(0xFF18312D),
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                    if (node.isFlashcard)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: node.isDue
                                              ? const Color(0xFFFADFD8)
                                              : const Color(0xFFD9F0EA),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          node.isDue ? 'Due' : 'Card',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelMedium
                                              ?.copyWith(
                                                color: node.isDue
                                                    ? const Color(0xFF7A2517)
                                                    : const Color(0xFF0F5D57),
                                              ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  node.body.isEmpty
                                      ? 'No note body yet.'
                                      : node.body.replaceAll('\n', ' '),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: const Color(0xFF5C594F),
                                      ),
                                ),
                                if (node.children.isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 8),
                                  Text(
                                    '${node.children.length} child '
                                    '${node.children.length == 1 ? 'node' : 'nodes'}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelMedium,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          PopupMenuButton<_NodeMenuAction>(
                            onSelected: (_NodeMenuAction action) {
                              switch (action) {
                                case _NodeMenuAction.addChild:
                                  onAddChild();
                                  break;
                                case _NodeMenuAction.edit:
                                  onEdit();
                                  break;
                                case _NodeMenuAction.toggleFlashcard:
                                  onToggleFlashcard();
                                  break;
                                case _NodeMenuAction.promote:
                                  onPromote();
                                  break;
                                case _NodeMenuAction.moveUp:
                                  onMoveUp();
                                  break;
                                case _NodeMenuAction.moveDown:
                                  onMoveDown();
                                  break;
                                case _NodeMenuAction.delete:
                                  onDelete();
                                  break;
                              }
                            },
                            itemBuilder: (BuildContext context) {
                              return <PopupMenuEntry<_NodeMenuAction>>[
                                const PopupMenuItem<_NodeMenuAction>(
                                  value: _NodeMenuAction.addChild,
                                  child: Text('Add child'),
                                ),
                                const PopupMenuItem<_NodeMenuAction>(
                                  value: _NodeMenuAction.edit,
                                  child: Text('Edit'),
                                ),
                                PopupMenuItem<_NodeMenuAction>(
                                  value: _NodeMenuAction.toggleFlashcard,
                                  child: Text(
                                    node.isFlashcard
                                        ? 'Remove flashcard'
                                        : 'Make flashcard',
                                  ),
                                ),
                                const PopupMenuItem<_NodeMenuAction>(
                                  value: _NodeMenuAction.promote,
                                  child: Text('Promote one level'),
                                ),
                                if (canMoveUp)
                                  const PopupMenuItem<_NodeMenuAction>(
                                    value: _NodeMenuAction.moveUp,
                                    child: Text('Move up'),
                                  ),
                                if (canMoveDown)
                                  const PopupMenuItem<_NodeMenuAction>(
                                    value: _NodeMenuAction.moveDown,
                                    child: Text('Move down'),
                                  ),
                                const PopupMenuDivider(),
                                const PopupMenuItem<_NodeMenuAction>(
                                  value: _NodeMenuAction.delete,
                                  child: Text('Delete'),
                                ),
                              ];
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
        ),
      ),
    );
  }

  Widget _dragPreview(Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent, width: 2),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            blurRadius: 18,
            color: Color(0x22000000),
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Text(
        node.title.isEmpty ? 'Untitled node' : node.title,
        style: const TextStyle(
          color: Color(0xFF18312D),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

enum _NodeMenuAction {
  addChild,
  edit,
  toggleFlashcard,
  promote,
  moveUp,
  moveDown,
  delete,
}

class _RootDropZone extends StatelessWidget {
  const _RootDropZone({required this.onAccept});

  final ValueChanged<String> onAccept;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DragTarget<String>(
        onAcceptWithDetails: (DragTargetDetails<String> details) {
          onAccept(details.data);
        },
        builder:
            (
              BuildContext context,
              List<String?> candidateData,
              List<dynamic> rejectedData,
            ) {
              final bool hovering = candidateData.isNotEmpty;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: hovering
                      ? const Color(0xFFD9F0EA)
                      : const Color(0xFFF1ECE2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: hovering
                        ? const Color(0xFF0E5E56)
                        : const Color(0xFFD9CDB7),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.vertical_align_top),
                    const SizedBox(width: 12),
                    Text(
                      'Drop here to move a node to the top level',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              );
            },
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9E6D8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2B38F)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.warning_amber_outlined),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
          IconButton(onPressed: onDismiss, icon: const Icon(Icons.close)),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    this.foreground = const Color(0xFF18312D),
    this.background = const Color(0xFFE7ECEA),
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: foreground),
      ),
    );
  }
}

class _NodeEditorResult {
  const _NodeEditorResult({
    required this.title,
    required this.body,
    required this.isFlashcard,
  });

  final String title;
  final String body;
  final bool isFlashcard;
}

class _NodeEditorSheet extends StatefulWidget {
  const _NodeEditorSheet({this.existingNode});

  final KnowledgeNode? existingNode;

  @override
  State<_NodeEditorSheet> createState() => _NodeEditorSheetState();
}

class _NodeEditorSheetState extends State<_NodeEditorSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late bool _isFlashcard;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existingNode?.title ?? '',
    );
    _bodyController = TextEditingController(
      text: widget.existingNode?.body ?? '',
    );
    _isFlashcard = widget.existingNode?.isFlashcard ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets viewInsets = MediaQuery.viewInsetsOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            widget.existingNode == null ? 'Create node' : 'Edit node',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bodyController,
            minLines: 6,
            maxLines: 12,
            decoration: const InputDecoration(
              labelText: 'Body',
              hintText: 'Use headings, bullets, or plain notes.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: _isFlashcard,
            contentPadding: EdgeInsets.zero,
            title: const Text('Use this node as a flashcard'),
            subtitle: const Text('Prompt = title, answer = body'),
            onChanged: (bool value) => setState(() => _isFlashcard = value),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _save, child: const Text('Save')),
            ],
          ),
        ],
      ),
    );
  }

  void _save() {
    final String title = _titleController.text.trim();
    if (title.isEmpty) {
      return;
    }
    Navigator.of(context).pop(
      _NodeEditorResult(
        title: title,
        body: _bodyController.text.trim(),
        isFlashcard: _isFlashcard,
      ),
    );
  }
}

class _FlashcardReviewDialog extends StatefulWidget {
  const _FlashcardReviewDialog({
    required this.node,
    required this.position,
    required this.total,
  });

  final KnowledgeNode node;
  final int position;
  final int total;

  @override
  State<_FlashcardReviewDialog> createState() => _FlashcardReviewDialogState();
}

class _FlashcardReviewDialogState extends State<_FlashcardReviewDialog> {
  bool _showAnswer = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Review ${widget.position}/${widget.total}'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.node.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (_showAnswer)
              SelectableText(
                widget.node.body.isEmpty ? 'No answer yet.' : widget.node.body,
              )
            else
              const Text(
                'Try to answer before revealing the back of the card.',
              ),
            const SizedBox(height: 16),
            if (!_showAnswer)
              FilledButton.tonal(
                onPressed: () => setState(() => _showAnswer = true),
                child: const Text('Show answer'),
              ),
          ],
        ),
      ),
      actions: _showAnswer
          ? <Widget>[
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(FlashcardReviewOutcome.forgot),
                child: const Text('Forgot'),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(FlashcardReviewOutcome.hard),
                child: const Text('Hard'),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(FlashcardReviewOutcome.good),
                child: const Text('Good'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(context).pop(FlashcardReviewOutcome.easy),
                child: const Text('Easy'),
              ),
            ]
          : <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
    );
  }
}

class _DetachedNode {
  const _DetachedNode({
    required this.node,
    required this.roots,
    required this.parentId,
  });

  final KnowledgeNode node;
  final List<KnowledgeNode> roots;
  final String? parentId;
}

class _ParentLocation {
  const _ParentLocation({
    required this.parentId,
    required this.siblings,
    required this.index,
  });

  final String? parentId;
  final List<KnowledgeNode> siblings;
  final int index;
}

KnowledgeNode? _findNode(List<KnowledgeNode> nodes, String nodeId) {
  for (final KnowledgeNode node in nodes) {
    if (node.id == nodeId) {
      return node;
    }
    final KnowledgeNode? childMatch = _findNode(node.children, nodeId);
    if (childMatch != null) {
      return childMatch;
    }
  }
  return null;
}

bool _containsNode(List<KnowledgeNode> nodes, String nodeId) {
  return _findNode(nodes, nodeId) != null;
}

List<KnowledgeNode> _mapNodeList(
  List<KnowledgeNode> nodes,
  String nodeId,
  KnowledgeNode Function(KnowledgeNode node) transform,
) {
  return nodes
      .map((KnowledgeNode node) {
        if (node.id == nodeId) {
          return transform(node);
        }
        if (node.children.isEmpty) {
          return node;
        }
        return node.copyWith(
          children: _mapNodeList(node.children, nodeId, transform),
        );
      })
      .toList(growable: false);
}

List<KnowledgeNode> _removeNode(List<KnowledgeNode> nodes, String nodeId) {
  final List<KnowledgeNode> remaining = <KnowledgeNode>[];
  for (final KnowledgeNode node in nodes) {
    if (node.id == nodeId) {
      continue;
    }
    remaining.add(node.copyWith(children: _removeNode(node.children, nodeId)));
  }
  return remaining;
}

_DetachedNode? _detachNode(
  List<KnowledgeNode> nodes,
  String nodeId, {
  String? parentId,
}) {
  final List<KnowledgeNode> working = <KnowledgeNode>[];
  for (final KnowledgeNode node in nodes) {
    if (node.id == nodeId) {
      return _DetachedNode(
        node: node,
        roots: <KnowledgeNode>[...working, ...nodes.skip(working.length + 1)],
        parentId: parentId,
      );
    }

    final _DetachedNode? detached = _detachNode(
      node.children,
      nodeId,
      parentId: node.id,
    );
    if (detached != null) {
      working.add(node.copyWith(children: detached.roots));
      working.addAll(nodes.skip(working.length));
      return _DetachedNode(
        node: detached.node,
        roots: working,
        parentId: detached.parentId,
      );
    }
    working.add(node);
  }
  return null;
}

_ParentLocation? _findParentLocation(
  List<KnowledgeNode> nodes,
  String parentId,
) {
  for (int index = 0; index < nodes.length; index += 1) {
    final KnowledgeNode node = nodes[index];
    if (node.id == parentId) {
      return _ParentLocation(
        parentId: parentId,
        siblings: node.children,
        index: node.children.length,
      );
    }
    final _ParentLocation? childLocation = _findParentLocation(
      node.children,
      parentId,
    );
    if (childLocation != null) {
      return childLocation;
    }
  }
  return null;
}

_ParentLocation? _findParentLocationForNode(
  List<KnowledgeNode> nodes,
  String nodeId,
) {
  for (int index = 0; index < nodes.length; index += 1) {
    final KnowledgeNode node = nodes[index];
    if (node.id == nodeId) {
      return _ParentLocation(parentId: null, siblings: nodes, index: index);
    }
    for (
      int childIndex = 0;
      childIndex < node.children.length;
      childIndex += 1
    ) {
      if (node.children[childIndex].id == nodeId) {
        return _ParentLocation(
          parentId: node.id,
          siblings: node.children,
          index: childIndex,
        );
      }
    }
    final _ParentLocation? deeperLocation = _findParentLocationForNode(
      node.children,
      nodeId,
    );
    if (deeperLocation != null) {
      return deeperLocation;
    }
  }
  return null;
}

List<KnowledgeNode> _replaceChildren(
  List<KnowledgeNode> nodes,
  String parentId,
  List<KnowledgeNode> nextChildren,
) {
  return _mapNodeList(
    nodes,
    parentId,
    (KnowledgeNode node) => node.copyWith(children: nextChildren),
  );
}

String _formatTimestamp(DateTime timestamp) {
  final DateTime local = timestamp.toLocal();
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}

String _formatDue(DateTime? dueAt) {
  if (dueAt == null) {
    return 'now';
  }
  return _formatTimestamp(dueAt);
}
