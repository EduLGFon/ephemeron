// Locale-specific vocabulary for the capture parser. Pure Dart, no Flutter.
import 'capture_priority.dart';

enum CaptureLocale { en, pt }

const Map<CaptureLocale, Set<String>> todayWords = {
  CaptureLocale.en: {'today'},
  CaptureLocale.pt: {'hoje'},
};

const Map<CaptureLocale, Set<String>> tomorrowWords = {
  CaptureLocale.en: {'tomorrow'},
  CaptureLocale.pt: {'amanha', 'amanhã'},
};

const Map<CaptureLocale, Set<String>> nextWords = {
  CaptureLocale.en: {'next'},
  CaptureLocale.pt: {'proximo', 'próximo', 'proxima', 'próxima'},
};

const Map<CaptureLocale, Set<String>> inWords = {
  CaptureLocale.en: {'in'},
  CaptureLocale.pt: {'em'},
};

const Map<CaptureLocale, Set<String>> dayWords = {
  CaptureLocale.en: {'day', 'days'},
  CaptureLocale.pt: {'dia', 'dias'},
};

const Map<CaptureLocale, Set<String>> hourWords = {
  CaptureLocale.en: {'hour', 'hours'},
  CaptureLocale.pt: {'hora', 'horas'},
};

const Map<CaptureLocale, Set<String>> countdownWords = {
  CaptureLocale.en: {'countdown', 'until'},
  CaptureLocale.pt: {'contagem', 'ate', 'até'},
};

const Map<CaptureLocale, Set<String>> repeatStartWords = {
  CaptureLocale.en: {'every'},
  CaptureLocale.pt: {'toda', 'todo'},
};

const Map<CaptureLocale, Set<String>> dailyWords = {
  CaptureLocale.en: {'daily'},
  CaptureLocale.pt: {'diariamente'},
};

const Map<CaptureLocale, Map<String, int>> weekdays = {
  CaptureLocale.en: {
    'mon': DateTime.monday,
    'monday': DateTime.monday,
    'tue': DateTime.tuesday,
    'tuesday': DateTime.tuesday,
    'wed': DateTime.wednesday,
    'wednesday': DateTime.wednesday,
    'thu': DateTime.thursday,
    'thursday': DateTime.thursday,
    'fri': DateTime.friday,
    'friday': DateTime.friday,
    'sat': DateTime.saturday,
    'saturday': DateTime.saturday,
    'sun': DateTime.sunday,
    'sunday': DateTime.sunday,
  },
  CaptureLocale.pt: {
    'seg': DateTime.monday,
    'segunda': DateTime.monday,
    'ter': DateTime.tuesday,
    'terca': DateTime.tuesday,
    'terça': DateTime.tuesday,
    'qua': DateTime.wednesday,
    'quarta': DateTime.wednesday,
    'qui': DateTime.thursday,
    'quinta': DateTime.thursday,
    'sex': DateTime.friday,
    'sexta': DateTime.friday,
    'sab': DateTime.saturday,
    'sabado': DateTime.saturday,
    'sábado': DateTime.saturday,
    'dom': DateTime.sunday,
    'domingo': DateTime.sunday,
  },
};

const Map<CaptureLocale, Map<String, int>> months = {
  CaptureLocale.en: {
    'jan': 1,
    'january': 1,
    'feb': 2,
    'february': 2,
    'mar': 3,
    'march': 3,
    'apr': 4,
    'april': 4,
    'may': 5,
    'jun': 6,
    'june': 6,
    'jul': 7,
    'july': 7,
    'aug': 8,
    'august': 8,
    'sep': 9,
    'september': 9,
    'oct': 10,
    'october': 10,
    'nov': 11,
    'november': 11,
    'dec': 12,
    'december': 12,
  },
  CaptureLocale.pt: {
    'jan': 1,
    'janeiro': 1,
    'fev': 2,
    'fevereiro': 2,
    'mar': 3,
    'marco': 3,
    'março': 3,
    'abr': 4,
    'abril': 4,
    'mai': 5,
    'maio': 5,
    'jun': 6,
    'junho': 6,
    'jul': 7,
    'julho': 7,
    'ago': 8,
    'agosto': 8,
    'set': 9,
    'setembro': 9,
    'out': 10,
    'outubro': 10,
    'nov': 11,
    'novembro': 11,
    'dez': 12,
    'dezembro': 12,
  },
};

const Map<String, CapturePriority> priorityWords = {
  'high': CapturePriority.high,
  'alta': CapturePriority.high,
  'medium': CapturePriority.medium,
  'media': CapturePriority.medium,
  'média': CapturePriority.medium,
  'low': CapturePriority.low,
  'baixa': CapturePriority.low,
};

// Re-export kind/repeat/span via parser; locale lives here.
