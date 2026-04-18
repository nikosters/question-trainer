import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

class FormulaText extends StatelessWidget {
  const FormulaText(this.text, {this.style, super.key});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final inline = _toInlineSpans(
      text,
      baseStyle: style ?? Theme.of(context).textTheme.bodyLarge,
    );

    return Text.rich(
      TextSpan(
        style: style ?? Theme.of(context).textTheme.bodyLarge,
        children: inline,
      ),
    );
  }

  List<InlineSpan> _toInlineSpans(String input, {TextStyle? baseStyle}) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'\$(.+?)\$', dotAll: true);

    int lastEnd = 0;
    for (final match in regex.allMatches(input)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: input.substring(lastEnd, match.start)));
      }

      final latex = match.group(1);
      if (latex != null && latex.trim().isNotEmpty) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Math.tex(
              latex,
              textStyle: baseStyle,
              onErrorFallback: (error) => Text(error.message, style: baseStyle),
            ),
          ),
        );
      }

      lastEnd = match.end;
    }

    if (lastEnd < input.length) {
      spans.add(TextSpan(text: input.substring(lastEnd)));
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: input));
    }

    return spans;
  }
}
