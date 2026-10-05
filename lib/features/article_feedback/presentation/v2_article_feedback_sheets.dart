import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/utils/localization_helper.dart';
import '../domain/v2_article_feedback.dart';

enum V2ArticleOverflowAction { notInterested, report }

Future<V2ArticleOverflowAction?> showV2ArticleOverflowSheet(
  BuildContext context,
) {
  return showModalBottomSheet<V2ArticleOverflowAction>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const V2ArticleOverflowSheet(),
  );
}

typedef V2ReportSubmit = Future<void> Function(
  V2ReportReason reason,
  String comment,
);

/// Resolves to true when the report was accepted, null when dismissed.
Future<bool?> showV2ReportSheet(
  BuildContext context, {
  required V2ReportSubmit submit,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => V2ReportSheet(submit: submit),
  );
}

String v2ReportReasonLabel(BuildContext context, V2ReportReason reason) {
  return switch (reason) {
    V2ReportReason.offensiveContent =>
      LocalizationHelper.v2FeedbackReasonOffensive(context),
    V2ReportReason.harassmentAbuse =>
      LocalizationHelper.v2FeedbackReasonHarassment(context),
    V2ReportReason.misinformation =>
      LocalizationHelper.v2FeedbackReasonMisinformation(context),
    V2ReportReason.spamMisleading =>
      LocalizationHelper.v2FeedbackReasonSpam(context),
    V2ReportReason.other => LocalizationHelper.v2FeedbackReasonOther(context),
  };
}

/// Rounded surface + grab handle shared by the V2 bottom sheets.
class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Flexible(child: SingleChildScrollView(child: child)),
            ],
          ),
        ),
      ),
    );
  }
}

class V2ArticleOverflowSheet extends StatelessWidget {
  const V2ArticleOverflowSheet({super.key});

  static const notInterestedKey = ValueKey('v2_overflow_not_interested');
  static const reportKey = ValueKey('v2_overflow_report');

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600);
    return _SheetFrame(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: notInterestedKey,
              leading: const Icon(Icons.visibility_off_outlined),
              title: Text(
                LocalizationHelper.v2FeedbackNotInterested(context),
                style: style,
              ),
              onTap: () => Navigator.of(context)
                  .pop(V2ArticleOverflowAction.notInterested),
            ),
            ListTile(
              key: reportKey,
              leading: const Icon(Icons.flag_outlined),
              title: Text(
                LocalizationHelper.v2FeedbackReport(context),
                style: style,
              ),
              onTap: () =>
                  Navigator.of(context).pop(V2ArticleOverflowAction.report),
            ),
          ],
        ),
      ),
    );
  }
}

/// Caps the comment at [V2ReportForm.maxCommentLength] UTF-16 code units
/// without splitting a character.
class V2ReportCommentLengthFormatter extends TextInputFormatter {
  const V2ReportCommentLengthFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    const max = V2ReportForm.maxCommentLength;
    if (newValue.text.length <= max) return newValue;
    if (oldValue.text.length >= max) return oldValue;
    final buffer = StringBuffer();
    for (final char in newValue.text.characters) {
      if (buffer.length + char.length > max) break;
      buffer.write(char);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class V2ReportSheet extends StatefulWidget {
  const V2ReportSheet({super.key, required this.submit});

  static const commentKey = ValueKey('v2_report_comment');
  static const submitKey = ValueKey('v2_report_submit');
  static const errorKey = ValueKey('v2_report_error');

  static ValueKey<String> reasonKey(V2ReportReason reason) =>
      ValueKey('v2_report_reason_${reason.id}');

  final V2ReportSubmit submit;

  @override
  State<V2ReportSheet> createState() => _V2ReportSheetState();
}

class _V2ReportSheetState extends State<V2ReportSheet> {
  final TextEditingController _comment = TextEditingController();
  V2ReportReason? _reason;
  bool _submitting = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _comment.addListener(_onCommentChanged);
  }

  @override
  void dispose() {
    _comment.removeListener(_onCommentChanged);
    _comment.dispose();
    super.dispose();
  }

  void _onCommentChanged() => setState(() {});

  bool get _canSubmit =>
      !_submitting && V2ReportForm.canSubmit(_reason, _comment.text);

  Future<void> _submit() async {
    final reason = _reason;
    if (!_canSubmit || reason == null) return;
    setState(() {
      _submitting = true;
      _failed = false;
    });
    try {
      await widget.submit(
        reason,
        V2ReportForm.normalizeComment(_comment.text),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _failed = true;
      });
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final otherNeedsText = _reason == V2ReportReason.other &&
        !V2ReportForm.isCommentValid(V2ReportReason.other, _comment.text);

    return _SheetFrame(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                LocalizationHelper.v2FeedbackReportTitle(context),
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            const SizedBox(height: 6),
            RadioGroup<V2ReportReason>(
              groupValue: _reason,
              onChanged: (value) {
                if (_submitting || value == null) return;
                setState(() => _reason = value);
              },
              child: Column(
                children: [
                  for (final reason in V2ReportReason.values)
                    RadioListTile<V2ReportReason>(
                      key: V2ReportSheet.reasonKey(reason),
                      value: reason,
                      enabled: !_submitting,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        v2ReportReasonLabel(context, reason),
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: V2ReportSheet.commentKey,
              controller: _comment,
              enabled: !_submitting,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: const [V2ReportCommentLengthFormatter()],
              decoration: InputDecoration(
                labelText: LocalizationHelper.v2FeedbackTellUsMore(context),
                helperText: otherNeedsText
                    ? LocalizationHelper.v2FeedbackOtherRequired(context)
                    : null,
                helperMaxLines: 2,
                counterText:
                    '${_comment.text.length}/${V2ReportForm.maxCommentLength}',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            if (_failed) ...[
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Text(
                  LocalizationHelper.v2FeedbackReportFailed(context),
                  key: V2ReportSheet.errorKey,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            FilledButton(
              key: V2ReportSheet.submitKey,
              onPressed: _canSubmit ? _submit : null,
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      LocalizationHelper.v2FeedbackSubmit(context),
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
