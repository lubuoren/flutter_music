import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../application/netease_auth_controller.dart';

enum _LoginMode { qrCode, password, cookie }

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final TextEditingController _cookieController = TextEditingController();
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  _LoginMode _mode = _LoginMode.qrCode;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref
          .read(neteaseAuthControllerProvider.notifier)
          .load(startQrIfLoggedOut: true);
    });
  }

  @override
  void dispose() {
    _cookieController.dispose();
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(neteaseAuthControllerProvider);
    final controller = ref.read(neteaseAuthControllerProvider.notifier);

    ref.listen(
      neteaseAuthControllerProvider.select((state) => state.errorMessage),
      (previous, next) {
        if (next != null && next != previous && mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(next)));
        }
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('登录网易云账号'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: '在线音乐设置',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
        children: [
          if (state.isLoggedIn)
            _ProfilePanel(
              state: state,
              onRefresh: controller.refreshLoginStatus,
              onLogout: controller.logout,
            )
          else ...[
            SegmentedButton<_LoginMode>(
              segments: const [
                ButtonSegment(
                  value: _LoginMode.qrCode,
                  icon: Icon(Icons.qr_code_rounded),
                  label: Text('二维码'),
                ),
                ButtonSegment(
                  value: _LoginMode.password,
                  icon: Icon(Icons.password_rounded),
                  label: Text('密码'),
                ),
                ButtonSegment(
                  value: _LoginMode.cookie,
                  icon: Icon(Icons.cookie_rounded),
                  label: Text('Cookie'),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (selection) {
                setState(() {
                  _mode = selection.first;
                });
                if (_mode == _LoginMode.qrCode && state.qrImageData == null) {
                  controller.startQrLogin();
                }
              },
            ),
            const SizedBox(height: 16),
            if (_mode == _LoginMode.qrCode)
              _QrLoginPanel(state: state, onRefresh: controller.startQrLogin)
            else if (_mode == _LoginMode.password)
              _PasswordLoginPanel(
                accountController: _accountController,
                passwordController: _passwordController,
                isLoading: state.isLoading,
                onSubmit: () {
                  final account = _accountController.text.trim();
                  final password = _passwordController.text;
                  if (account.contains('@')) {
                    controller.loginWithEmail(account, password);
                  } else {
                    controller.loginWithPhone(account, password);
                  }
                },
              )
            else
              _CookieLoginPanel(
                controller: _cookieController,
                isLoading: state.isLoading,
                onSubmit: () => controller.importCookie(_cookieController.text),
              ),
          ],
        ],
      ),
    );
  }
}

class _ProfilePanel extends StatelessWidget {
  const _ProfilePanel({
    required this.state,
    required this.onRefresh,
    required this.onLogout,
  });

  final NeteaseAuthState state;
  final VoidCallback onRefresh;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final profile = state.profile!;
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage:
                      profile.avatarUrl == null || profile.avatarUrl!.isEmpty
                      ? null
                      : NetworkImage(profile.avatarUrl!),
                  child: profile.avatarUrl == null || profile.avatarUrl!.isEmpty
                      ? const Icon(Icons.person_rounded)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.nickname,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        'UID ${profile.userId}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                if (state.isLoading)
                  const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(Icons.check_circle_rounded, color: colorScheme.primary),
              ],
            ),
            if (profile.signature != null && profile.signature!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                profile.signature!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: state.isLoading ? null : onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('校验登录态'),
                ),
                OutlinedButton.icon(
                  onPressed: state.isLoading ? null : onLogout,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('退出登录'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QrLoginPanel extends StatelessWidget {
  const _QrLoginPanel({required this.state, required this.onRefresh});

  final NeteaseAuthState state;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            SizedBox.square(
              dimension: 220,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: state.qrImageData == null
                      ? state.isLoading
                            ? const CircularProgressIndicator()
                            : const Icon(Icons.qr_code_2_rounded, size: 72)
                      : Padding(
                          padding: const EdgeInsets.all(14),
                          child: _QrImage(data: state.qrImageData!),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              state.qrStatusMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              state.isPollingQr ? '正在轮询扫码状态' : '二维码未在轮询',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: state.isLoading ? null : onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(state.qrImageData == null ? '生成二维码' : '刷新二维码'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CookieLoginPanel extends StatelessWidget {
  const _CookieLoginPanel({
    required this.controller,
    required this.isLoading,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'MUSIC_U=...; __csrf=...',
                labelText: '网易云 Cookie',
              ),
              textInputAction: TextInputAction.newline,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: isLoading ? null : onSubmit,
              icon: isLoading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login_rounded),
              label: const Text('导入并校验'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordLoginPanel extends StatefulWidget {
  const _PasswordLoginPanel({
    required this.accountController,
    required this.passwordController,
    required this.isLoading,
    required this.onSubmit,
  });

  final TextEditingController accountController;
  final TextEditingController passwordController;
  final bool isLoading;
  final VoidCallback onSubmit;

  @override
  State<_PasswordLoginPanel> createState() => _PasswordLoginPanelState();
}

class _PasswordLoginPanelState extends State<_PasswordLoginPanel> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: widget.accountController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: '手机号或邮箱',
                hintText: '13800138000 或 you@example.com',
                prefixIcon: Icon(Icons.account_circle_rounded),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: widget.passwordController,
              obscureText: _obscure,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: '密码',
                prefixIcon: const Icon(Icons.lock_rounded),
                suffixIcon: IconButton(
                  tooltip: _obscure ? '显示密码' : '隐藏密码',
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!widget.isLoading) {
                  widget.onSubmit();
                }
              },
            ),
            const SizedBox(height: 10),
            Text(
              '账号含 @ 视为邮箱登录，否则按手机号登录。密码经 MD5 后通过 HTTPS '
              '发送，仅用于换取登录态，不在本地保存。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: widget.isLoading ? null : widget.onSubmit,
              icon: widget.isLoading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login_rounded),
              label: const Text('登录'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QrImage extends StatelessWidget {
  const _QrImage({required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    if (data.startsWith('data:image/svg+xml')) {
      final svg = Uri.decodeFull(data.substring(data.indexOf(',') + 1));
      return SvgPicture.string(svg, fit: BoxFit.contain);
    }

    if (data.startsWith('data:image') && data.contains('base64,')) {
      final payload = data.substring(data.indexOf('base64,') + 7);
      return Image.memory(base64Decode(payload), fit: BoxFit.contain);
    }

    if (data.startsWith('http://') || data.startsWith('https://')) {
      return Image.network(data, fit: BoxFit.contain);
    }

    return SelectableText(data, textAlign: TextAlign.center);
  }
}
