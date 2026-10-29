import '../extension/extension.dart';

/// 旅のしおり 1 冊分。
class LeafletEntity {
  /// 必須の項目を指定して作る。
  LeafletEntity(
    this.key,
    this.title,
    this.imageUrl,
    this.coverColor,
    this.firstDate,
    this.lastDate, {
    this.firstTimeZoneId,
    this.lastTimeZoneId,
    this.ownerUid,
    this.shared = false,
  });

  /// Realtime Database のキー。共同編集の「公開用しおり ID」でもある。
  String key;

  /// しおりを作った人の uid。古いデータでは null。
  final String? ownerUid;

  /// オーナーが共同編集を有効にしているか。
  final bool shared;

  /// しおりの名前。
  String title;

  /// 表紙。絵文字、または古い形式の画像 URL。
  String? imageUrl;

  /// 表紙の背景色（ARGB の整数値）。
  int? coverColor;

  /// 旅程の最初の日時。旅程がなければ null。
  DateTime? firstDate;

  /// 旅程の最後の日時。旅程がなければ null。
  DateTime? lastDate;

  /// [firstDate] を現地時刻にするタイムゾーン ID。無ければ端末のタイムゾーン。
  String? firstTimeZoneId;

  /// [lastDate] を現地時刻にするタイムゾーン ID。無ければ端末のタイムゾーン。
  String? lastTimeZoneId;

  /// 表紙に敷き詰める絵文字。未設定または URL のときは既定の絵文字。
  String get coverEmoji {
    final url = imageUrl;
    if (url != null && url.isNotEmpty && !url.startsWith('http')) return url;
    return '🐨';
  }

  /// DB の値から作る。タイトルが無いなど、形式が不正なら null を返す。
  static LeafletEntity? tryBuild(String key, Map<Object?, Object?> map) {
    final title = map['title'];
    if (title is! String) return null;

    final imageUrl = map['imageUrl'];
    final coverColor = map['coverColor'];
    final firstDate = map['firstDate'];
    final lastDate = map['lastDate'];
    final ownerUid = map['ownerUid'];
    final firstZone = map['firstTimeZoneId'];
    final lastZone = map['lastTimeZoneId'];
    return LeafletEntity(
      key,
      title,
      imageUrl is String ? imageUrl : null,
      coverColor is int ? coverColor : null,
      firstDate is num ? fromSecondsSinceEpoch(firstDate.toInt()) : null,
      lastDate is num ? fromSecondsSinceEpoch(lastDate.toInt()) : null,
      firstTimeZoneId: firstZone is String ? firstZone : null,
      lastTimeZoneId: lastZone is String ? lastZone : null,
      ownerUid: ownerUid is String ? ownerUid : null,
      shared: map['shared'] == true,
    );
  }

  /// DB に保存する、後から変えられる項目。
  ///
  /// `ownerUid` と `shared` はオーナーだけが変えられるので含めない。
  Map<String, Object?> toJson() {
    return {
      'title': title,
      'imageUrl': imageUrl,
      'coverColor': coverColor,
      'firstDate': firstDate?.secondsSinceEpoch(),
      'lastDate': lastDate?.secondsSinceEpoch(),
      'firstTimeZoneId': firstTimeZoneId,
      'lastTimeZoneId': lastTimeZoneId,
    };
  }
}
