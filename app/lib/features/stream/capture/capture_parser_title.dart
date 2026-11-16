part of 'capture_parser.dart';

String _buildTitle(_ParseState s) {
  final buf = StringBuffer();
  for (var i = 0; i < s.tokens.length; i++) {
    if (s.used[i]) continue;
    if (buf.isNotEmpty) buf.write(' ');
    buf.write(s.tokens[i].text);
  }
  return buf.toString().replaceAll(_wsRe, ' ').trim();
}
