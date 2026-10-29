import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../components/app_button.dart';
import '../components/readable_width.dart';
import '../data/app_services_scope.dart';
import '../entity/leaflet_entity.dart';
import '../extension/extension.dart';
import '../l10n/l10n.dart';
import '../notes/note_screen.dart';
import 'marks_model.dart';

class MarksScreen extends StatefulWidget {
  final LeafletEntity _leaflet;

  const MarksScreen(this._leaflet, {super.key});

  @override
  State<MarksScreen> createState() => _MarksScreenState();
}

class _MarksScreenState extends State<MarksScreen> {
  MarksModel? _model;
  MarksModel get _marksModel => _model!;
  final ItemScrollController _itemScrollController = ItemScrollController();
  bool _hasScrolled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final existing = _model;
    if (existing != null) {
      existing.l10n = context.l10n;
      return;
    }
    _model = MarksModel(widget._leaflet, context.services)
      ..l10n = context.l10n
      ..onWriteError = _showError
      ..fetchMarksEntity()
      ..addListener(_onModelUpdated);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _onModelUpdated() {
    if (!_hasScrolled &&
        _marksModel.nowItemIndex != null &&
        _marksModel.listItems.isNotEmpty) {
      _hasScrolled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final index = _marksModel.nowItemIndex;
        if (index != null && _itemScrollController.isAttached) {
          _itemScrollController.jumpTo(index: index);
        }
      });
    }
  }

  @override
  void dispose() {
    _marksModel.removeListener(_onModelUpdated);
    _marksModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MarksModel>.value(
      value: _marksModel,
      child: Scaffold(
        appBar: AppBar(
          title: Consumer<MarksModel>(
            builder: (context, model, child) => AutoSizeText(
              maxLines: 1,
              model.leaflet?.title.withoutNewLineCode() ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          actions: [
            Consumer<MarksModel>(
              builder: (context, model, child) {
                final icon = model.isEditMode ? Icons.check : Icons.edit;
                return AppIconButton(
                  tooltip: model.isEditMode
                      ? context.l10n.doneEditing
                      : context.l10n.editMode,
                  onPressed: model.leaflet == null
                      ? null
                      : model.toggleEditMode,
                  icon: icon,
                );
              },
            ),
          ],
        ),
        body: Consumer<MarksModel>(
          builder: (context, model, child) {
            final listItems = model.listItems;
            // 時刻・アイコン・日付の円は、位置と大きさを決めて重ねている。
            // 文字サイズを最大にすると重なってしまうため、この画面の文字だけ 1.3 倍までにする
            // （アクセシビリティとのトレードオフ。ギャラリーの「文字サイズ最大」で確認）。
            return MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.3,
              // 左右の余白は、リストの余白にする（余白の部分でも、スクロールできる）。
              child: LayoutBuilder(
                builder: (context, constraints) =>
                    ScrollablePositionedList.builder(
                      padding: ReadableWidth.padding(
                        constraints.maxWidth,
                        maxWidth: AppWidth.reading,
                      ),
                      itemScrollController: _itemScrollController,
                      itemCount: listItems.length,
                      itemBuilder: (context, index) {
                        final item = listItems[index];
                        return item.build(context, model);
                      },
                    ),
              ),
            );
          },
        ),
        floatingActionButton: Consumer<MarksModel>(
          builder: (context, model, child) => FloatingActionButton(
            tooltip: context.l10n.openNote,
            onPressed: model.leaflet == null
                ? null
                : () {
                    final leaflet = model.leaflet;
                    if (leaflet == null) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (context) => NoteScreen(leaflet),
                      ),
                    );
                  },
            child: const Icon(Icons.library_books_outlined),
          ),
        ),
      ),
    );
  }
}
