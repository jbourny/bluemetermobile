import 'dart:ui';

class TranslationService {
  static final TranslationService _instance = TranslationService._internal();

  factory TranslationService() {
    return _instance;
  }

  TranslationService._internal();

  // Obtient la langue actuelle du système
  String get currentLanguage => PlatformDispatcher.instance.locale.languageCode;

  // Dictionnaire de traduction
  final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'Unknown': 'Unknown',
      'Stormblade': 'Stormblade',
      'FrostMage': 'Frost Mage',
      'WindKnight': 'Wind Knight',
      'VerdantOracle': 'Verdant Oracle',
      'HeavyGuardian': 'Heavy Guardian',
      'Marksman': 'Marksman',
      'ShieldKnight': 'Shield Knight',
      'SoulMusician': 'Soul Musician',
      'Tank': 'Tank',
      'Heal': 'Healer',
      'DPS': 'DPS',
      'NoData': 'No data',
      'Start': 'Start',
      'Stop': 'Stop',
    },
    'fr': {
      'Unknown': 'Inconnu',
      'Stormblade': 'Lame Tempête',
      'FrostMage': 'Mage de Glace',
      'WindKnight': 'Chevalier du Vent',
      'VerdantOracle': 'Oracle Verdoyant',
      'HeavyGuardian': 'Gardien Lourd',
      'Marksman': 'Tireur d\'élite',
      'ShieldKnight': 'Chevalier Bouclier',
      'SoulMusician': 'Musicien de l\'Âme',
      'Tank': 'Tank',
      'Heal': 'Soigneur',
      'DPS': 'DPS',
      'NoData': 'Pas de données',
      'Start': 'Démarrer',
      'Stop': 'Arrêter',
    },
    'zh': {
      'Unknown': '未知',
      'Stormblade': '雷影剑士',
      'FrostMage': '冰魔导师',
      'WindKnight': '青岚骑士',
      'VerdantOracle': '森语者',
      'HeavyGuardian': '巨刃守护者',
      'Marksman': '神射手',
      'ShieldKnight': '神盾骑士',
      'SoulMusician': '灵魂乐手',
      'Tank': '坦克',
      'Heal': '治疗',
      'DPS': '输出',
      'NoData': '无数据',
      'Start': '开始',
      'Stop': '停止',
    },
    'de': {
      'Unknown': 'Unbekannt',
      'Stormblade': 'Sturmklinge',
      'FrostMage': 'Frostmagier',
      'WindKnight': 'Windritter',
      'VerdantOracle': 'Waldorakel',
      'HeavyGuardian': 'Schwerer Wächter',
      'Marksman': 'Scharfschütze',
      'ShieldKnight': 'Schildritter',
      'SoulMusician': 'Seelenmusiker',
      'Tank': 'Tank',
      'Heal': 'Heiler',
      'DPS': 'DPS',
      'NoData': 'Keine Daten',
      'Start': 'Starten',
      'Stop': 'Stoppen',
    },
    'ru': {
      'Unknown': 'Неизвестно',
      'Stormblade': 'Клинок Бури',
      'FrostMage': 'Маг Льда',
      'WindKnight': 'Рыцарь Ветра',
      'VerdantOracle': 'Лесной Оракул',
      'HeavyGuardian': 'Тяжелый Страж',
      'Marksman': 'Стрелок',
      'ShieldKnight': 'Рыцарь Щита',
      'SoulMusician': 'Музыкант Души',
      'Tank': 'Танк',
      'Heal': 'Лекарь',
      'DPS': 'Урон',
      'NoData': 'Нет данных',
      'Start': 'Старт',
      'Stop': 'Стоп',
    },
    'uk': {
      'Unknown': 'Невідомо',
      'Stormblade': 'Клинок Бурі',
      'FrostMage': 'Маг Льоду',
      'WindKnight': 'Лицар Вітру',
      'VerdantOracle': 'Лісовий Оракул',
      'HeavyGuardian': 'Важкий Вартовий',
      'Marksman': 'Стрілець',
      'ShieldKnight': 'Лицар Щита',
      'SoulMusician': 'Музикант Душі',
      'Tank': 'Танк',
      'Heal': 'Лікар',
      'DPS': 'ДПС',
      'NoData': 'Немає даних',
      'Start': 'Старт',
      'Stop': 'Стоп',
    },
  };

  String translate(String key) {
    // Essaie de trouver la traduction dans la langue actuelle
    if (_localizedValues.containsKey(currentLanguage) &&
        _localizedValues[currentLanguage]!.containsKey(key)) {
      return _localizedValues[currentLanguage]![key]!;
    }
    
    // Fallback sur l'anglais
    if (_localizedValues['en']!.containsKey(key)) {
      return _localizedValues['en']![key]!;
    }

    // Retourne la clé si aucune traduction n'est trouvée
    return key;
  }
}
