import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/notes/note_document.dart';

void main() {
  var sequence = 0;
  String id() => 'id-${sequence++}';
  NoteDocument note(String text) {
    const empty = NoteDocument('g', {});
    final changes = editNoteLines(
      empty,
      Delta()..insert('\n'),
      Delta()..insert(text),
      id,
    );
    return NoteDocument('g', changes);
  }

  test('splits across operations and preserves newline attributes', () {
    final delta = Delta()
      ..insert('bold', {'bold': true})
      ..insert('\n', {'header': 1})
      ..insert('plain\n\n');
    final bodies = splitNoteDelta(delta);
    expect(bodies, hasLength(3));
    final doc = NoteDocument('g', {
      for (var i = 0; i < bodies.length; i++)
        'l$i': NoteLine(
          id: 'l$i',
          generation: 'g',
          afterId: i == 0 ? '' : 'l${i - 1}',
          order: i + 1,
          writeId: 'w',
          delta: bodies[i],
        ),
    });
    expect(doc.toDelta(), delta);
    expect(NoteDocument.parse(doc.toJson()).toDelta(), delta);
  });

  test('enforces exact grapheme and paragraph boundaries', () {
    final blank = Delta()..insert('\n');
    for (final character in ['a', 'あ', '👨‍👩‍👧‍👦', 'e\u0301']) {
      expect(
        acceptsNoteChange(blank, Delta()..insert('${character * 1000}\n')),
        isTrue,
      );
      expect(
        acceptsNoteChange(blank, Delta()..insert('${character * 1001}\n')),
        isFalse,
      );
    }
    expect(acceptsNoteChange(blank, Delta()..insert('\n' * 500)), isTrue);
    expect(acceptsNoteChange(blank, Delta()..insert('\n' * 501)), isFalse);
  });

  test('split keeps left identity and join tombstones the right identity', () {
    final original = note('abc');
    final left = original.visibleLines.single.id;
    final before = original.toDelta();
    final split = editNoteLines(
      original,
      before,
      Delta()
        ..retain(1)
        ..insert('\n'),
      id,
    );
    final divided = NoteDocument('g', {...original.lines, ...split});
    expect(divided.visibleLines.first.id, left);
    expect(divided.visibleLines, hasLength(2));
    final right = divided.visibleLines.last.id;
    final merged = editNoteLines(
      divided,
      divided.toDelta(),
      Delta()
        ..retain(1)
        ..delete(1),
      id,
    );
    expect(merged[right]!.deleted, isTrue);
    expect(NoteDocument('g', {...divided.lines, ...merged}).toDelta(), before);
  });

  test(
    'same-anchor concurrent insertions converge regardless of map order',
    () {
      final base = note('a\nb');
      final first = base.visibleLines.first;
      NoteLine inserted(String id) => NoteLine(
        id: id,
        generation: 'g',
        afterId: first.id,
        order: 10,
        writeId: id,
        delta: '[{"insert":"$id\\n"}]',
      );
      final a = NoteDocument('g', {
        ...base.lines,
        'x': inserted('x'),
        'y': inserted('y'),
      });
      final b = NoteDocument('g', {
        'y': inserted('y'),
        'x': inserted('x'),
        ...base.lines,
      });
      expect(a.toDelta(), b.toDelta());
      expect(a.visibleLines.map((line) => line.id).toList().sublist(1, 3), [
        'y',
        'x',
      ]);
    },
  );

  test('deleting an entire paragraph preserves the following paragraph ID', () {
    final original = note('one\ntwo\nthree');
    final lines = original.visibleLines;
    final changes = editNoteLines(
      original,
      original.toDelta(),
      Delta()..delete(4),
      id,
    );
    final result = NoteDocument('g', {...original.lines, ...changes});
    expect(changes.keys, [lines.first.id]);
    expect(changes[lines.first.id]!.deleted, isTrue);
    expect(
      result.visibleLines.map((line) => line.id),
      lines.skip(1).map((line) => line.id),
    );
    expect(result.toDelta(), Delta()..insert('two\nthree\n'));
  });

  test(
    'over-limit received content can be reduced without losing other lines',
    () {
      final large = Delta()..insert('\n' * 501);
      expect(acceptsNoteChange(large, Delta()..insert('\n' * 500)), isTrue);
      expect(acceptsNoteChange(large, Delta()..insert('\n' * 502)), isFalse);
      final longParagraph = Delta()..insert('${'a' * 1001}\n');
      expect(
        acceptsNoteChange(longParagraph, Delta()..insert('${'a' * 1000}\n')),
        isTrue,
      );
      expect(acceptsNoteChange(longParagraph, longParagraph), isFalse);
      expect(
        acceptsNoteChange(longParagraph, Delta()..insert('${'a' * 1002}\n')),
        isFalse,
      );
    },
  );

  test('serialized bodies have a separate technical limit', () {
    final blank = Delta()..insert('\n');
    final hugeStyle = Delta()
      ..insert('a', {'link': 'x' * 20000})
      ..insert('\n');
    expect(acceptsNoteChange(blank, hugeStyle), isFalse);
    expect(() => decodeLine('x' * 20001), throwsFormatException);
  });
}
