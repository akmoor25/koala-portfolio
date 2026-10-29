import 'dart:convert';

import 'package:flutter_quill/quill_delta.dart';

import '../entity/mark_entity.dart';
import '../helper/act_type.dart';
import '../helper/time_zones.dart';
import '../notes/note_document.dart';
import 'firebase/firebase_services.dart';
import 'sample_note.dart';
import 'sample_step.dart';
import 'sample_texts_en.dart';
import 'sample_tours_americas.dart';
import 'sample_tours_asia_pacific.dart';
import 'sample_tours_europe.dart';

/// 試しに眺められる、しおり 1 冊分。
class SampleLeaflet {
  /// しおりの見た目と、旅程、ノートの本文（Quill の Delta JSON）をまとめる。
  const SampleLeaflet({
    required this.title,
    required this.emoji,
    required this.coverColor,
    required this.marks,
    required this.noteText,
  });

  /// しおりの名前。
  final String title;

  /// 表紙の絵文字。
  final String emoji;

  /// 表紙の背景色（ARGB の整数値）。
  final int coverColor;

  /// 旅程。開始日時の昇順。
  final List<MarkEntity> marks;

  /// ノートの本文（Quill の Delta を JSON にした文字列）。
  final String noteText;
}

/// 日本語の文章を、[languageCode] の言語にする。英語の訳が無ければ日本語のまま。
String Function(String) _translator(String languageCode) {
  if (languageCode == 'ja') return (text) => text;
  return (text) => sampleTextsEn[text] ?? text;
}

/// 沖縄のノート。これから行く旅なので、持ち物はチェックリストで準備中。
final _okinawaNote = <SampleParagraph>[
  heading('この旅のこと'),
  para([
    '結婚 5 周年の記念に、',
    bold('初めて二人で行った海', color: SampleColor.blue),
    'へ、もう一度。',
  ]),
  quote(['あのときは雨で行けなかった古宇利島。今度こそ、晴れた日の海の色を見たい。']),
  heading('楽しみなこと'),
  numbered([colored('ジンベエザメの餌やり', SampleColor.orange, bold: true)]),
  numbered(['古宇利島の橋を、窓を開けてドライブ']),
  numbered(['再建中の首里城の正殿を見る']),
  heading('持ち物'),
  todo(['水着とラッシュガード'], done: true),
  todo(['日焼け止め・サングラス']),
  todo(['羽織るもの（機内と夜は冷える）']),
  todo(['結婚式の写真（同じ場所で撮り直す）']),
  heading('予約メモ'),
  bullet(['レンタカー：', bold('2 日目の 8:00 に受け取り')]),
  bullet([struck('首里城は最終日の午後'), ' → 午前に変更（空港へ余裕を持つため）']),
  bullet([
    '観光情報：',
    link('Visit Okinawa Japan', 'https://visitokinawajapan.com/'),
  ]),
  para([colored('台風が近いときは、欠航の情報をこまめに確認する', SampleColor.red)]),
];

/// 京都のノート。去年の春に、母と行った旅。
final _kyotoNote = <SampleParagraph>[
  heading('旅のテーマ'),
  para(['母を連れて行く、', bold('桜の京都'), '。ゆっくり歩けるように、1 日の予定は少なめに。']),
  heading('出発前チェック'),
  todo(['新幹線の E 席（富士山の側）を予約'], done: true),
  todo(['母の歩きやすい靴を、一緒に買いに行く'], done: true),
  todo(['折りたたみ傘（春の雨に備えて）'], done: true),
  heading('桜の見どころ'),
  bullet([bold('祇園白川'), '：夜のライトアップ']),
  bullet([bold('嵐山'), '：トロッコ列車の窓から']),
  bullet([
    '開花の情報：',
    link('Kyoto City Official Travel Guide', 'https://kyoto.travel/'),
  ], indent: 1),
  heading('食べたいもの'),
  todo(['湯豆腐'], done: true),
  todo(['抹茶パフェ'], done: true),
  todo(['出汁巻き卵（錦市場）'], done: true),
  heading('旅を終えて'),
  quote(['「また来年も来ようね」と母。白川の夜桜の下で、久しぶりにたくさん話せた。']),
  para([colored('次は、紅葉の季節に。', SampleColor.purple, bold: true)]),
];

/// 北海道のノート。これから行く、冬の旅。
final _hokkaidoNote = <SampleParagraph>[
  heading('この旅のこと'),
  para(['雪を見たことがない', bold('姪っ子'), 'と、はじめての冬の北海道へ。']),
  quote(['「雪だるまをつくりたい！」……その一言で、この旅を決めた。']),
  heading('防寒の持ち物'),
  todo(['ダウンジャケット（姪っ子の分も）'], done: true),
  todo(['手袋とネックウォーマー']),
  todo(['滑りにくい靴']),
  todo(['カイロ']),
  para([colored('路面が凍っているので、歩くときは小さな歩幅で', SampleColor.red, bold: true)]),
  heading('食べたいもの'),
  numbered(['札幌ラーメン']),
  numbered(['ジンギスカン']),
  numbered(['海鮮丼']),
  bullet(['イクラは、姪っ子と半分こ'], indent: 1),
  numbered(['スープカレー']),
  heading('参考'),
  bullet([link('HOKKAIDO LOVE!', 'https://www.visit-hokkaido.jp/')]),
];

/// 国内旅行 3 冊と、地域ごとの海外旅行 5 冊を作る。日付は [now]（東京の日付）を基準にする。
///
/// しおり一覧では、次の区分に分かれる。
/// - Next：沖縄（40 日後）、北海道（12 日後）。
/// - Now：シドニー（2 日前に出発）。開いたときに「いま・つぎ」が見える。
/// - 今年：アメリカ大陸（50 日前）、地中海（130 日前）。作るのが年の前半だと、前の年に入る。
/// - 前の年：ヨーロッパ（9 月）、アジア（6 月）、京都（3 月の桜）。季節に合わせて日付を決める。
///
/// 海外旅行は、エリアごとに近い国や都市を巡る密度の高い旅程（タイムゾーンをまたぐ移動と、
/// 各都市の現地時刻の確認用）。文章は [languageCode]（`ja` か `en`）の言語で作る。
List<SampleLeaflet> buildSampleLeaflets(
  DateTime now, {
  String languageCode = 'ja',
}) {
  final t = _translator(languageCode);
  // 日付は、日本の「今日」を基準にする（国内の 3 冊は、すべて東京のタイムゾーン）。
  final tokyoNow = wallOf(sampleHomeZone, now);
  final today = DateTime(tokyoNow.year, tokyoNow.month, tokyoNow.day);
  final lastYear = today.year - 1;
  DateTime daysFromToday(int days) =>
      DateTime(today.year, today.month, today.day + days);

  List<MarkEntity> marksOf(DateTime first, List<SampleStep> steps) {
    return [for (final step in steps) _markOf(first, step, t)];
  }

  return [
    SampleLeaflet(
      title: t('沖縄２泊３日'),
      emoji: '🌺🌴🪸🍍',
      coverColor: 0xFF00ACC1,
      marks: marksOf(daysFromToday(40), const [
        SampleStep(
          0,
          (7, 30),
          (8, 30),
          '自宅から羽田空港へ',
          type: ActType.train,
          remark: '出発の朝は、いつもより早起き。空港で朝ごはんを食べるのも、旅の楽しみのひとつ',
        ),
        SampleStep(
          0,
          (9, 30),
          (12, 15),
          '羽田空港 → 那覇空港',
          type: ActType.airplane,
          remark: '窓側の席を予約済み。着陸の前に見える、エメラルドグリーンの海が待ち遠しい',
        ),
        SampleStep(
          0,
          (12, 45),
          (14, 0),
          '沖縄そばでランチ',
          type: ActType.walking,
          remark: '着いて最初のごはんは、沖縄そば。コーレーグースを少しだけ入れてみる',
        ),
        SampleStep(
          0,
          (14, 30),
          (16, 30),
          '国際通りを散策',
          type: ActType.walking,
          remark: 'お土産は下見だけにして、買うのは最終日。ブルーシールのアイスは、今日食べる',
        ),
        SampleStep(0, (17, 0), (17, 30), 'ホテルへ移動', type: ActType.taxi),
        SampleStep(
          0,
          (19, 0),
          (20, 30),
          '夕食（島料理の居酒屋）',
          remark: '三線のライブがある居酒屋を予約（19:00）。二人の記念日だと伝えてある',
        ),
        SampleStep(
          1,
          (8, 30),
          (10, 30),
          'レンタカーで美ら海水族館へ',
          type: ActType.car,
          remark: '朝の高速は混むので、早めに出発。運転は交代で、助手席は DJ 係',
        ),
        SampleStep(
          1,
          (10, 30),
          (14, 0),
          '美ら海水族館',
          link: 'https://churaumi.okinawa/',
          remark: 'いちばんの楽しみ、ジンベエザメ！餌やりの時刻は、入口で確認する',
        ),
        SampleStep(
          1,
          (14, 30),
          (16, 0),
          '古宇利島をドライブ',
          type: ActType.car,
          about: true,
          remark: '前回は雨で行けなかった場所。今度こそ、橋の上から海の色を見たい',
        ),
        SampleStep(
          1,
          (18, 30),
          (20, 0),
          '夕食（ステーキ）',
          remark: '沖縄は、飲んだ後にステーキで締める文化があるらしい。体験してみる',
        ),
        SampleStep(
          2,
          (9, 0),
          (11, 0),
          '首里城公園を散策',
          type: ActType.walking,
          remark: '再建中の正殿を見られるのは、今だけ。工事の様子を見学できるのも楽しみ',
        ),
        SampleStep(
          2,
          (11, 30),
          (13, 0),
          'お土産と遅めのランチ',
          remark: '職場には紅芋タルト、自分たちには、やちむんの器を 1 つずつ',
        ),
        SampleStep(2, (14, 0), (14, 30), '空港へ移動', type: ActType.bus),
        SampleStep(
          2,
          (16, 0),
          (18, 30),
          '那覇空港 → 羽田空港',
          type: ActType.airplane,
          remark: '日焼けした腕を見ながら、また来ようねと話す帰り道',
        ),
      ]),
      noteText: sampleNoteJson(_okinawaNote, t),
    ),
    SampleLeaflet(
      title: t('京都２泊３日'),
      emoji: '🌸⛩️🍵🚄',
      coverColor: 0xFFE53935,
      marks: marksOf(DateTime(lastYear, 3, 28), const [
        SampleStep(
          0,
          (8, 0),
          (10, 15),
          '東京 → 京都（新幹線）',
          type: ActType.train,
          remark: '富士山が見える E 席を予約済み。晴れますように',
        ),
        SampleStep(0, (10, 45), (12, 0), '荷物をホテルに預ける'),
        SampleStep(
          0,
          (12, 0),
          (13, 30),
          '伏見稲荷大社で千本鳥居',
          type: ActType.walking,
          remark: '千本鳥居は、奥へ進むほど人が減る。四ツ辻まで登って、京都の街を見下ろしたい',
        ),
        SampleStep(
          0,
          (14, 0),
          (16, 30),
          '祇園を散策',
          type: ActType.bus,
          remark: '白川沿いの桜並木を見るのが、この旅の目的のひとつ',
        ),
        SampleStep(
          0,
          (18, 0),
          (20, 0),
          '夕食（先斗町）',
          remark: '鴨川が見える席を予約（18:00）。夜桜を眺めながら乾杯',
        ),
        SampleStep(1, (8, 30), (9, 30), '嵯峨嵐山へ（JR）', type: ActType.train),
        SampleStep(
          1,
          (9, 30),
          (11, 0),
          '竹林の小径と渡月橋',
          type: ActType.walking,
          remark: '朝の竹林は、空気が澄んでいるらしい。人が少ないうちに歩きたい',
        ),
        SampleStep(
          1,
          (11, 30),
          (12, 15),
          '嵯峨野トロッコ列車',
          type: ActType.train,
          remark: '保津川沿いの桜を、窓のないオープン車両から眺める',
        ),
        SampleStep(
          1,
          (12, 30),
          (14, 0),
          '湯豆腐のランチ',
          remark: '母が若いころに食べて、忘れられないと言っていた湯豆腐。同じ店を探してみる',
        ),
        SampleStep(
          1,
          (15, 0),
          (17, 30),
          '清水寺と二年坂・三年坂',
          type: ActType.bus,
          about: true,
          remark: '清水の舞台から、春の京都を一望。坂道の途中で、抹茶ソフトを食べる',
        ),
        SampleStep(1, (19, 0), (20, 30), '夕食（京料理）'),
        SampleStep(
          2,
          (9, 0),
          (10, 30),
          '金閣寺',
          type: ActType.bus,
          remark: '池に映る金閣を、晴れた朝に。写真は、鏡のように映る角度で',
        ),
        SampleStep(
          2,
          (11, 0),
          (13, 0),
          '錦市場で食べ歩き',
          type: ActType.walking,
          remark: '出汁巻き卵と豆乳ドーナツは必ず。お土産の漬物も、ここで選ぶ',
        ),
        SampleStep(2, (14, 30), (16, 45), '京都 → 東京（新幹線）', type: ActType.train),
      ]),
      noteText: sampleNoteJson(_kyotoNote, t),
    ),
    SampleLeaflet(
      title: t('北海道２泊３日'),
      emoji: '❄️⛄️❄️🛷',
      coverColor: 0xFF5C6BC0,
      marks: marksOf(daysFromToday(12), const [
        SampleStep(0, (8, 0), (9, 30), '羽田空港へ', type: ActType.train),
        SampleStep(
          0,
          (10, 30),
          (12, 10),
          '羽田空港 → 新千歳空港',
          type: ActType.airplane,
          remark: '姪っ子に、窓から雪原を見せてあげたくて、窓側の席を選んだ',
        ),
        SampleStep(0, (12, 40), (13, 20), '快速エアポートで札幌へ', type: ActType.train),
        SampleStep(
          0,
          (13, 30),
          (15, 0),
          '札幌ラーメンのランチ',
          remark: '味噌ラーメンに、バターとコーンをのせる王道で',
        ),
        SampleStep(
          0,
          (15, 30),
          (17, 30),
          '大通公園と時計台',
          type: ActType.walking,
          remark: '公園の雪で、念願の雪だるまづくり。手袋の替えも持っていく',
        ),
        SampleStep(
          0,
          (19, 0),
          (21, 0),
          '夕食（ジンギスカン）',
          remark: '煙のにおいがつくので、上着は店のビニール袋に入れる',
        ),
        SampleStep(1, (9, 0), (9, 45), '小樽へ（JR）', type: ActType.train),
        SampleStep(
          1,
          (10, 0),
          (12, 0),
          '小樽運河を散策',
          type: ActType.walking,
          remark: '雪の積もった運河と倉庫を背景に、姪っ子と写真を撮りたい',
        ),
        SampleStep(
          1,
          (12, 0),
          (13, 30),
          '海鮮丼のランチ',
          remark: 'ウニ、イクラ、カニ。全部のせにするか、真剣に悩む予定',
        ),
        SampleStep(
          1,
          (14, 0),
          (16, 0),
          'ガラス工房で体験',
          about: true,
          remark: '自分で吹いたグラスで、家に帰ってから乾杯したい',
        ),
        SampleStep(1, (17, 0), (17, 45), '札幌へ戻る', type: ActType.train),
        SampleStep(
          2,
          (9, 0),
          (11, 30),
          '藻岩山ロープウェイと展望台',
          type: ActType.ropeway,
          remark: '晴れたら、雪の札幌の街と石狩湾まで見渡せるかもしれない',
        ),
        SampleStep(
          2,
          (12, 0),
          (13, 30),
          'スープカレーのランチ',
          remark: '辛さは控えめにして、姪っ子と分け合う。野菜がごろごろ入っているのがうれしい',
        ),
        SampleStep(2, (14, 30), (15, 15), '新千歳空港へ', type: ActType.train),
        SampleStep(
          2,
          (17, 0),
          (18, 40),
          '新千歳空港 → 羽田空港',
          type: ActType.airplane,
          remark: '空港で、家族へのお菓子と、自分用のじゃがいものお菓子を買って帰る',
        ),
      ]),
      noteText: sampleNoteJson(_hokkaidoNote, t),
    ),
    SampleLeaflet(
      title: t('アジア３か国周遊'),
      emoji: '🥬🥩🥟🥗🥪',
      coverColor: 0xFF00897B,
      marks: marksOf(DateTime(lastYear, 6, 14), asiaTourSteps),
      noteText: sampleNoteJson(asiaTourNote, t),
    ),
    SampleLeaflet(
      title: t('ヨーロッパ鉄道旅行'),
      emoji: '🎨🏰🚂🖼️🛶',
      coverColor: 0xFF7E57C2,
      marks: marksOf(DateTime(lastYear, 9, 12), europeTourSteps),
      noteText: sampleNoteJson(europeTourNote, t),
    ),
    SampleLeaflet(
      title: t('地中海３都市めぐり'),
      emoji: '🏛️🍝🥘🫒⛵',
      coverColor: 0xFFF9A825,
      marks: marksOf(daysFromToday(-130), mediterraneanTourSteps),
      noteText: sampleNoteJson(mediterraneanTourNote, t),
    ),
    SampleLeaflet(
      title: t('アメリカ大陸の都市旅行'),
      emoji: '🗽🌴🍔🍕✈️',
      coverColor: 0xFFEF6C00,
      marks: marksOf(daysFromToday(-50), americasTourSteps),
      noteText: sampleNoteJson(americasTourNote, t),
    ),
    SampleLeaflet(
      title: t('シドニー５日間'),
      emoji: '🐨🦘🏄🌊☀️',
      coverColor: 0xFF3949AB,
      marks: marksOf(daysFromToday(-2), sydneyTourSteps),
      noteText: sampleNoteJson(sydneyTourNote, t),
    ),
  ];
}

/// [step] を、旅の初日 [first] を基準にした旅程にする。
///
/// 開始と終了は、それぞれのタイムゾーンの現地時刻。飛行機などの [SampleStep.duration] が
/// あるときは、開始に所要時間を足して終了にする（夏時間でも矛盾しない）。
MarkEntity _markOf(DateTime first, SampleStep step, String Function(String) t) {
  final start = instantOf(
    step.zone,
    DateTime(
      first.year,
      first.month,
      first.day + step.day,
      step.start.$1,
      step.start.$2,
    ),
  );
  final endZone = step.endZone ?? step.zone;
  final duration = step.duration;
  final endTime = step.end;
  if (duration == null && endTime == null) {
    throw StateError('A step needs an end or a duration: ${step.title}');
  }
  final end = duration != null
      ? start.add(duration)
      : instantOf(
          endZone,
          DateTime(
            first.year,
            first.month,
            first.day + step.day,
            endTime!.$1,
            endTime.$2,
          ),
        );
  return MarkEntity(
    '',
    step.about,
    step.type,
    t(step.title),
    t(step.remark),
    step.link,
    step.zone,
    start,
    end,
    endTimeZoneId: endZone == step.zone ? '' : endZone,
  );
}

/// サンプル作成の進捗。
class SampleInstallProgress {
  /// 完了した書き込み数、全書き込み数、現在のしおり名。
  const SampleInstallProgress(this.completed, this.total, this.title);

  /// 完了した書き込み数。
  final int completed;

  /// 全書き込み数。
  final int total;

  /// 現在作成しているしおり名。
  final String title;

  /// 0 から 1 までの進捗率。
  double get fraction => total == 0 ? 0 : completed / total;
}

/// サンプル 1 冊の進捗のうち、旅程以外の段階の数（しおりの作成、ノート、期間、表紙）。
///
/// 旅程は 1 回で保存するが、件数の多さが進捗の伸びに表れるよう、旅程の件数を別に足す。
const _stepsBesidesMarks = 4;

/// [buildSampleLeaflets] のサンプルを、自分のしおりとして追加する。
///
/// しおりを作ってから旅程とノートを書き、最後に期間と表紙の色を保存する。
/// 追加したしおりの数を返す。
Future<int> installSampleLeaflets({
  required FirebaseLeafletRepository leaflets,
  required FirebaseMarkRepository marks,
  required FirebaseNoteRepository notes,
  DateTime? now,
  String languageCode = 'ja',
  void Function(SampleInstallProgress progress)? onProgress,
}) async {
  final samples = buildSampleLeaflets(
    now ?? DateTime.now(),
    languageCode: languageCode,
  );
  final total = samples.fold<int>(
    0,
    (sum, sample) => sum + sample.marks.length + _stepsBesidesMarks,
  );
  var completed = 0;
  void report(String title) {
    onProgress?.call(SampleInstallProgress(completed, total, title));
  }

  if (samples.isNotEmpty) report(samples.first.title);
  for (final sample in samples) {
    final key = await leaflets.addLeaflet(
      sample.title,
      coverEmoji: sample.emoji,
    );
    completed++;
    report(sample.title);
    await marks.createMarks(key, sample.marks);
    for (var i = 0; i < sample.marks.length; i++) {
      completed++;
      report(sample.title);
    }
    final note = NoteDocument.fromDelta(
      Delta.fromJson(jsonDecode(sample.noteText) as List<Object?>),
      notes.newNoteId(),
      notes.newNoteId,
    );
    await notes.createNote(key, note);
    completed++;
    report(sample.title);
    await leaflets.updateLeafletPeriod(
      key,
      firstDate: sample.marks.first.startDate,
      lastDate: sample.marks.last.endDate,
      firstTimeZoneId: sample.marks.first.startZoneId,
      lastTimeZoneId: sample.marks.last.endZoneId,
    );
    completed++;
    report(sample.title);
    await leaflets.updateLeafletCover(
      key,
      imageUrl: sample.emoji,
      coverColor: sample.coverColor,
    );
    completed++;
    report(sample.title);
  }
  return samples.length;
}
