import 'package:flutter/material.dart';
import '../models/city_study.dart';
import '../providers/city_ai_prompts.dart';

class SectionEditorCard extends StatefulWidget {
  final CityStudySection section;
  final CityAISectionInfo info;
  final bool isLoading;
  final VoidCallback? onAiGenerate;
  final ValueChanged<String> onContentChanged;

  const SectionEditorCard({
    super.key,
    required this.section,
    required this.info,
    this.isLoading = false,
    this.onAiGenerate,
    required this.onContentChanged,
  });

  @override
  State<SectionEditorCard> createState() => _SectionEditorCardState();
}

class _SectionEditorCardState extends State<SectionEditorCard> {
  late TextEditingController _controller;
  bool _expanded = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.section.content);
  }

  @override
  void didUpdateWidget(SectionEditorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section.content != widget.section.content &&
        widget.section.content != _controller.text) {
      _controller.text = widget.section.content;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasContent = widget.section.content.isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: hasContent
              ? const Color(0xFFD4A574).withAlpha(60)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(widget.info.icon, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.info.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (!_expanded && hasContent)
                          Text(
                            widget.section.content,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        if (!_expanded && !hasContent)
                          Text(
                            widget.info.hint,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (hasContent)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4A574).withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '已编辑',
                        style: TextStyle(
                          fontSize: 10,
                          color: const Color(0xFFD4A574),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _controller,
                maxLines: 8,
                minLines: 4,
                decoration: InputDecoration(
                  hintText: widget.info.hint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerLow,
                ),
                onChanged: widget.onContentChanged,
              ),
            ),
            if (widget.onAiGenerate != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: widget.isLoading ? null : widget.onAiGenerate,
                    icon: widget.isLoading
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: const Color(0xFFD4A574),
                            ),
                          )
                        : const Icon(Icons.auto_awesome, size: 16),
                    label: Text(widget.isLoading ? '生成中…' : '🤖 AI 辅助生成'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFD4A574),
                      side: const BorderSide(color: Color(0xFFD4A574)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
