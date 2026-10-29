import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/notes/note_colors.dart';
import 'package:koala/theme/app_theme.dart';

void main() {
  final light = buildAppTheme(
    Brightness.light,
    useGoogleFonts: false,
  ).scaffoldBackgroundColor;
  final dark = buildAppTheme(
    Brightness.dark,
    useGoogleFonts: false,
  ).scaffoldBackgroundColor;

  test('the reference backgrounds are the app backgrounds', () {
    expect(noteLightBackground, light);
    expect(noteDarkBackground, dark);
  });

  test('every selectable color is readable on both themes', () {
    for (final color in NoteTextColor.values) {
      expect(
        contrastRatio(color.color, light),
        greaterThanOrEqualTo(3),
        reason: '${color.name} on light',
      );
      expect(
        contrastRatio(color.color, dark),
        greaterThanOrEqualTo(3),
        reason: '${color.name} on dark',
      );
      expect(isReadableNoteTextColor(color.color), isTrue);
    }
    expect(contrastRatio(noteLinkColor, light), greaterThanOrEqualTo(3));
    expect(contrastRatio(noteLinkColor, dark), greaterThanOrEqualTo(3));
  });

  test('black, white and near-neutral extremes are not readable', () {
    for (final color in const [
      Colors.black,
      Colors.white,
      Color(0xFF212121),
      Color(0xFFFAFAFA),
      Color(0xFF000080),
      Color(0xFFFFF59D),
    ]) {
      expect(isReadableNoteTextColor(color), isFalse, reason: '$color');
    }
  });

  group('noteDisplayStyle', () {
    const fallback = Color(0xFF123456);

    test('shows an unreadable color in the default text color', () {
      for (final value in ['#000000', '#ffffff', '#FFFFFFFF', '#212121']) {
        expect(
          noteDisplayStyle(ColorAttribute(value), fallback).color,
          fallback,
          reason: value,
        );
      }
    });

    test('keeps a readable color as stored', () {
      expect(
        noteDisplayStyle(
          ColorAttribute(NoteTextColor.blue.hex),
          fallback,
        ).color,
        isNull,
      );
    });

    test('hides stored backgrounds', () {
      expect(
        noteDisplayStyle(
          const BackgroundAttribute('#FFF59D'),
          fallback,
        ).backgroundColor,
        Colors.transparent,
      );
      expect(
        noteDisplayStyle(
          const BackgroundAttribute(null),
          fallback,
        ).backgroundColor,
        isNull,
      );
    });

    test('leaves other attributes alone', () {
      expect(noteDisplayStyle(Attribute.bold, fallback), const TextStyle());
    });
  });
}
