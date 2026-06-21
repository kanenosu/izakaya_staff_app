// import_menu.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'firebase_options.dart'; // FlutterFire CLI で生成したもの

/// 手持ちのデータをそのまま定義
final Map<String, dynamic> rawData = {
  'ドリンク': {
    'ハイボール': [
      {'name': '強炭酸角ハイボール(角、かくはい)', 'price': 520, 'icon': Icons.local_bar},
      {'name': '陸ハイボール', 'price': 520, 'icon': Icons.local_bar},
      {'name': 'コーラハイボール(コークハイ)', 'price': 580, 'icon': Icons.local_bar},
      {'name': 'ジンジャーハイボール(じんはい)', 'price': 580, 'icon': Icons.local_bar},
    ],
    'ジャパニーズジン': [
      {'name': '翠ジンソーダ', 'price': 580, 'icon': Icons.local_drink},
      {'name': '翠ジンレモン', 'price': 600, 'icon': Icons.local_drink},
    ],
    'ジン': [
      {'name': 'ビーフィーター', 'price': 580, 'icon': Icons.local_drink},
    ],
    'チューハイ': [
      {'name': '生絞りグレープフルーツサワー', 'price': 490, 'icon': Icons.local_drink},
      {'name': 'レモンサワー(れもさ, れもんs)', 'price': 490, 'icon': Icons.local_drink},
      {'name': 'ウーロンハイ(ウーハイ)', 'price': 490, 'icon': Icons.local_drink},
      {'name': 'シークワーサーサワー', 'price': 490, 'icon': Icons.local_drink},
      {'name': '生茶ハイ', 'price': 490, 'icon': Icons.local_drink},
      {'name': 'ラムネサワー(ラムネさ)', 'price': 490, 'icon': Icons.local_drink},
      {'name': '午後ティーハイ(午後ハイ)', 'price': 490, 'icon': Icons.local_drink},
      {'name': 'ゆずサワー(ゆずさ)', 'price': 490, 'icon': Icons.local_drink},
      {'name': 'トマトハイ', 'price': 490, 'icon': Icons.local_drink},
      {'name': '南高梅サワー(うめさ)', 'price': 490, 'icon': Icons.local_drink},
      {'name': '水割南高梅入り', 'price': 490, 'icon': Icons.local_drink},
      {'name': 'カルピスサワー(かるぴすさ)', 'price': 490, 'icon': Icons.local_drink},
      {'name': 'お湯割南高梅入り', 'price': 490, 'icon': Icons.local_drink},
      {'name': 'ジャスミン', 'price': 580, 'icon': Icons.local_drink},
    ],
    'ワイン': [
      {'name': 'フランジア', 'price': 600, 'icon': Icons.wine_bar},
      {'name': 'ロックワイン', 'price': 550, 'icon': Icons.wine_bar},
      {'name': 'ホットワイン', 'price': 550, 'icon': Icons.wine_bar},
      {'name': 'カリモーチョ', 'price': 580, 'icon': Icons.wine_bar},
      {'name': 'オペレーター', 'price': 580, 'icon': Icons.wine_bar},
      {'name': 'キティ', 'price': 580, 'icon': Icons.wine_bar},
      {'name': 'キール', 'price': 580, 'icon': Icons.wine_bar},
      {'name': 'ロマンティックハーモニー', 'price': 580, 'icon': Icons.wine_bar},
      {'name': 'スプリッツァー', 'price': 580, 'icon': Icons.wine_bar},
      {'name': '満期風アメリカンレモネード', 'price': 580, 'icon': Icons.wine_bar},
    ],
    'コールドプレスレモンサワー': [
      {'name': '生レモンサワー(なまれも)', 'price': 580, 'icon': Icons.local_drink},
      {'name': '塩レモンサワー(しおれも)', 'price': 580, 'icon': Icons.local_drink},
      {'name': '蜂蜜レモンサワー(はちれも)', 'price': 580, 'icon': Icons.local_drink},
    ],
    '万喜オリジナル': [
      {'name': 'コーヒー焼酎(コーヒー)', 'price': 600, 'icon': Icons.local_drink},
      {'name': '万喜秘蔵の酒(秘蔵)', 'price': 600, 'icon': Icons.local_drink},
      {'name': 'ガリガリくんサワー(ガリサワー)', 'price': 580, 'icon': Icons.local_drink},
    ],
    'カクテル': [
      {'name': 'カシスソーダ', 'price': 580, 'icon': Icons.local_drink},
      {'name': 'カシスオレンジ', 'price': 580, 'icon': Icons.local_drink},
      {'name': 'カシスウーロン', 'price': 580, 'icon': Icons.local_drink},
      // …（以降同じフォーマットで全アイテムを追加してください）
    ],
    'ビール': [
      {'name': 'ハートランド(生、生ビール)', 'price': 590, 'icon': Icons.sports_bar},
      {'name': 'ドラフトギネス(ギネス)', 'price': 620, 'icon': Icons.sports_bar},
      {'name': '赤星', 'price': 790, 'icon': Icons.sports_bar},
      {'name': 'アサヒスーパードライ(アサヒ)', 'price': 790, 'icon': Icons.sports_bar},
      {'name': '一番絞り', 'price': 790, 'icon': Icons.sports_bar},
      {'name': 'オールフリー', 'price': 490, 'icon': Icons.sports_bar},
    ],
    'ホッピー': [
      {'name': 'ホッピーセット', 'price': 550, 'icon': Icons.local_drink},
      {'name': 'ホッピー外', 'price': 280, 'icon': Icons.local_drink},
      {'name': 'ホッピー中', 'price': 250, 'icon': Icons.local_drink},
    ],
    '果実酒': [
      {'name': '焙煎樽仕込梅酒(ブランド梅酒)', 'price': 650, 'icon': Icons.local_drink},
      {'name': '梅酒', 'price': 580, 'icon': Icons.local_drink},
      {'name': 'ハチミツ梅酒(はちうめ)', 'price': 650, 'icon': Icons.local_drink},
      {'name': '鳳凰美田梅酒', 'price': 650, 'icon': Icons.local_drink},
      {'name': 'シンルチュウ（杏露酒）', 'price': 580, 'icon': Icons.local_drink},
      {'name': 'ライキチュウ（茘枝酒）', 'price': 580, 'icon': Icons.local_drink},
    ],
    '日本酒': [
      {'name': 'ど辛山本', 'price': 880, 'icon': Icons.local_drink},
      {'name': '玉乃光94', 'price': 880, 'icon': Icons.local_drink},
      {'name': '伯楽星', 'price': 880, 'icon': Icons.local_drink},
      {'name': '大七', 'price': 880, 'icon': Icons.local_drink},
      {'name': '九頭龍', 'price': 800, 'icon': Icons.local_drink},
      {'name': '鳳凰美田', 'price': 900, 'icon': Icons.local_drink},
      {'name': '花陽浴', 'price': 1300, 'icon': Icons.local_drink},
      {'name': '醸し人九平次', 'price': 1300, 'icon': Icons.local_drink},
      {'name': '十四代', 'price': 1600, 'icon': Icons.local_drink},
      {'name': '農口尚彦研究所', 'price': 1300, 'icon': Icons.local_drink},
      {'name': '飛露喜', 'price': 1500, 'icon': Icons.local_drink},
    ],
    '焼酎': [
      // 麦焼酎
      {'name': '二階堂', 'price': 500, 'icon': Icons.local_drink},
      {'name': '兼八', 'price': 500, 'icon': Icons.local_drink},
      {'name': '自然麦', 'price': 500, 'icon': Icons.local_drink},
      {'name': '中々', 'price': 500, 'icon': Icons.local_drink},
      {'name': '佐藤麦', 'price': 500, 'icon': Icons.local_drink},

      // 芋焼酎
      {'name': '佐藤黒', 'price': 500, 'icon': Icons.local_drink},
      {'name': '川越', 'price': 500, 'icon': Icons.local_drink},
      {'name': '明るい農村', 'price': 500, 'icon': Icons.local_drink},
      {'name': '萬膳', 'price': 500, 'icon': Icons.local_drink},
      {'name': '佐藤白', 'price': 500, 'icon': Icons.local_drink},
      {'name': '富乃宝山', 'price': 500, 'icon': Icons.local_drink},
      {'name': '白波', 'price': 500, 'icon': Icons.local_drink},
      {'name': '日南娘', 'price': 500, 'icon': Icons.local_drink},
      {'name': '三岳', 'price': 500, 'icon': Icons.local_drink},
      {'name': '山猪', 'price': 500, 'icon': Icons.local_drink},
      {'name': '鰐塚', 'price': 500, 'icon': Icons.local_drink},
      {'name': '赤霧島', 'price': 500, 'icon': Icons.local_drink},
      {'name': '幻の露', 'price': 500, 'icon': Icons.local_drink},
      {'name': '田倉', 'price': 500, 'icon': Icons.local_drink},

      // 米焼酎
      {'name': 'よろしく千萬', 'price': 500, 'icon': Icons.local_drink},
      {'name': '山せみ', 'price': 500, 'icon': Icons.local_drink},

      // 黒糖焼酎
      {'name': '朝日', 'price': 500, 'icon': Icons.local_drink},
      {'name': 'まんこい', 'price': 500, 'icon': Icons.local_drink},

      // その他焼酎
      {'name': '鬼火', 'price': 500, 'icon': Icons.local_drink},
      {'name': '黒瀬', 'price': 500, 'icon': Icons.local_drink},
      {'name': 'ちらんtea酎', 'price': 500, 'icon': Icons.local_drink},
      {'name': '鍛高譚', 'price': 500, 'icon': Icons.local_drink},
      {'name': '黒胡麻', 'price': 500, 'icon': Icons.local_drink},
      {'name': '春雨カリー', 'price': 500, 'icon': Icons.local_drink},

      // プレミアム焼酎
      {'name': '神秘の島', 'price': 800, 'icon': Icons.local_drink},
      {'name': '魔王', 'price': 800, 'icon': Icons.local_drink},
      {'name': '村尾', 'price': 800, 'icon': Icons.local_drink},
      {'name': '森伊蔵', 'price': 100, 'icon': Icons.local_drink},
      {'name': '農口', 'price': 1000, 'icon': Icons.local_drink},
      {'name': '十四代乙焼酎', 'price': 1000, 'icon': Icons.local_drink},
    ],

    'ボトル': [
      {'name': '自然麦', 'price': 3800, 'icon': Icons.local_drink},
      {'name': 'よろしく千萬', 'price': 3800, 'icon': Icons.local_drink},
      {'name': '幻の露', 'price': 3800, 'icon': Icons.local_drink},
      {'name': '富乃宝山', 'price': 3800, 'icon': Icons.local_drink},
      {'name': '吉兆宝山', 'price': 3800, 'icon': Icons.local_drink},
      {'name': '明るい農村', 'price': 3800, 'icon': Icons.local_drink},
    ],
    'ソフトドリンク': [
      {'name': 'ウーロン茶', 'price': 350, 'icon': Icons.local_drink},
      {'name': 'オレンジジュース(オレジュー)', 'price': 350, 'icon': Icons.local_drink},
      {'name': '生茶', 'price': 350, 'icon': Icons.local_drink},
      {'name': 'ジンジャーエール', 'price': 350, 'icon': Icons.local_drink},
      {'name': 'コーラ', 'price': 350, 'icon': Icons.local_drink},
      {'name': '午後の紅茶', 'price': 350, 'icon': Icons.local_drink},
      {'name': 'ラムネ', 'price': 400, 'icon': Icons.local_drink},
      {'name': '生グレープフルーツ(なまぐれ)', 'price': 400, 'icon': Icons.local_drink},
      {'name': 'ゆず茶', 'price': 400, 'icon': Icons.local_drink},
      {'name': '自家製はちみつレモン', 'price': 400, 'icon': Icons.local_drink},
      {'name': 'コールドプレスレモネード', 'price': 400, 'icon': Icons.local_drink},
    ],
    // …他サブカテゴリ
  },
  '焼き物': [
    {'name': 'アミレバー', 'price': 180, 'icon': Icons.outdoor_grill},
    {'name': '皮', 'price': 90, 'icon': Icons.outdoor_grill},
    {'name': 'シロコロ', 'price': 200, 'icon': Icons.outdoor_grill},
    {'name': 'つくね', 'price': 250, 'icon': Icons.outdoor_grill},
    {'name': '豚巻きバンネギ(ぶねぎ)', 'price': 280, 'icon': Icons.outdoor_grill},
    {'name': '豚巻きレタス(ぶれた)', 'price': 280, 'icon': Icons.outdoor_grill},
    {'name': '豚巻きトマト(ぶとま)', 'price': 280, 'icon': Icons.outdoor_grill},
    {'name': '豚巻きアスパラ(ぶあす)', 'price': 280, 'icon': Icons.outdoor_grill},
    {'name': 'テッポー', 'price': 90, 'icon': Icons.outdoor_grill},
    {'name': 'ハツ', 'price': 90, 'icon': Icons.outdoor_grill},
    {'name': 'からしハツ', 'price': 180, 'icon': Icons.outdoor_grill},
    {'name': 'ねぎま', 'price': 180, 'icon': Icons.outdoor_grill},
    {'name': 'ぼんじり', 'price': 180, 'icon': Icons.outdoor_grill},
    {'name': '豚カルビ', 'price': 200, 'icon': Icons.outdoor_grill},
    {'name': 'ハツモト', 'price': 180, 'icon': Icons.outdoor_grill},
    {'name': 'せせり', 'price': 180, 'icon': Icons.outdoor_grill},
    {'name': 'ささみ', 'price': 180, 'icon': Icons.outdoor_grill},
    {'name': '手羽先(てば)', 'price': 200, 'icon': Icons.outdoor_grill},
    {'name': 'ぶりぶり丸チョウ(マルチョウ)', 'price': 200, 'icon': Icons.outdoor_grill},
    {'name': 'しいたけ', 'price': 180, 'icon': Icons.outdoor_grill},
    {'name': 'エリンギ', 'price': 180, 'icon': Icons.outdoor_grill},
    {'name': 'ししとう', 'price': 180, 'icon': Icons.outdoor_grill},
    {'name': 'アボカド', 'price': 200, 'icon': Icons.outdoor_grill},
    {'name': 'アスパラ', 'price': 200, 'icon': Icons.outdoor_grill},
    {'name': '厚揚げ', 'price': 200, 'icon': Icons.outdoor_grill},
    {'name': 'マッシュルーム', 'price': 200, 'icon': Icons.outdoor_grill},
    {'name': '銀杏', 'price': 200, 'icon': Icons.outdoor_grill},
    {'name': '皮付き長芋', 'price': 200, 'icon': Icons.outdoor_grill},
    {'name': 'ナス', 'price': 200, 'icon': Icons.outdoor_grill},
    {'name': 'アスパラ', 'price': 200, 'icon': Icons.outdoor_grill},
    {'name': '串5本盛り合わせ(ごほんもり)', 'price': 780, 'icon': Icons.outdoor_grill},
  ],

  '一品料理': [
    {'name': '日替わり煮込み(にこみ)', 'price': 580, 'icon': Icons.restaurant_menu},
    {'name': 'やみつき塩からあげ(からあげ)', 'price': 680, 'icon': Icons.restaurant_menu},
    {'name': 'レッチリ3P(れっちり)', 'price': 650, 'icon': Icons.restaurant_menu},
    {'name': '手羽先素揚げ3P(手羽先素揚げ)', 'price': 500, 'icon': Icons.restaurant_menu},
    {'name': 'フライドポテト', 'price': 480, 'icon': Icons.restaurant_menu},
    {'name': 'チリポテト', 'price': 480, 'icon': Icons.restaurant_menu},
    {'name': '厚焼き玉子プレーン(あつぷれ)', 'price': 480, 'icon': Icons.restaurant_menu},
    {'name': '厚焼き玉子めんたい(あつめん)', 'price': 580, 'icon': Icons.restaurant_menu},
    {'name': '厚焼き玉子チーズ(あつちー)', 'price': 580, 'icon': Icons.restaurant_menu},
    {'name': '厚焼き玉子そぼろ(あつそぼ)', 'price': 580, 'icon': Icons.restaurant_menu},
    {'name': '熟成地鶏の溶岩スモーク(スモーク)', 'price': 980, 'icon': Icons.restaurant_menu},
    {
      'name': '厚切り牛タンの溶岩焼き(ぎゅうたん)',
      'price': 1180,
      'icon': Icons.restaurant_menu,
    },
    {
      'name': '自家製タルタルのチキン南蛮(ちきなん)',
      'price': 780,
      'icon': Icons.restaurant_menu,
    },
    {'name': 'MIXホルモンまぜ刺(MIX)', 'price': 880, 'icon': Icons.restaurant_menu},
    {'name': 'ホタテの刺身', 'price': 680, 'icon': Icons.restaurant_menu},
    {'name': 'ホタテの磯辺焼き(いそべ)', 'price': 280, 'icon': Icons.restaurant_menu},
  ],

  'サラダ': [
    {'name': '新鮮国産野菜のサラダ(こくさら)', 'price': 680, 'icon': Icons.eco},
    {'name': '自家製タルタルとブロッコリーのサラダ(ぶろさら)', 'price': 680, 'icon': Icons.eco},
    {'name': 'ささみとアボカドのサラダ(あぼさら)', 'price': 680, 'icon': Icons.eco},
    {'name': 'オニ玉サラダ(おにたま)', 'price': 580, 'icon': Icons.eco},
    {'name': 'ピリ辛そぼろと豆腐のサラダ(そぼさら)', 'price': 580, 'icon': Icons.eco},
    {'name': '万喜風ゴマサラダ(ごマサラ)', 'price': 680, 'icon': Icons.eco},
  ],

  'おつまみ': [
    {'name': '冷やっこ', 'price': 250, 'icon': Icons.fastfood},
    {'name': 'マキ卵', 'price': 250, 'icon': Icons.fastfood},
    {'name': '冷トマト', 'price': 380, 'icon': Icons.fastfood},
    {'name': 'ガツ刺し', 'price': 380, 'icon': Icons.fastfood},
    {'name': 'ガツポン酢', 'price': 380, 'icon': Icons.fastfood},
    {'name': 'ガツキムチ', 'price': 480, 'icon': Icons.fastfood},
    {'name': '青唐コブクロ(コブクロ)', 'price': 480, 'icon': Icons.fastfood},
    {'name': '女帝てる子のぬか漬け(ぬかづけ)', 'price': 380, 'icon': Icons.fastfood},
    {'name': 'セロリと白菜のゆず漬け(ゆずづけ)', 'price': 380, 'icon': Icons.fastfood},
    {'name': '漬物盛り合わせ(つけもり)', 'price': 480, 'icon': Icons.fastfood},
    {'name': '明太マヨささみ(めんまよ)', 'price': 480, 'icon': Icons.fastfood},
    {'name': 'キムチ', 'price': 300, 'icon': Icons.fastfood},
    {'name': 'チャンジャ', 'price': 480, 'icon': Icons.fastfood},
    {'name': 'くじら刺し', 'price': 780, 'icon': Icons.fastfood},
    {'name': 'バリバリキャベツ', 'price': 280, 'icon': Icons.fastfood},
    {'name': 'バリバリきゅうり', 'price': 280, 'icon': Icons.fastfood},
  ],

  '鍋': [
    {'name': '青春の塩もつ鍋(塩もつ)', 'price': 980, 'icon': Icons.ramen_dining},
    {'name': '情熱の味噌もつ(みそもつ)', 'price': 1280, 'icon': Icons.ramen_dining},
    {'name': '火吹き辛辛もつ鍋(辛もつ)', 'price': 1480, 'icon': Icons.ramen_dining},
    {'name': '青春の塩ちゃんこ鍋(塩ちゃんこ)', 'price': 900, 'icon': Icons.ramen_dining},
    {'name': '情熱の味噌ちゃんこ鍋(みそちゃんこ)', 'price': 1200, 'icon': Icons.ramen_dining},
    {'name': '火吹き辛辛ちゃんこ鍋(からちゃんこ)', 'price': 1400, 'icon': Icons.ramen_dining},
  ],

  'トッピング': [
    {'name': 'トッピングマルチョウ', 'price': 500, 'icon': Icons.add},
    {'name': 'トッピングつくね', 'price': 500, 'icon': Icons.add},
    {'name': 'トッピング鶏肉', 'price': 500, 'icon': Icons.add},
    {'name': 'トッピング豚肉', 'price': 500, 'icon': Icons.add},
    {'name': '野菜セット', 'price': 500, 'icon': Icons.add},
    {'name': 'きのこセット', 'price': 500, 'icon': Icons.add},
    {'name': '追加スープ', 'price': 300, 'icon': Icons.add},
    {'name': '雑炊セット', 'price': 600, 'icon': Icons.add},
    {'name': 'ラーメンセット', 'price': 600, 'icon': Icons.add},
    {'name': 'チーズリゾット', 'price': 700, 'icon': Icons.add},
  ],

  '〆メニュー': [
    {'name': 'そぼろ丼(そぼろ)', 'price': 680, 'icon': Icons.set_meal},
    {'name': 'TKG', 'price': 580, 'icon': Icons.set_meal},
    {'name': '鶏飯', 'price': 800, 'icon': Icons.set_meal},
    {'name': 'キーマカレー(キーマ)', 'price': 880, 'icon': Icons.set_meal},
    {'name': 'チーズキーマカレー(チーキー)', 'price': 950, 'icon': Icons.set_meal},
    {'name': '白湯スープ', 'price': 300, 'icon': Icons.set_meal},
    {'name': '白湯ラーメン', 'price': 800, 'icon': Icons.set_meal},
  ],

  'デザート': [
    {'name': 'ふわとろはちみつチーズ(はちチー)', 'price': 780, 'icon': Icons.icecream},
    {'name': 'バニラアイス', 'price': 280, 'icon': Icons.icecream},
    {'name': 'ハニーバター', 'price': 680, 'icon': Icons.icecream},
    {'name': '大人のアフォガード', 'price': 680, 'icon': Icons.icecream},
  ],

  'その他': [
    {'name': 'ビールセット', 'price': 500, 'icon': Icons.local_bar},
    {
      'name': '【熟成地鶏！漫喫コース】全11品2時間飲み放題付き',
      'price': 4880,
      'icon': Icons.local_bar,
    },
    {'name': '飲み放題2H', 'price': 1800, 'icon': Icons.local_bar},
    {'name': '飲み放題1H延長', 'price': 900, 'icon': Icons.local_bar},
  ],

  'お通し': [
    {'name': 'お通し', 'price': 300, 'icon': Icons.fastfood},
  ],
};

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    // options: DefaultFirebaseOptions.currentPlatform,
  );

  final batch = FirebaseFirestore.instance.batch();
  final col = FirebaseFirestore.instance.collection('menu_items');

  rawData.forEach((topCategory, value) {
    if (value is Map<String, List>) {
      // ドリンク系：大カテゴリ/サブカテゴリ
      value.forEach((subCategory, items) {
        for (var item in items) {
          batch.set(
            col.doc(), // 自動ID
            {
              'name': item['name'],
              'price': item['price'],
              'category': '$topCategory/$subCategory',
            },
          );
        }
      });
    } else if (value is List) {
      // フード系：カテゴリそのまま
      for (var item in value) {
        batch.set(col.doc(), {
          'name': item['name'],
          'price': item['price'],
          'category': topCategory,
        });
      }
    }
  });

  await batch.commit();
  print('✅ 一括インポート完了！');
  exit(0); // スクリプト終了
}
