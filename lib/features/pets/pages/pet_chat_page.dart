import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_manager/data/models/pet.dart';
import 'package:home_manager/data/ai/ai_models.dart';
import 'package:home_manager/core/services/pet_chat_service.dart';
import 'package:home_manager/core/providers/tts_settings_provider.dart';
import 'package:home_manager/data/ai/tts_provider.dart';
import 'package:home_manager/data/repositories/pet_ai_repository.dart';

class PetChatPage extends ConsumerStatefulWidget {
  final Pet pet;
  final bool isOwner;

  const PetChatPage({super.key, required this.pet, this.isOwner = false});

  @override
  ConsumerState<PetChatPage> createState() => _PetChatPageState();
}

class _PetChatPageState extends ConsumerState<PetChatPage> {
  final PetChatService _chatService = PetChatService();
  final PetAIRepository _repository = PetAIRepository();
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  String _currentResponse = '';
  int _loadingMessageIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final conversations = await _repository.getConversations(widget.pet.id);
      if (conversations.isNotEmpty) {
        setState(() {
          for (final conv in conversations) {
            _messages.add(
              ChatMessage(
                id:
                    conv['id'] ??
                    DateTime.now().millisecondsSinceEpoch.toString(),
                content: conv['content'] ?? '',
                isUser: conv['role'] == 'user',
              ),
            );
          }
        });
      } else {
        _addSystemMessage();
      }
    } catch (e) {
      _addSystemMessage();
    }
  }

  void _addSystemMessage() {
    setState(() {
      _messages.add(
        ChatMessage(
          id: 'system',
          content: '和 ${widget.pet.name} 的对话开始啦！',
          isUser: false,
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    _controller.clear();

    setState(() {
      _messages.add(
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: text,
          isUser: true,
        ),
      );
      _currentResponse = '';
      _loadingMessageIndex = _messages.length;
      _messages.add(
        ChatMessage(
          id: 'loading_${DateTime.now().millisecondsSinceEpoch}',
          content: '',
          isUser: false,
        ),
      );
      _isLoading = true;
    });

    try {
      await for (final result in _chatService.sendMessageStream(
        pet: widget.pet,
        message: text,
        history: _messages
            .where(
              (m) =>
                  m.id != 'system' &&
                  m.id != 'loading_${_messages[_loadingMessageIndex]?.id}',
            )
            .toList(),
        isOwner: widget.isOwner,
      )) {
        setState(() {
          _currentResponse = result.fullResponse;
          if (_loadingMessageIndex >= 0 &&
              _loadingMessageIndex < _messages.length) {
            _messages[_loadingMessageIndex] = ChatMessage(
              id: _messages[_loadingMessageIndex].id,
              content: _currentResponse,
              isUser: false,
            );
          }
        });
      }

      final ttsSettings = ref.read(ttsSettingsProvider);
      if (ttsSettings.enabled && _currentResponse.isNotEmpty) {
        ref.read(ttsProvider.notifier).speak(_currentResponse);
      }

      setState(() {
        _isLoading = false;
        _loadingMessageIndex = -1;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _loadingMessageIndex = -1;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('发送失败: $e')));
      }
    }
  }

  void _toggleTTS() {
    ref.read(ttsSettingsProvider.notifier).toggle();
    final ttsSettings = ref.read(ttsSettingsProvider);
    if (ttsSettings.enabled) {
      ref.read(ttsProvider.notifier).speak('语音已开启');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ttsSettings = ref.watch(ttsSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            _getPetIcon(widget.pet.type),
            const SizedBox(width: 8),
            Text(widget.pet.name),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              ttsSettings.enabled ? Icons.volume_up : Icons.volume_off,
              color: ttsSettings.enabled ? Colors.green : null,
            ),
            onPressed: _toggleTTS,
            tooltip: ttsSettings.enabled ? '关闭语音' : '开启语音',
          ),
          if (widget.pet.skills.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  widget.pet.skills.first.icon,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                if (message.id == 'system') {
                  return _buildSystemMessage(message);
                }
                return _buildMessageBubble(message, index);
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildSystemMessage(ChatMessage message) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message.content,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ),
    );
  }

  Widget _getPetIcon(String type) {
    IconData icon;
    Color color;
    switch (type) {
      case 'cat':
        icon = Icons.pets;
        color = Colors.purple;
        break;
      case 'dog':
        icon = Icons.pets;
        color = Colors.brown;
        break;
      case 'rabbit':
      case 'hamster':
      case 'guinea_pig':
      case 'chinchilla':
        icon = Icons.face;
        color = Colors.pink;
        break;
      case 'bird':
      case 'parrot':
        icon = Icons.flutter_dash;
        color = Colors.orange;
        break;
      case 'fish':
      case 'turtle':
        icon = Icons.water;
        color = Colors.blue;
        break;
      case 'lizard':
        icon = Icons.pest_control;
        color = Colors.green;
        break;
      default:
        icon = Icons.pets;
        color = Colors.grey;
    }
    return Icon(icon, color: color, size: 28);
  }

  Widget _buildMessageBubble(ChatMessage message, int index) {
    final isUser = message.isUser;
    final isLoading = !isUser && _isLoading && index == _loadingMessageIndex;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? Theme.of(context).primaryColor : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isUser ? const Radius.circular(4) : null,
            bottomLeft: !isUser ? const Radius.circular(4) : null,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                message.content,
                style: TextStyle(color: isUser ? Colors.white : Colors.black87),
              ),
            ),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: '和 ${widget.pet.name} 说点什么...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _isLoading ? null : _sendMessage,
              icon: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              color: Theme.of(context).primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}
