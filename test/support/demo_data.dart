import 'package:koala/entity/leaflet_entity.dart';
import 'package:koala/entity/mark_entity.dart';
import 'package:koala/helper/act_type.dart';

/// 利用者（自分）の uid。
const demoUserId = 'demo-me';

/// 初期データのしおりのキー。本物と同じ形式（12 文字の公開用しおり ID）にして、画面の表示を本物に近づける。
const demoTripKey = 'D3M0TR1P0001';

/// 初期データのしおりの名前。テストで画面の文字を探すのにも使う。
const demoTripTitle = '沖縄 2 泊 3 日';

/// 初期データの旅程のうち、「いま」にあたる旅程の名前。
const demoNowStepTitle = '国際通りを散策';

/// 初期データのノートにある 1 行。
const demoNoteLine = '日焼け止め・サングラス';

/// [DemoDatabase] の初期データになる、しおり 1 冊分。
class DemoLeaflet {
  /// しおりと旅程、ノートの本文（Quill の Delta JSON）をまとめる。
  const DemoLeaflet(this.leaflet, this.marks, this.noteText);

  /// しおり。
  final LeafletEntity leaflet;

  /// 旅程。開始日時の昇順。
  final List<MarkEntity> marks;

  /// ノートの本文（Quill の Delta を JSON にした文字列）。
  final String noteText;
}

/// 初期データ用のサンプルを [now] を基準に作る。
///
/// 「いま」と「つぎ」が必ず表示に現れるよう、旅の途中の時刻に合わせる。
List<DemoLeaflet> buildDemoLeaflets(DateTime now) {
  final base = DateTime(now.year, now.month, now.day, now.hour);
  DateTime at(int hours, [int minutes = 0]) =>
      base.add(Duration(hours: hours, minutes: minutes));

  final marks = <MarkEntity>[
    MarkEntity(
      'demo-1',
      false,
      ActType.train,
      '自宅を出発',
      '',
      '',
      'Asia/Tokyo',
      at(-6),
      at(-5, 30),
    ),
    MarkEntity(
      'demo-2',
      false,
      ActType.airplane,
      '羽田空港 → 那覇空港',
      '機内ではお菓子を食べる',
      '',
      'Asia/Tokyo',
      at(-4),
      at(-1, 30),
    ),
    MarkEntity(
      'demo-3',
      false,
      ActType.walking,
      demoNowStepTitle,
      'お土産を買う',
      '',
      'Asia/Tokyo',
      at(-1),
      at(1),
    ),
    MarkEntity(
      'demo-4',
      true,
      ActType.taxi,
      'ホテルへ移動',
      '',
      '',
      'Asia/Tokyo',
      at(1, 30),
      at(2),
    ),
    MarkEntity(
      'demo-5',
      false,
      null,
      '夕食（沖縄そば）',
      '予約済み（19:00）',
      '',
      'Asia/Tokyo',
      at(3),
      at(4, 30),
    ),
    MarkEntity(
      'demo-6',
      false,
      ActType.bus,
      '美ら海水族館へ',
      '',
      '',
      'Asia/Tokyo',
      at(24),
      at(26),
    ),
  ];

  final leaflet = LeafletEntity(
    demoTripKey,
    demoTripTitle,
    '🌺',
    null,
    marks.first.startDate,
    marks.last.endDate,
    ownerUid: demoUserId,
  );

  const noteText =
      '[{"insert":"持ち物"},{"insert":"\\n","attributes":{"header":2}},'
      '{"insert":"パスポートは不要（国内旅行）"},{"insert":"\\n"},'
      '{"insert":"$demoNoteLine"},{"insert":"\\n"},'
      '{"insert":"行きたい場所"},{"insert":"\\n","attributes":{"header":2}},'
      '{"insert":"首里城・美ら海水族館・国際通り"},{"insert":"\\n"}]';

  return [DemoLeaflet(leaflet, marks, noteText)];
}
