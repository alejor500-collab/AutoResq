import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../../../../core/constants/app_colors.dart';
// Chat uses Spanish field names from ChatMessage entity
import '../../../../core/utils/helpers.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../../domain/entities/message_entity.dart';

class DriverChatScreen extends ConsumerStatefulWidget {
  final String emergencyId;

  const DriverChatScreen({super.key, required this.emergencyId});

  @override
  ConsumerState<DriverChatScreen> createState() => _DriverChatScreenState();
}

class _DriverChatScreenState extends ConsumerState<DriverChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();

    await ref
        .read(chatNotifierProvider(widget.emergencyId).notifier)
        .sendMessage(emergencyId: widget.emergencyId, content: text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(messagesStreamProvider(widget.emergencyId));
    final user = ref.watch(authNotifierProvider).value;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Glass Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  height: 64 + MediaQuery.of(context).padding.top,
                  padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.onSurface.withOpacity(0.06),
                        blurRadius: 40,
                        offset: const Offset(0, 40),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.pop(),
                          child: const Icon(Icons.arrow_back,
                              color: AppColors.secondary),
                        ),
                        const Gap(16),
                        // Tech avatar with online indicator
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor:
                                  AppColors.surfaceContainerHigh,
                              child: const Icon(Icons.person,
                                  color: AppColors.secondary, size: 20),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 2),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Gap(12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Carlos Mendez',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.3,
                                  color: AppColors.onBackground,
                                ),
                              ),
                              Text(
                                'Especialista en Transmisiones \u2022 Online',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                  color: AppColors.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () {},
                          child: const Icon(Icons.call,
                              color: AppColors.primary, size: 22),
                        ),
                        const Gap(16),
                        const Icon(Icons.more_vert,
                            color: AppColors.secondary, size: 22),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Messages
          Positioned.fill(
            top: 64 + MediaQuery.of(context).padding.top,
            bottom: 0,
            child: Column(
              children: [
                Expanded(
                  child: messages.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary),
                    ),
                    error: (e, _) => Center(child: Text(e.toString())),
                    data: (msgs) {
                      _scrollToBottom();
                      if (msgs.isEmpty) {
                        return const Center(
                          child: Text(
                            'Inicia la conversacion con tu tecnico',
                            style: TextStyle(
                                color: AppColors.secondary, fontSize: 13),
                          ),
                        );
                      }
                      return ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                        itemCount: msgs.length + 1,
                        itemBuilder: (context, i) {
                          if (i == 0) {
                            return _DateBadge();
                          }
                          final msg = msgs[i - 1];
                          final isMe = msg.remitenteId == user?.id;
                          return _ChatBubble(message: msg, isMe: isMe);
                        },
                      );
                    },
                  ),
                ),

                // Input area
                _ChatInputBar(
                  controller: _msgCtrl,
                  onSend: _send,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Date Badge ───────────────────────────────────────────────────────────────

class _DateBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(9999),
        ),
        child: const Text(
          'Hoy',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: AppColors.secondary,
          ),
        ),
      ),
    );
  }
}

// ─── Chat Bubble (Stitch style) ───────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const _ChatBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.85,
            ),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isMe ? null : AppColors.surfaceContainerLow,
              gradient: isMe ? AppColors.primaryGradient : null,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isMe ? 20 : 0),
                bottomRight: Radius.circular(isMe ? 0 : 20),
              ),
              boxShadow: isMe
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: AppColors.onSurface.withOpacity(0.03),
                        blurRadius: 8,
                      ),
                    ],
            ),
            child: Text(
              message.contenido,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: isMe ? Colors.white : AppColors.onBackground,
              ),
            ),
          ),
          const Gap(4),
          Padding(
            padding: EdgeInsets.only(
              left: isMe ? 0 : 4,
              right: isMe ? 4 : 0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment:
                  isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                Text(
                  AppHelpers.formatTime(message.fechaEnvio),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.secondary,
                  ),
                ),
                if (isMe) ...[
                  const Gap(4),
                  Icon(
                    Icons.done_all,
                    size: 14,
                    color: AppColors.primary,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Input Bar ────────────────────────────────────────────────────────────────

class _ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _ChatInputBar({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            MediaQuery.of(context).padding.bottom + 40,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Attach button
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: AppColors.secondary),
              ),
              const Gap(12),
              // Text field
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(
                      minHeight: 56, maxHeight: 128),
                  child: TextField(
                    controller: controller,
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.onBackground,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Escribe un mensaje...',
                      hintStyle: TextStyle(
                        color: AppColors.secondary.withOpacity(0.5),
                        fontWeight: FontWeight.w500,
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceContainerLow,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
              const Gap(12),
              // Send button
              GestureDetector(
                onTap: onSend,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.2),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.send,
                      color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
