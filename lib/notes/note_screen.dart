import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../components/app_button.dart';
import '../components/readable_width.dart';
import '../components/spacing.dart';
import '../data/app_services_scope.dart';
import '../entity/leaflet_entity.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import 'note_colors.dart';
import 'note_model.dart';
import 'note_styles.dart';
import 'remote_caret_overlay.dart';

/// 画面を離れる前に、未保存の変更の保存を待つ上限。
///
/// 通信が遅いときに戻る操作が固まらないよう打ち切り、保存せずに離れるか、編集を続けるかを尋ねる。
const _leaveSaveTimeout = Duration(seconds: 5);

class NoteScreen extends StatelessWidget {
  const NoteScreen(this._leaflet, {super.key});
  final LeafletEntity _leaflet;

  void _showMessage(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<NoteModel>(
      create: (context) {
        final model = NoteModel(_leaflet, context.services);
        model.onWriteError = (message) => _showMessage(context, message);
        unawaited(model.fetchNote());
        return model;
      },
      child: const _NoteContent(),
    );
  }
}

class _NoteContent extends StatefulWidget {
  const _NoteContent();

  @override
  State<_NoteContent> createState() => _NoteContentState();
}

class _NoteContentState extends State<_NoteContent> {
  bool _dialogOpen = false;
  bool _leaveAllowed = false;
  bool _leaving = false;
  bool _declinedReset = false;

  Future<void> _reset(NoteModel model) async {
    if (_dialogOpen || _declinedReset) return;
    _dialogOpen = true;
    final expected = model.unreadableValue;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(context.l10n.noteUnreadable),
        actions: [
          AppButton(
            onPressed: () => Navigator.pop(context, false),
            label: context.l10n.cancel,
          ),
          AppButton(
            onPressed: () => Navigator.pop(context, true),
            label: context.l10n.noteDiscard,
          ),
        ],
      ),
    );
    _dialogOpen = false;
    if (!mounted) return;
    if (discard == true) {
      await model.resetUnreadableNote(expected);
    } else {
      setState(() => _declinedReset = true);
    }
  }

  Future<void> _leave(NoteModel model) async {
    if (_leaving) return;
    _leaving = true;
    model.editorFocusNode.unfocus();
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    var saved = !model.hasUnsavedChanges;
    if (!saved) {
      saved = await model.putText().timeout(
        _leaveSaveTimeout,
        onTimeout: () => false,
      );
    }
    if (!mounted) return;
    var discard = false;
    if (!saved) {
      discard =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              content: Text(context.l10n.noteSaveFailed),
              actions: [
                AppButton(
                  onPressed: () => Navigator.pop(context, false),
                  label: context.l10n.noteKeepEditing,
                ),
                AppButton(
                  onPressed: () => Navigator.pop(context, true),
                  label: context.l10n.noteLeaveUnsaved,
                ),
              ],
            ),
          ) ==
          true;
    }
    if (!mounted) return;
    if (saved || discard) {
      setState(() => _leaveAllowed = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
    _leaving = false;
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<NoteModel>();
    model.l10n = context.l10n;
    if (model.invalidFormat &&
        !model.readFailed &&
        !_dialogOpen &&
        !_declinedReset) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_reset(model));
      });
    }
    return PopScope(
      canPop: _leaveAllowed,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          model.stopEditing();
        } else {
          unawaited(_leave(model));
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Note')),
        body: Consumer<NoteModel>(
          builder: (context, model, child) {
            model.l10n = context.l10n;
            final theme = Theme.of(context);
            if (!model.ready) {
              return Center(
                child: model.invalidFormat || model.readFailed
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            model.readFailed
                                ? context.l10n.noteReadFailed
                                : context.l10n.noteUnreadable,
                          ),
                          AppButton(
                            onPressed: () {
                              if (model.invalidFormat && !model.readFailed) {
                                _declinedReset = false;
                                unawaited(_reset(model));
                              } else {
                                unawaited(model.retryRead());
                              }
                            },
                            label: context.l10n.noteRetry,
                          ),
                        ],
                      )
                    : const CircularProgressIndicator(),
              );
            }
            return Column(
              children: [
                if (model.editingCount > 0)
                  Container(
                    width: double.infinity,
                    color: theme.koala.accentSoft,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpace.xsmall,
                      horizontal: AppSpace.medium,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit,
                          size: 16,
                          color: theme.koala.onAccentSoft,
                        ),
                        const HGap.small(),
                        Text(
                          context.l10n.othersEditing(model.editingCount),
                          style: TextStyle(
                            color: theme.koala.onAccentSoft,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: ReadableWidth(
                    maxWidth: AppWidth.reading,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        QuillSimpleToolbar(
                          controller: model.quillController,
                          config: QuillSimpleToolbarConfig(
                            multiRowsDisplay: false,
                            showFontFamily: false,
                            showFontSize: false,
                            showItalicButton: false,
                            showCodeBlock: false,
                            showInlineCode: false,
                            showSearchButton: false,
                            showSubscript: false,
                            showSuperscript: false,
                            // 背景色は、文字色との組み合わせで読めなくなるため使わない。
                            showBackgroundColorButton: false,
                            buttonOptions: QuillSimpleToolbarButtonOptions(
                              base: QuillToolbarBaseButtonOptions(
                                iconTheme: noteToolbarIconTheme(theme),
                              ),
                              // 黒・白を含まない、どちらのテーマでも読める色だけを選ばせる。
                              color: QuillToolbarColorButtonOptions(
                                customOnPressedCallback: (controller, _) =>
                                    showNoteColorDialog(context, controller),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: AppInsets.small,
                            child: Container(
                              decoration: BoxDecoration(
                                color: theme.scaffoldBackgroundColor,
                                border: Border.all(color: theme.outlineColor),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: AppInsets.small,
                              child: RemoteCaretOverlay(
                                carets: model.remoteCarets,
                                editorKey: model.editorKey,
                                controller: model.quillController,
                                scrollController: model.editorScrollController,
                                child: QuillEditor.basic(
                                  controller: model.quillController,
                                  focusNode: model.editorFocusNode,
                                  scrollController:
                                      model.editorScrollController,
                                  config: QuillEditorConfig(
                                    editorKey: model.editorKey,
                                    customStyleBuilder: (attribute) =>
                                        noteDisplayStyle(
                                          attribute,
                                          DefaultTextStyle.of(context)
                                              .style
                                              .color,
                                        ),
                                    customStyles: noteEditorStyles(context),
                                    onLaunchUrl: (String url) async {
                                      await launchUrl(
                                        Uri.parse(url),
                                        mode: LaunchMode.externalApplication,
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
