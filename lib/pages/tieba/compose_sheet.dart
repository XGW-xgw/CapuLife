import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../services/cap_image_picker.dart';
import '../../services/tieba/tieba_api.dart';
import '../../services/tieba/tieba_client.dart';
import '../../services/tieba/tieba_emoticons.dart';
import '../../theme.dart';
import '../../widgets/cap_icon.dart';
import '../../widgets/cap_sheet.dart';
import '../../widgets/cap_toast.dart';

Future<bool?> showTiebaComposeSheet({
  required BuildContext context,
  required TiebaClient client,
  required String forumName,
  required int forumId,
  bool reply = false,
  int threadId = 0,
  String threadTitle = '',
  int quotePostId = 0,
  int subPostId = 0,
  int replyUid = 0,
  String replyPrefix = '',
  String replyUserName = '',
  VoidCallback? onSent,
}) {
  return showCapSheet<bool>(
    context: context,
    heightFactor: 0.92,
    builder: (_) => _ComposeSheet(
      client: client,
      forumName: forumName,
      forumId: forumId,
      reply: reply,
      threadId: threadId,
      threadTitle: threadTitle,
      quotePostId: quotePostId,
      subPostId: subPostId,
      replyUid: replyUid,
      replyPrefix: replyPrefix,
      replyUserName: replyUserName,
      onSent: onSent,
    ),
  );
}

class _ComposeImage {
  _ComposeImage({
    required this.path,
    required this.width,
    required this.height,
  });

  final String path;
  final int width;
  final int height;
}

class _ComposeSheet extends StatefulWidget {
  const _ComposeSheet({
    required this.client,
    required this.forumName,
    required this.forumId,
    required this.reply,
    required this.threadId,
    required this.threadTitle,
    required this.quotePostId,
    required this.subPostId,
    required this.replyUid,
    required this.replyPrefix,
    required this.replyUserName,
    this.onSent,
  });

  final TiebaClient client;
  final String forumName;
  final int forumId;
  final bool reply;
  final int threadId;
  final String threadTitle;
  final int quotePostId;
  final int subPostId;
  final int replyUid;
  final String replyPrefix;
  final String replyUserName;
  final VoidCallback? onSent;

  @override
  State<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<_ComposeSheet> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _content = TextEditingController();
  final FocusNode _contentFocus = FocusNode();
  final List<_ComposeImage> _images = [];
  bool _sending = false;
  bool _showEmoji = false;
  String _status = '';

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  Future<(int, int)> _imageSize(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final width = frame.image.width;
      final height = frame.image.height;
      frame.image.dispose();
      codec.dispose();
      if (width > 0 && height > 0) return (width, height);
    } catch (_) {}
    return (1080, 1080);
  }

  Future<void> _pickImages() async {
    if (_sending) return;
    final remain = 9 - _images.length;
    if (remain <= 0) {
      showCapToast(context, '最多选择 9 张图片');
      return;
    }
    final paths = await CapImagePicker.pickImages(count: remain);
    if (!mounted || paths.isEmpty) return;
    for (final path in paths) {
      if (_images.length >= 9) break;
      final (width, height) = await _imageSize(path);
      _images.add(_ComposeImage(path: path, width: width, height: height));
    }
    if (mounted) {
      setState(() => _showEmoji = false);
    }
  }

  void _toggleEmoji() {
    setState(() => _showEmoji = !_showEmoji);
    if (_showEmoji) {
      _contentFocus.unfocus();
    } else {
      _contentFocus.requestFocus();
    }
  }

  void _insertEmoji(TiebaEmoticon emoticon) {
    final text = _content.text;
    final selection = _content.selection;
    final start = selection.isValid
        ? selection.start.clamp(0, text.length)
        : text.length;
    final end = selection.isValid
        ? selection.end.clamp(0, text.length)
        : text.length;
    final from = start < end ? start : end;
    final to = start < end ? end : start;
    final insert = emoticon.insertText;
    _content.value = TextEditingValue(
      text: '${text.substring(0, from)}$insert${text.substring(to)}',
      selection: TextSelection.collapsed(offset: from + insert.length),
    );
  }

  Future<void> _send() async {
    if (_sending) return;
    final content = _content.text.trim();
    if (content.isEmpty && _images.isEmpty) {
      showCapToast(context, '写点内容或选张图片吧');
      return;
    }
    if (!widget.reply && _title.text.trim().isEmpty) {
      showCapToast(context, '给帖子起个标题');
      return;
    }
    setState(() {
      _sending = true;
      _status = '准备发送…';
    });
    try {
      final tags = <String>[];
      for (var i = 0; i < _images.length; i += 1) {
        final image = _images[i];
        setState(() => _status = '上传图片 ${i + 1}/${_images.length}…');
        final bytes = await File(image.path).readAsBytes();
        final uploaded = await widget.client.api.uploadPicture(
          bytes: bytes,
          forumName: widget.forumName.isEmpty ? '成都航空职业技术大学' : widget.forumName,
          width: image.width,
          height: image.height,
          onProgress: (progress) {
            if (!mounted) return;
            setState(() {
              _status =
                  '上传图片 ${i + 1}/${_images.length}（${(progress * 100).round()}%）';
            });
          },
        );
        tags.add('#(pic,${uploaded.picId},${uploaded.width},${uploaded.height})');
      }
      final finalContent = [
        if (content.isNotEmpty) '${widget.replyPrefix}$content',
        ...tags,
      ].join('\n');
      setState(() => _status = '提交中…');
      await widget.client.healSession();
      if (widget.reply) {
        await widget.client.api.addPost(
          forumId: widget.forumId,
          forumName: widget.forumName,
          threadId: widget.threadId,
          content: finalContent,
          quotePostId: widget.quotePostId,
          subPostId: widget.subPostId,
          replyUid: widget.replyUid,
        );
      } else {
        await widget.client.api.addThread(
          forumId: widget.forumId,
          forumName: widget.forumName,
          title: _title.text.trim(),
          content: finalContent,
        );
      }
      if (!mounted) return;
      showCapToast(context, widget.reply ? '回复已发送' : '帖子已发布');
      widget.onSent?.call();
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      showCapToast(
        context,
        error is TiebaApiException
            ? error.message
            : (widget.reply ? '回复失败，请稍后重试' : '发布失败，请稍后重试'),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _status = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CapSheetPanel(
      title: widget.reply ? '回复帖子' : '发布新帖',
      subtitle: widget.reply
          ? widget.replyUserName.isNotEmpty
              ? '回复 ${widget.replyUserName} · ${widget.forumName}吧'
              : '${widget.threadTitle.isEmpty ? '帖子' : widget.threadTitle} · ${widget.forumName}吧'
          : '${widget.forumName}吧',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            if (!widget.reply) ...[
              _label(context, '标题'),
              Container(
                height: capRpx(context, 92),
                padding: EdgeInsets.symmetric(horizontal: capRpx(context, 26)),
                decoration: _fieldDecoration(context),
                child: TextField(
                  controller: _title,
                  maxLength: 60,
                  style: TextStyle(
                    fontSize: capRpx(context, 27),
                    color: AppColors.ink,
                  ),
                  decoration: _inputDecoration(context, '写一个清楚的标题'),
                ),
              ),
              SizedBox(height: capRpx(context, 18)),
            ],
            _label(context, widget.reply ? '回复内容' : '正文'),
            Container(
              constraints: BoxConstraints(minHeight: capRpx(context, 260)),
              padding: EdgeInsets.symmetric(
                horizontal: capRpx(context, 22),
                vertical: capRpx(context, 18),
              ),
              decoration: _fieldDecoration(context),
              child: TextField(
                controller: _content,
                focusNode: _contentFocus,
                autofocus: true,
                maxLines: null,
                maxLength: 2000,
                onTap: () {
                  if (_showEmoji) setState(() => _showEmoji = false);
                },
                style: TextStyle(
                  fontSize: capRpx(context, 24),
                  height: 1.6,
                  color: AppColors.ink,
                ),
                decoration: _inputDecoration(
                  context,
                  '友善交流，具体一点会更容易得到回复',
                ),
              ),
            ),
            SizedBox(height: capRpx(context, 10)),
            Row(
              children: [
                _toolButton(
                  icon: 'smile',
                  active: _showEmoji,
                  onTap: _sending ? null : _toggleEmoji,
                ),
                SizedBox(width: capRpx(context, 8)),
                _toolButton(
                  icon: 'image-plus',
                  onTap: _sending ? null : _pickImages,
                ),
                const Spacer(),
                Text(
                  _status.isNotEmpty ? _status : '${_images.length}/9 图',
                  style: TextStyle(
                    fontSize: capRpx(context, 18),
                    color: _status.isNotEmpty
                        ? AppColors.accent
                        : AppColors.mutedSoft,
                  ),
                ),
              ],
            ),
            if (_showEmoji) ...[
              SizedBox(height: capRpx(context, 10)),
              Container(
                height: capRpx(context, 250),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(capRpx(context, 20)),
                  border: Border.all(color: AppColors.line, width: 0.8),
                ),
                child: GridView.builder(
                  padding: EdgeInsets.all(capRpx(context, 12)),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: capRpx(context, 8),
                    crossAxisSpacing: capRpx(context, 8),
                  ),
                  itemCount: tiebaEmoticons.length,
                  itemBuilder: (context, index) {
                    final emoticon = tiebaEmoticons[index];
                    return GestureDetector(
                      onTap: () => _insertEmoji(emoticon),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(capRpx(context, 10)),
                        ),
                        padding: EdgeInsets.all(capRpx(context, 5)),
                        child: Image.network(
                          emoticon.imageUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stack) => Center(
                            child: Text(
                              emoticon.name,
                              style: TextStyle(
                                fontSize: capRpx(context, 14),
                                color: AppColors.mutedSoft,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            if (_images.isNotEmpty) ...[
              SizedBox(height: capRpx(context, 12)),
              Wrap(
                spacing: capRpx(context, 8),
                runSpacing: capRpx(context, 8),
                children: [
                  for (var i = 0; i < _images.length; i += 1)
                    SizedBox(
                      width: capRpx(context, 150),
                      height: capRpx(context, 150),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(capRpx(context, 14)),
                            child: Image.file(
                              File(_images[i].path),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stack) => ColoredBox(
                                color: AppColors.surfaceSoft,
                                child: Center(
                                  child: CapIcon(
                                    'image',
                                    size: capRpx(context, 28),
                                    color: AppColors.mutedSoft,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (!_sending)
                            Positioned(
                              right: capRpx(context, 4),
                              top: capRpx(context, 4),
                              child: GestureDetector(
                                onTap: () => setState(() => _images.removeAt(i)),
                                child: Container(
                                  width: capRpx(context, 32),
                                  height: capRpx(context, 32),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: CapIcon(
                                      'x',
                                      size: capRpx(context, 16),
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (_images.length < 9 && !_sending)
                    GestureDetector(
                      onTap: _pickImages,
                      child: Container(
                        width: capRpx(context, 150),
                        height: capRpx(context, 150),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSoft,
                          borderRadius: BorderRadius.circular(capRpx(context, 14)),
                          border: Border.all(color: AppColors.line, width: 0.8),
                        ),
                        child: Center(
                          child: CapIcon(
                            'plus',
                            size: capRpx(context, 30),
                            color: AppColors.mutedSoft,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
            SizedBox(height: capRpx(context, 18)),
            GestureDetector(
              onTap: _sending ? null : _send,
              child: Opacity(
                opacity: _sending ? 0.7 : 1,
                child: Container(
                  height: capRpx(context, 82),
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(capRpx(context, 20)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CapIcon(
                        _sending ? 'loader-circle' : 'send',
                        size: capRpx(context, 26),
                        color: Colors.white,
                      ),
                      SizedBox(width: capRpx(context, 8)),
                      Text(
                        _sending
                            ? (_status.isEmpty ? '发送中…' : _status)
                            : (widget.reply ? '发送回复' : '发布帖子'),
                        style: TextStyle(
                          fontSize: capRpx(context, 24),
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: capRpx(context, 12)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CapIcon(
                  'info',
                  size: capRpx(context, 18),
                  color: AppColors.mutedSoft,
                ),
                SizedBox(width: capRpx(context, 5)),
                Expanded(
                  child: Text(
                    '表情以贴吧代码插入；图片最多 9 张，发送时会先上传到贴吧图床。凭据只保存在本机。',
                    style: TextStyle(
                      fontSize: capRpx(context, 17),
                      height: 1.5,
                      color: AppColors.mutedSoft,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: capRpx(context, 8)),
          ],
        ),
      );
  }

  Widget _toolButton({
    required String icon,
    required VoidCallback? onTap,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: capRpx(context, 58),
        height: capRpx(context, 58),
        decoration: BoxDecoration(
          color: active ? AppColors.accentSoft : AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(capRpx(context, 16)),
          border: Border.all(
            color: active ? AppColors.accent.withValues(alpha: 0.3) : AppColors.line,
            width: 0.8,
          ),
        ),
        child: Center(
          child: CapIcon(
            icon,
            size: capRpx(context, 25),
            color: active ? AppColors.accent : AppColors.muted,
          ),
        ),
      ),
    );
  }

  Widget _label(BuildContext context, String text) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        capRpx(context, 4),
        0,
        capRpx(context, 4),
        capRpx(context, 12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: capRpx(context, 22),
          fontWeight: FontWeight.w700,
          letterSpacing: capRpx(context, 0.9),
          color: AppColors.muted,
        ),
      ),
    );
  }

  BoxDecoration _fieldDecoration(BuildContext context) => BoxDecoration(
    color: AppColors.surfaceSoft,
    borderRadius: BorderRadius.circular(capRpx(context, 22)),
    border: Border.all(color: AppColors.line, width: 0.8),
  );

  InputDecoration _inputDecoration(BuildContext context, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: capRpx(context, 22),
        color: AppColors.mutedSoft,
      ),
      counterText: '',
      border: InputBorder.none,
      isDense: true,
      contentPadding: EdgeInsets.zero,
    );
  }
}