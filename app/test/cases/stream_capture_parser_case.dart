import 'package:ephemeron/features/stream/capture/capture_parser.dart';
import 'package:ephemeron/features/stream/capture/capture_kind.dart';
import 'package:ephemeron/features/stream/capture/capture_priority.dart';
import 'package:ephemeron/features/stream/capture/capture_repeat.dart';
import 'package:ephemeron/features/stream/capture/capture_span.dart';
import 'package:flutter_test/flutter_test.dart';

// ignore_for_file: unused_element_parameter

class _Case {
  const _Case({
    required this.input,
    required this.locale,
    required this.kind,
    required this.title,
    this.tag,
    this.prio,
    this.date,
    this.startTime,
    this.endTime,
    this.repeat,
    this.spans,
    this.spanTexts,
  });

  final String input;
  final CaptureLocale locale;
  final CaptureKind kind;
  final String title;
  final String? tag;
  final CapturePriority? prio;
  final DateTime? date;
  final DateTime? startTime;
  final DateTime? endTime;
  final CaptureRepeat? repeat;
  final List<CaptureSpan>? spans;
  final List<String>? spanTexts;
}

void main() {
  final now = DateTime(2026, 11, 16, 9, 0);

  final cases = <_Case>[
    _Case(
      input: 'call dentist tomorrow 3pm',
      locale: CaptureLocale.en,
      kind: CaptureKind.task,
      title: 'call dentist',
    ),
    _Case(
      input: 'meeting with Ana 14:00-15:00 #work !high',
      locale: CaptureLocale.en,
      kind: CaptureKind.event,
      title: 'meeting with Ana',
      tag: 'work',
      prio: CapturePriority.high,
    ),
    _Case(
      input: 'gym every mon wed fri 7am',
      locale: CaptureLocale.en,
      kind: CaptureKind.habit,
      title: 'gym',
    ),
    _Case(
      input: 'exam 12 dec',
      locale: CaptureLocale.en,
      kind: CaptureKind.task,
      title: 'exam',
    ),
    _Case(
      input: 'lunch today 12:30',
      locale: CaptureLocale.en,
      kind: CaptureKind.task,
      title: 'lunch',
    ),
    _Case(
      input: 'call mom 3 pm',
      locale: CaptureLocale.en,
      kind: CaptureKind.task,
      title: 'call mom',
    ),
    _Case(
      input: 'standup daily 9am',
      locale: CaptureLocale.en,
      kind: CaptureKind.habit,
      title: 'standup',
    ),
    _Case(
      input: 'party 20 dec 18:00-22:00',
      locale: CaptureLocale.en,
      kind: CaptureKind.event,
      title: 'party',
    ),
    _Case(
      input: 'deadline 12 dec #work !low',
      locale: CaptureLocale.en,
      kind: CaptureKind.task,
      title: 'deadline',
      tag: 'work',
      prio: CapturePriority.low,
    ),
    _Case(
      input: 'countdown until 25 dec',
      locale: CaptureLocale.en,
      kind: CaptureKind.countdown,
      title: '',
    ),
    _Case(
      input: 'trip in 3 days',
      locale: CaptureLocale.en,
      kind: CaptureKind.task,
      title: 'trip',
    ),
    _Case(
      input: 'reminder in 2 hours',
      locale: CaptureLocale.en,
      kind: CaptureKind.task,
      title: 'reminder',
    ),
    _Case(
      input: 'next monday review',
      locale: CaptureLocale.en,
      kind: CaptureKind.task,
      title: 'review',
    ),
    _Case(
      input: 'focus 15h30',
      locale: CaptureLocale.en,
      kind: CaptureKind.task,
      title: 'focus',
    ),
    _Case(
      input: 'read 7h',
      locale: CaptureLocale.en,
      kind: CaptureKind.task,
      title: 'read',
    ),
    _Case(
      input: 'workout every day 6am',
      locale: CaptureLocale.en,
      kind: CaptureKind.habit,
      title: 'workout',
    ),
    _Case(
      input: 't buy milk',
      locale: CaptureLocale.en,
      kind: CaptureKind.task,
      title: 'buy milk',
    ),
    _Case(
      input: 'e sync 10:00-10:30',
      locale: CaptureLocale.en,
      kind: CaptureKind.event,
      title: 'sync',
    ),
    _Case(
      input: 'h water daily',
      locale: CaptureLocale.en,
      kind: CaptureKind.habit,
      title: 'water',
    ),
    _Case(
      input: 'c new year 1 jan',
      locale: CaptureLocale.en,
      kind: CaptureKind.countdown,
      title: 'new year',
    ),
    _Case(
      input: 'unknown xyz',
      locale: CaptureLocale.en,
      kind: CaptureKind.task,
      title: 'unknown xyz',
    ),
    _Case(
      input: 'meeting 14:00-15:00 #work',
      locale: CaptureLocale.en,
      kind: CaptureKind.event,
      title: 'meeting',
      tag: 'work',
    ),
    _Case(
      input: 'run 7am #health !medium',
      locale: CaptureLocale.en,
      kind: CaptureKind.task,
      title: 'run',
      tag: 'health',
      prio: CapturePriority.medium,
    ),
    _Case(
      input: 'exam 12 december',
      locale: CaptureLocale.en,
      kind: CaptureKind.task,
      title: 'exam',
    ),
    _Case(
      input: 'call 3pm-4pm',
      locale: CaptureLocale.en,
      kind: CaptureKind.event,
      title: 'call',
    ),
    _Case(
      input: 'report due 5 jan',
      locale: CaptureLocale.en,
      kind: CaptureKind.task,
      title: 'report due',
    ),
    _Case(
      input: 'gym mon wed fri',
      locale: CaptureLocale.en,
      kind: CaptureKind.task,
      title: 'gym',
    ),
    _Case(
      input: 'gym every mon',
      locale: CaptureLocale.en,
      kind: CaptureKind.habit,
      title: 'gym',
    ),
    _Case(
      input: 'standup every day',
      locale: CaptureLocale.en,
      kind: CaptureKind.habit,
      title: 'standup',
    ),
    _Case(
      input: 'party tomorrow',
      locale: CaptureLocale.en,
      kind: CaptureKind.task,
      title: 'party',
    ),
    _Case(
      input: 'dentista amanhã 15h',
      locale: CaptureLocale.pt,
      kind: CaptureKind.task,
      title: 'dentista',
    ),
    _Case(
      input: 'reunião 14:00-15:00 #trabalho !alta',
      locale: CaptureLocale.pt,
      kind: CaptureKind.event,
      title: 'reunião',
      tag: 'trabalho',
      prio: CapturePriority.high,
    ),
    _Case(
      input: 'academia toda seg qua sex 7h',
      locale: CaptureLocale.pt,
      kind: CaptureKind.habit,
      title: 'academia',
    ),
    _Case(
      input: 'prova 12 dez',
      locale: CaptureLocale.pt,
      kind: CaptureKind.task,
      title: 'prova',
    ),
    _Case(
      input: 'almoço hoje 12:30',
      locale: CaptureLocale.pt,
      kind: CaptureKind.task,
      title: 'almoço',
    ),
    _Case(
      input: 'ligar mãe 3 pm',
      locale: CaptureLocale.pt,
      kind: CaptureKind.task,
      title: 'ligar mãe',
    ),
    _Case(
      input: 'reunião diariamente 9h',
      locale: CaptureLocale.pt,
      kind: CaptureKind.habit,
      title: 'reunião',
    ),
    _Case(
      input: 'festa 20 dez 18:00-22:00',
      locale: CaptureLocale.pt,
      kind: CaptureKind.event,
      title: 'festa',
    ),
    _Case(
      input: 'prazo 12 dez #trabalho !baixa',
      locale: CaptureLocale.pt,
      kind: CaptureKind.task,
      title: 'prazo',
      tag: 'trabalho',
      prio: CapturePriority.low,
    ),
    _Case(
      input: 'contagem até 25 dez',
      locale: CaptureLocale.pt,
      kind: CaptureKind.countdown,
      title: '',
    ),
    _Case(
      input: 'viagem em 3 dias',
      locale: CaptureLocale.pt,
      kind: CaptureKind.task,
      title: 'viagem',
    ),
    _Case(
      input: 'lembrete em 2 horas',
      locale: CaptureLocale.pt,
      kind: CaptureKind.task,
      title: 'lembrete',
    ),
    _Case(
      input: 'próxima segunda revisão',
      locale: CaptureLocale.pt,
      kind: CaptureKind.task,
      title: 'revisão',
    ),
    _Case(
      input: 'foco 15h30',
      locale: CaptureLocale.pt,
      kind: CaptureKind.task,
      title: 'foco',
    ),
    _Case(
      input: 'ler 7h',
      locale: CaptureLocale.pt,
      kind: CaptureKind.task,
      title: 'ler',
    ),
    _Case(
      input: 'treino todo dia 6h',
      locale: CaptureLocale.pt,
      kind: CaptureKind.habit,
      title: 'treino',
    ),
    _Case(
      input: 't comprar leite',
      locale: CaptureLocale.pt,
      kind: CaptureKind.task,
      title: 'comprar leite',
    ),
    _Case(
      input: 'e sync 10:00-10:30',
      locale: CaptureLocale.pt,
      kind: CaptureKind.event,
      title: 'sync',
    ),
    _Case(
      input: 'h água diariamente',
      locale: CaptureLocale.pt,
      kind: CaptureKind.habit,
      title: 'água',
    ),
    _Case(
      input: 'c ano novo 1 jan',
      locale: CaptureLocale.pt,
      kind: CaptureKind.countdown,
      title: 'ano novo',
    ),
    _Case(
      input: 'desconhecido xyz',
      locale: CaptureLocale.pt,
      kind: CaptureKind.task,
      title: 'desconhecido xyz',
    ),
    _Case(
      input: 'reunião 14:00-15:00 #trabalho',
      locale: CaptureLocale.pt,
      kind: CaptureKind.event,
      title: 'reunião',
      tag: 'trabalho',
    ),
    _Case(
      input: 'corrida 7h #saude !media',
      locale: CaptureLocale.pt,
      kind: CaptureKind.task,
      title: 'corrida',
      tag: 'saude',
      prio: CapturePriority.medium,
    ),
    _Case(
      input: 'prova 12 dezembro',
      locale: CaptureLocale.pt,
      kind: CaptureKind.task,
      title: 'prova',
    ),
    _Case(
      input: 'ligar 3pm-4pm',
      locale: CaptureLocale.pt,
      kind: CaptureKind.event,
      title: 'ligar',
    ),
    _Case(
      input: 'relatório 5 jan',
      locale: CaptureLocale.pt,
      kind: CaptureKind.task,
      title: 'relatório',
    ),
    _Case(
      input: 'academia seg qua sex',
      locale: CaptureLocale.pt,
      kind: CaptureKind.task,
      title: 'academia',
    ),
    _Case(
      input: 'academia toda seg',
      locale: CaptureLocale.pt,
      kind: CaptureKind.habit,
      title: 'academia',
    ),
    _Case(
      input: 'reunião todo dia',
      locale: CaptureLocale.pt,
      kind: CaptureKind.habit,
      title: 'reunião',
    ),
    _Case(
      input: 'festa amanhã',
      locale: CaptureLocale.pt,
      kind: CaptureKind.task,
      title: 'festa',
    ),
  ];

  for (var i = 0; i < cases.length; i++) {
    final c = cases[i];
    test('capture case $i', () {
      final r = parseCapture(c.input, locale: c.locale, now: now);
      expect(r.kind, c.kind, reason: c.input);
      expect(r.title, c.title, reason: c.input);
      if (c.tag != null) {
        expect(r.listTag, c.tag, reason: c.input);
      }
      if (c.prio != null) {
        expect(r.priority, c.prio, reason: c.input);
      }
      if (c.date != null) {
        expect(r.date, c.date, reason: c.input);
      }
      if (c.startTime != null) {
        expect(r.startTime, c.startTime, reason: c.input);
      }
      if (c.endTime != null) {
        expect(r.endTime, c.endTime, reason: c.input);
      }
      if (c.repeat != null) {
        expect(r.repeat, c.repeat, reason: c.input);
      }
      if (c.spans != null) {
        expect(r.spans, c.spans, reason: c.input);
      }
      if (c.spanTexts != null) {
        final texts = r.spans
            .map((s) => c.input.substring(s.start, s.end))
            .toList();
        expect(texts, c.spanTexts, reason: c.input);
      }
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
      now: DateTime(2026, 11, 16),
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

  test('unknown priority stays in title', () {
    final r = parseCapture(
      'buy milk #unknown !urgent',
      locale: CaptureLocale.en,
      now: now,
    );
    expect(r.title, 'buy milk !urgent');
    expect(r.listTag, 'unknown');
    expect(r.priority, CapturePriority.none);
  });

  test('later tags stay in title', () {
    final r = parseCapture(
      'buy stuff #work #home',
      locale: CaptureLocale.en,
      now: now,
    );
    expect(r.listTag, 'work');
    expect(r.title, 'buy stuff #home');
  });

  test('invalid day-month not consumed', () {
    final r = parseCapture('exam 31 feb', locale: CaptureLocale.en, now: now);
    expect(r.title, 'exam 31 feb');
    expect(r.date, isNull);
  });

  test('overnight range keeps end next day', () {
    final r = parseCapture(
      'meeting 22:00-02:00',
      locale: CaptureLocale.en,
      now: now,
    );
    expect(r.startTime, DateTime(2026, 11, 16, 22, 0));
    expect(r.endTime, DateTime(2026, 11, 17, 2, 0));
  });

  test('repeated repeat rule stays in title', () {
    final r = parseCapture(
      'every mon every wed gym',
      locale: CaptureLocale.en,
      now: now,
    );
    expect(
      r.repeat,
      const CaptureRepeat(
        frequency: CaptureRepeatFrequency.weekly,
        weekdays: <int>[DateTime.monday],
      ),
    );
    expect(r.title, 'every wed gym');
    expect(r.kind, CaptureKind.habit);
  });

  test('repeated date stays in title', () {
    final r = parseCapture(
      'exam 12 dec 5 jan',
      locale: CaptureLocale.en,
      now: now,
    );
    expect(r.date, DateTime(2026, 12, 12));
    expect(r.title, 'exam 5 jan');
  });

  test('spans sorted by start offset', () {
    final r = parseCapture(
      'meeting 14:00-15:00 #work !high',
      locale: CaptureLocale.en,
      now: now,
    );
    for (var i = 1; i < r.spans.length; i++) {
      expect(r.spans[i].start >= r.spans[i - 1].start, true);
    }
  });
}
