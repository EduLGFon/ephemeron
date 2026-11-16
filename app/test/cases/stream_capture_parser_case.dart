import 'package:ephemeron/features/stream/capture/capture_parser.dart';
import 'package:ephemeron/features/stream/capture/capture_kind.dart';
import 'package:ephemeron/features/stream/capture/capture_priority.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 16, 9, 0);

  final cases = <Map<String, dynamic>>[
    // English basics
    {
      'input': 'call dentist tomorrow 3pm',
      'locale': CaptureLocale.en,
      'kind': CaptureKind.task,
      'title': 'call dentist',
    },
    {
      'input': 'meeting with Ana 14:00-15:00 #work !high',
      'locale': CaptureLocale.en,
      'kind': CaptureKind.event,
      'title': 'meeting with Ana',
      'tag': 'work',
      'prio': CapturePriority.high,
    },
    {
      'input': 'gym every mon wed fri 7am',
      'locale': CaptureLocale.en,
      'kind': CaptureKind.habit,
      'title': 'gym',
    },
    {
      'input': 'exam 12 dec',
      'locale': CaptureLocale.en,
      'kind': CaptureKind.task,
      'title': 'exam',
    },
    {
      'input': 'lunch today 12:30',
      'locale': CaptureLocale.en,
      'kind': CaptureKind.task,
      'title': 'lunch',
    },
    {
      'input': 'call mom 3 pm',
      'locale': CaptureLocale.en,
      'kind': CaptureKind.task,
      'title': 'call mom',
    },
    {
      'input': 'standup daily 9am',
      'locale': CaptureLocale.en,
      'kind': CaptureKind.habit,
      'title': 'standup',
    },
    {
      'input': 'party 20 dec 18:00-22:00',
      'locale': CaptureLocale.en,
      'kind': CaptureKind.event,
      'title': 'party',
    },
    {
      'input': 'deadline 12 dec #work !low',
      'locale': CaptureLocale.en,
      'kind': CaptureKind.task,
      'title': 'deadline',
      'tag': 'work',
      'prio': CapturePriority.low,
    },
    {
      'input': 'countdown until 25 dec',
      'locale': CaptureLocale.en,
      'kind': CaptureKind.countdown,
      'title': '',
    },
    {
      'input': 'trip in 3 days',
      'locale': CaptureLocale.en,
      'kind': CaptureKind.task,
      'title': 'trip',
    },
    {
      'input': 'reminder in 2 hours',
      'locale': CaptureLocale.en,
      'kind': CaptureKind.task,
      'title': 'reminder',
    },
    {
      'input': 'next monday review',
      'locale': CaptureLocale.en,
      'kind': CaptureKind.task,
      'title': 'review',
    },
    {
      'input': 'focus 15h30',
      'locale': CaptureLocale.en,
      'kind': CaptureKind.task,
      'title': 'focus',
    },
    {
      'input': 'read 7h',
      'locale': CaptureLocale.en,
      'kind': CaptureKind.task,
      'title': 'read',
    },
    {
      'input': 'workout every day 6am',
      'locale': CaptureLocale.en,
      'kind': CaptureKind.habit,
      'title': 'workout',
    },
    {
      'input': 't buy milk',
      'locale': CaptureLocale.en,
      'kind': CaptureKind.task,
      'title': 'buy milk',
    },
    {
      'input': 'e sync 10:00-10:30',
      'locale': CaptureLocale.en,
      'kind': CaptureKind.event,
      'title': 'sync',
    },
    {
      'input': 'h water daily',
      'locale': CaptureLocale.en,
      'kind': CaptureKind.habit,
      'title': 'water',
    },
    {
      'input': 'c new year 1 jan',
      'locale': CaptureLocale.en,
      'kind': CaptureKind.countdown,
      'title': 'new year',
    },
    {
      'input': 'unknown xyz',
      'locale': CaptureLocale.en,
      'kind': CaptureKind.task,
      'title': 'unknown xyz',
    },
    {
      'input': 'meeting 14:00-15:00 #work',
      'locale': CaptureLocale.en,
      'kind': CaptureKind.event,
      'title': 'meeting',
      'tag': 'work',
    },
    {
      'input': 'run 7am #health !medium',
      'locale': CaptureLocale.en,
      'kind': CaptureKind.task,
      'title': 'run',
      'tag': 'health',
      'prio': CapturePriority.medium,
    },
    {
      'input': 'exam 12 december',
      'locale': CaptureLocale.en,
      'kind': CaptureKind.task,
      'title': 'exam',
    },
    {
      'input': 'call 3pm-4pm',
      'locale': CaptureLocale.en,
      'kind': CaptureKind.event,
      'title': 'call',
    },
    {
      'input': 'report due 5 jan',
      'locale': CaptureLocale.en,
      'kind': CaptureKind.task,
      'title': 'report due',
    },
    {
      'input': 'gym mon wed fri',
      'locale': CaptureLocale.en,
      'kind': CaptureKind.task,
      'title': 'gym',
    },
    {
      'input': 'gym every mon',
      'locale': CaptureLocale.en,
      'kind': CaptureKind.habit,
      'title': 'gym',
    },
    {
      'input': 'standup every day',
      'locale': CaptureLocale.en,
      'kind': CaptureKind.habit,
      'title': 'standup',
    },
    {
      'input': 'party tomorrow',
      'locale': CaptureLocale.en,
      'kind': CaptureKind.task,
      'title': 'party',
    },
    // Portuguese
    {
      'input': 'dentista amanhã 15h',
      'locale': CaptureLocale.pt,
      'kind': CaptureKind.task,
      'title': 'dentista',
    },
    {
      'input': 'reunião 14:00-15:00 #trabalho !alta',
      'locale': CaptureLocale.pt,
      'kind': CaptureKind.event,
      'title': 'reunião',
      'tag': 'trabalho',
      'prio': CapturePriority.high,
    },
    {
      'input': 'academia toda seg qua sex 7h',
      'locale': CaptureLocale.pt,
      'kind': CaptureKind.habit,
      'title': 'academia',
    },
    {
      'input': 'prova 12 dez',
      'locale': CaptureLocale.pt,
      'kind': CaptureKind.task,
      'title': 'prova',
    },
    {
      'input': 'almoço hoje 12:30',
      'locale': CaptureLocale.pt,
      'kind': CaptureKind.task,
      'title': 'almoço',
    },
    {
      'input': 'ligar mãe 3 pm',
      'locale': CaptureLocale.pt,
      'kind': CaptureKind.task,
      'title': 'ligar mãe',
    },
    {
      'input': 'reunião diariamente 9h',
      'locale': CaptureLocale.pt,
      'kind': CaptureKind.habit,
      'title': 'reunião',
    },
    {
      'input': 'festa 20 dez 18:00-22:00',
      'locale': CaptureLocale.pt,
      'kind': CaptureKind.event,
      'title': 'festa',
    },
    {
      'input': 'prazo 12 dez #trabalho !baixa',
      'locale': CaptureLocale.pt,
      'kind': CaptureKind.task,
      'title': 'prazo',
      'tag': 'trabalho',
      'prio': CapturePriority.low,
    },
    {
      'input': 'contagem até 25 dez',
      'locale': CaptureLocale.pt,
      'kind': CaptureKind.countdown,
      'title': '',
    },
    {
      'input': 'viagem em 3 dias',
      'locale': CaptureLocale.pt,
      'kind': CaptureKind.task,
      'title': 'viagem',
    },
    {
      'input': 'lembrete em 2 horas',
      'locale': CaptureLocale.pt,
      'kind': CaptureKind.task,
      'title': 'lembrete',
    },
    {
      'input': 'próxima segunda revisão',
      'locale': CaptureLocale.pt,
      'kind': CaptureKind.task,
      'title': 'revisão',
    },
    {
      'input': 'foco 15h30',
      'locale': CaptureLocale.pt,
      'kind': CaptureKind.task,
      'title': 'foco',
    },
    {
      'input': 'ler 7h',
      'locale': CaptureLocale.pt,
      'kind': CaptureKind.task,
      'title': 'ler',
    },
    {
      'input': 'treino todo dia 6h',
      'locale': CaptureLocale.pt,
      'kind': CaptureKind.habit,
      'title': 'treino',
    },
    {
      'input': 't comprar leite',
      'locale': CaptureLocale.pt,
      'kind': CaptureKind.task,
      'title': 'comprar leite',
    },
    {
      'input': 'e sync 10:00-10:30',
      'locale': CaptureLocale.pt,
      'kind': CaptureKind.event,
      'title': 'sync',
    },
    {
      'input': 'h água diariamente',
      'locale': CaptureLocale.pt,
      'kind': CaptureKind.habit,
      'title': 'água',
    },
    {
      'input': 'c ano novo 1 jan',
      'locale': CaptureLocale.pt,
      'kind': CaptureKind.countdown,
      'title': 'ano novo',
    },
    {
      'input': 'desconhecido xyz',
      'locale': CaptureLocale.pt,
      'kind': CaptureKind.task,
      'title': 'desconhecido xyz',
    },
    {
      'input': 'reunião 14:00-15:00 #trabalho',
      'locale': CaptureLocale.pt,
      'kind': CaptureKind.event,
      'title': 'reunião',
      'tag': 'trabalho',
    },
    {
      'input': 'corrida 7h #saude !media',
      'locale': CaptureLocale.pt,
      'kind': CaptureKind.task,
      'title': 'corrida',
      'tag': 'saude',
      'prio': CapturePriority.medium,
    },
    {
      'input': 'prova 12 dezembro',
      'locale': CaptureLocale.pt,
      'kind': CaptureKind.task,
      'title': 'prova',
    },
    {
      'input': 'ligar 3pm-4pm',
      'locale': CaptureLocale.pt,
      'kind': CaptureKind.event,
      'title': 'ligar',
    },
    {
      'input': 'relatório 5 jan',
      'locale': CaptureLocale.pt,
      'kind': CaptureKind.task,
      'title': 'relatório',
    },
    {
      'input': 'academia seg qua sex',
      'locale': CaptureLocale.pt,
      'kind': CaptureKind.task,
      'title': 'academia',
    },
    {
      'input': 'academia toda seg',
      'locale': CaptureLocale.pt,
      'kind': CaptureKind.habit,
      'title': 'academia',
    },
    {
      'input': 'reunião todo dia',
      'locale': CaptureLocale.pt,
      'kind': CaptureKind.habit,
      'title': 'reunião',
    },
    {
      'input': 'festa amanhã',
      'locale': CaptureLocale.pt,
      'kind': CaptureKind.task,
      'title': 'festa',
    },
  ];

  for (var i = 0; i < cases.length; i++) {
    final c = cases[i];
    test('capture case $i', () {
      final r = parseCapture(
        c['input'] as String,
        locale: c['locale'] as CaptureLocale,
        now: now,
      );
      expect(r.kind, c['kind'], reason: c['input'] as String);
      expect(r.title, c['title'], reason: c['input'] as String);
      if (c.containsKey('tag'))
        expect(r.listTag, c['tag'], reason: c['input'] as String);
      if (c.containsKey('prio'))
        expect(r.priority, c['prio'], reason: c['input'] as String);
    });
  }

  test('clock injection changes date', () {
    final r1 = parseCapture(
      'exam 12 dec',
      locale: CaptureLocale.en,
      now: DateTime(2026, 11, 16),
    );
    final r2 = parseCapture(
      'exam 12 dec',
      locale: CaptureLocale.en,
      now: DateTime(2027, 1, 1),
    );
    expect(r1.date, DateTime(2026, 12, 12));
    expect(r2.date, DateTime(2027, 12, 12));
  });

  test('clock function works', () {
    final r = parseCapture(
      'exam 12 dec',
      locale: CaptureLocale.en,
      clock: () => DateTime(2026, 11, 16),
    );
    expect(r.date, DateTime(2026, 12, 12));
  });

  test('spans have offsets', () {
    final r = parseCapture(
      'meeting 14:00-15:00 #work',
      locale: CaptureLocale.en,
      now: now,
    );
    expect(r.spans.isNotEmpty, true);
    for (final s in r.spans) {
      expect(s.end > s.start, true);
    }
  });
}
