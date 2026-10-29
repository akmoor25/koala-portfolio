import 'sample_tours_americas.dart';
import 'sample_tours_asia_pacific.dart';
import 'sample_tours_europe.dart';

/// サンプルのしおりの英語版。キーは日本語の文章。
///
/// 英語の端末では、サンプルを作るときに、日本語の文章をこの表で置き換える。
/// 表に無い文章は、日本語のまま使う（テストで、すべてに訳があることを確かめる）。
const sampleTextsEn = <String, String>{
  // 沖縄
  '沖縄２泊３日': 'Okinawa: 2 nights, 3 days',
  '自宅から羽田空港へ': 'Home to Haneda Airport',
  '羽田空港 → 那覇空港': 'Haneda → Naha Airport',
  '沖縄そばでランチ': 'Lunch: Okinawa soba',
  '国際通りを散策': 'Stroll along Kokusai Street',
  'ホテルへ移動': 'Go to the hotel',
  '夕食（島料理の居酒屋）': 'Dinner (island-food izakaya)',
  'レンタカーで美ら海水族館へ': 'Drive to Churaumi Aquarium',
  '美ら海水族館': 'Churaumi Aquarium',
  '古宇利島をドライブ': 'Drive around Kouri Island',
  '夕食（ステーキ）': 'Dinner (steak)',
  '首里城公園を散策': 'Walk around Shuri Castle Park',
  'お土産と遅めのランチ': 'Souvenirs and a late lunch',
  '空港へ移動': 'Go to the airport',
  '那覇空港 → 羽田空港': 'Naha Airport → Haneda',
  '持ち物': 'Things to bring',
  '日焼け止め・サングラス': 'Sunscreen and sunglasses',
  '羽織るもの（機内と夜は冷える）': 'Something to layer (cold on the plane and at night)',
  '出発の朝は、いつもより早起き。空港で朝ごはんを食べるのも、旅の楽しみのひとつ': 'Up earlier than usual on departure morning. Breakfast at the airport is part of the fun',
  '窓側の席を予約済み。着陸の前に見える、エメラルドグリーンの海が待ち遠しい': 'Window seat booked. Can\'t wait for the emerald-green sea just before landing',
  '着いて最初のごはんは、沖縄そば。コーレーグースを少しだけ入れてみる':
      'First meal on arrival: Okinawa soba, with a few drops of koregusu chili',
  'お土産は下見だけにして、買うのは最終日。ブルーシールのアイスは、今日食べる': 'Just scout the souvenirs and buy them on the last day. The Blue Seal ice cream, though, is for today',
  '三線のライブがある居酒屋を予約（19:00）。二人の記念日だと伝えてある': 'Booked an izakaya with live sanshin music (19:00). Told them it\'s our anniversary',
  '朝の高速は混むので、早めに出発。運転は交代で、助手席は DJ 係': 'The morning expressway gets busy, so leave early. We take turns driving; the passenger is the DJ',
  'いちばんの楽しみ、ジンベエザメ！餌やりの時刻は、入口で確認する':
      'The highlight: whale sharks! Check the feeding time at the entrance',
  '前回は雨で行けなかった場所。今度こそ、橋の上から海の色を見たい': 'Last time the rain kept us away. This time, I want to see the color of the sea from the bridge',
  '沖縄は、飲んだ後にステーキで締める文化があるらしい。体験してみる': 'In Okinawa, people apparently finish a night out with steak. We\'re trying it',
  '再建中の正殿を見られるのは、今だけ。工事の様子を見学できるのも楽しみ': 'Seeing the main hall under reconstruction is a now-only chance. Looking forward to watching the work',
  '職場には紅芋タルト、自分たちには、やちむんの器を 1 つずつ': 'Purple sweet potato tarts for work, and a piece of yachimun pottery for each of us',
  '日焼けした腕を見ながら、また来ようねと話す帰り道':
      'On the way home, looking at our tanned arms and promising to come back',
  '結婚 5 周年の記念に、': 'For our fifth wedding anniversary, back to ',
  '初めて二人で行った海': 'the first sea we visited together',
  'へ、もう一度。': ' once more.',
  'あのときは雨で行けなかった古宇利島。今度こそ、晴れた日の海の色を見たい。': 'Rain kept us from Kouri Island back then. This time, I want to see the sea on a sunny day.',
  'ジンベエザメの餌やり': 'Whale shark feeding time',
  '古宇利島の橋を、窓を開けてドライブ': 'Driving across the Kouri Bridge with the windows down',
  '再建中の首里城の正殿を見る': 'Seeing Shuri Castle\'s main hall being rebuilt',
  '水着とラッシュガード': 'Swimsuits and rash guards',
  '結婚式の写真（同じ場所で撮り直す）': 'Our wedding photo (to retake it in the same spot)',
  'レンタカー：': 'Rental car: ',
  '2 日目の 8:00 に受け取り': 'pick up at 8:00 on day 2',
  '首里城は最終日の午後': 'Shuri Castle on the last afternoon',
  ' → 午前に変更（空港へ余裕を持つため）': ' → moved to the morning (more time for the airport)',
  '台風が近いときは、欠航の情報をこまめに確認する':
      'If a typhoon is approaching, keep checking for flight cancellations',

  // 京都
  '京都２泊３日': 'Kyoto: 2 nights, 3 days',
  '東京 → 京都（新幹線）': 'Tokyo → Kyoto (Shinkansen)',
  '荷物をホテルに預ける': 'Leave the bags at the hotel',
  '伏見稲荷大社で千本鳥居': 'Thousand torii gates at Fushimi Inari',
  '祇園を散策': 'Stroll through Gion',
  '夕食（先斗町）': 'Dinner (Pontocho)',
  '嵯峨嵐山へ（JR）': 'To Saga-Arashiyama (JR)',
  '竹林の小径と渡月橋': 'Bamboo path and Togetsukyo Bridge',
  '嵯峨野トロッコ列車': 'Sagano Scenic Railway',
  '湯豆腐のランチ': 'Lunch: yudofu (hot tofu)',
  '清水寺と二年坂・三年坂': 'Kiyomizu-dera and the Ninenzaka slopes',
  '夕食（京料理）': 'Dinner (Kyoto cuisine)',
  '金閣寺': 'Kinkaku-ji (Golden Pavilion)',
  '錦市場で食べ歩き': 'Snack your way through Nishiki Market',
  '京都 → 東京（新幹線）': 'Kyoto → Tokyo (Shinkansen)',
  '食べたいもの': 'Things to eat',
  '湯豆腐': 'Yudofu',
  '抹茶パフェ': 'Matcha parfait',
  '出汁巻き卵（錦市場）': 'Dashimaki omelet (Nishiki Market)',
  '富士山が見える E 席を予約済み。晴れますように': 'Booked seat E for the view of Mount Fuji. Fingers crossed for clear skies',
  '千本鳥居は、奥へ進むほど人が減る。四ツ辻まで登って、京都の街を見下ろしたい': 'The farther you go through the torii, the fewer people. I want to climb to Yotsutsuji and look down on Kyoto',
  '白川沿いの桜並木を見るのが、この旅の目的のひとつ': 'Seeing the cherry trees along the Shirakawa canal is one of the reasons for this trip',
  '鴨川が見える席を予約（18:00）。夜桜を眺めながら乾杯': 'Booked a table overlooking the Kamo River (18:00). A toast under the evening blossoms',
  '朝の竹林は、空気が澄んでいるらしい。人が少ないうちに歩きたい': 'They say the air in the bamboo grove is crisp in the morning. I want to walk it before the crowds',
  '保津川沿いの桜を、窓のないオープン車両から眺める':
      'Watch the cherry trees along the Hozu River from the open-air car',
  '母が若いころに食べて、忘れられないと言っていた湯豆腐。同じ店を探してみる': 'Mom says she never forgot the yudofu she had here when she was young. I\'ll look for the same place',
  '清水の舞台から、春の京都を一望。坂道の途中で、抹茶ソフトを食べる': 'Take in spring Kyoto from the Kiyomizu stage. Matcha soft serve halfway up the slope',
  '池に映る金閣を、晴れた朝に。写真は、鏡のように映る角度で': 'The Golden Pavilion reflected in the pond on a sunny morning. Photos from the mirror-image angle',
  '出汁巻き卵と豆乳ドーナツは必ず。お土産の漬物も、ここで選ぶ': 'Dashimaki omelet and soy milk doughnuts for sure. Pick pickles to take home here too',
  '母を連れて行く、': 'Taking Mom to see ',
  '桜の京都': 'Kyoto in cherry blossom season',
  '。ゆっくり歩けるように、1 日の予定は少なめに。': '. Fewer plans each day so we can walk slowly.',
  '新幹線の E 席（富士山の側）を予約': 'Book seat E on the Shinkansen (the Mount Fuji side)',
  '母の歩きやすい靴を、一緒に買いに行く': 'Go shopping with Mom for comfortable walking shoes',
  '折りたたみ傘（春の雨に備えて）': 'Folding umbrella (for spring showers)',
  '祇園白川': 'Gion Shirakawa',
  '：夜のライトアップ': ': evening illumination',
  '嵐山': 'Arashiyama',
  '：トロッコ列車の窓から': ': from the scenic train',
  '開花の情報：': 'Bloom forecast: ',
  '「また来年も来ようね」と母。白川の夜桜の下で、久しぶりにたくさん話せた。': '"Let\'s come again next year," Mom said. Under the evening blossoms by the Shirakawa, we talked more than we had in ages.',
  '次は、紅葉の季節に。': 'Next time, for the autumn leaves.',

  // 北海道
  '北海道２泊３日': 'Hokkaido: 2 nights, 3 days',
  '羽田空港へ': 'To Haneda Airport',
  '羽田空港 → 新千歳空港': 'Haneda → New Chitose Airport',
  '快速エアポートで札幌へ': 'Rapid Airport train to Sapporo',
  '札幌ラーメンのランチ': 'Lunch: Sapporo ramen',
  '大通公園と時計台': 'Odori Park and the Clock Tower',
  '夕食（ジンギスカン）': 'Dinner (Genghis Khan lamb barbecue)',
  '小樽へ（JR）': 'To Otaru (JR)',
  '小樽運河を散策': 'Stroll along the Otaru Canal',
  '海鮮丼のランチ': 'Lunch: seafood rice bowl',
  'ガラス工房で体験': 'Glassmaking workshop',
  '札幌へ戻る': 'Back to Sapporo',
  '藻岩山ロープウェイと展望台': 'Mount Moiwa ropeway and observatory',
  'スープカレーのランチ': 'Lunch: soup curry',
  '新千歳空港へ': 'To New Chitose Airport',
  '新千歳空港 → 羽田空港': 'New Chitose → Haneda',
  '滑りにくい靴': 'Non-slip shoes',
  'カイロ': 'Hand warmers',
  '札幌ラーメン': 'Sapporo ramen',
  'ジンギスカン': 'Genghis Khan lamb barbecue',
  '海鮮丼': 'Seafood rice bowl',
  'スープカレー': 'Soup curry',
  '姪っ子に、窓から雪原を見せてあげたくて、窓側の席を選んだ':
      'I chose a window seat so my niece can see the snowfields from above',
  '味噌ラーメンに、バターとコーンをのせる王道で':
      'The classic: miso ramen topped with butter and corn',
  '公園の雪で、念願の雪だるまづくり。手袋の替えも持っていく':
      'Finally building a snowman in the park snow. Bringing spare gloves too',
  '煙のにおいがつくので、上着は店のビニール袋に入れる':
      'The smoke smell clings, so put coats in the restaurant\'s plastic bags',
  '雪の積もった運河と倉庫を背景に、姪っ子と写真を撮りたい':
      'I want a photo with my niece in front of the snowy canal and warehouses',
  'ウニ、イクラ、カニ。全部のせにするか、真剣に悩む予定': 'Sea urchin, salmon roe, crab. I plan to agonize over whether to get them all',
  '自分で吹いたグラスで、家に帰ってから乾杯したい':
      'I want to toast at home with a glass I blew myself',
  '晴れたら、雪の札幌の街と石狩湾まで見渡せるかもしれない':
      'On a clear day, we might see snowy Sapporo all the way to Ishikari Bay',
  '辛さは控えめにして、姪っ子と分け合う。野菜がごろごろ入っているのがうれしい': 'Mild spice so I can share with my niece. Love the big chunks of vegetables',
  '空港で、家族へのお菓子と、自分用のじゃがいものお菓子を買って帰る':
      'At the airport, sweets for the family and potato snacks for myself',
  '雪を見たことがない': 'My first Hokkaido winter, with my ',
  '姪っ子': 'niece',
  'と、はじめての冬の北海道へ。': ' who has never seen snow.',
  '「雪だるまをつくりたい！」……その一言で、この旅を決めた。': '"I want to build a snowman!" That one line was all it took to plan this trip.',
  'ダウンジャケット（姪っ子の分も）': 'Down jackets (one for my niece too)',
  '手袋とネックウォーマー': 'Gloves and neck warmers',
  '路面が凍っているので、歩くときは小さな歩幅で':
      'The roads are icy, so take small steps when walking',
  'イクラは、姪っ子と半分こ': 'Split the salmon roe with my niece',

  // 地域別の海外旅行
  '旅のテーマ': 'Trip theme',
  '予約と持ち物': 'Bookings and packing',
  '列車と美術館': 'Trains and museums',
  '出発前チェック': 'Pre-departure checklist',

  // 地域別の海外旅行で共通の文章
  '現地のメモ': 'Local notes',
  'ホテルにチェックイン': 'Check in at the hotel',
  'ホテルに荷物を預けて休憩': 'Leave bags at the hotel and rest',
  'ホテルを出て空港へ': 'Leave the hotel for the airport',
  'ホテルで荷物を受け取り空港へ': 'Pick up bags at the hotel and go to the airport',

  // ノートの見出し（共通）
  'この旅のこと': 'About this trip',
  '楽しみなこと': 'Looking forward to',
  '予約メモ': 'Booking notes',
  '観光情報：': 'Visitor info: ',
  '桜の見どころ': 'Cherry blossom spots',
  '防寒の持ち物': 'Cold-weather gear',
  '参考': 'References',
  '今日やること': 'To do today',
  '旅の日記': 'Travel diary',
  '旅を終えて': 'After the trip',
  'よかったことベスト 3': 'Top three moments',

  // 地域ごとの英訳
  ...sampleTextsEnAsiaPacific,
  ...sampleTextsEnEurope,
  ...sampleTextsEnAmericas,
};
