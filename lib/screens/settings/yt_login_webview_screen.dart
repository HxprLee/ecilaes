// Ecilaes - Cross-platform music player
// Copyright (C) 2024  hxprlee
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../router/routes.dart';
import '../../services/yt_login_coordinator.dart';
import '../../signals/audio_signal.dart';
import '../../signals/overlay_signal.dart';
import '../../utils/navigation.dart';
import '../../widgets/components/app_dialog.dart';
import '../../widgets/components/app_toast.dart';
import '../../widgets/components/sliver_page_header.dart';

class YtLoginWebViewScreen extends StatefulWidget {
  const YtLoginWebViewScreen({super.key});

  @override
  State<YtLoginWebViewScreen> createState() => _YtLoginWebViewScreenState();
}

class _YtLoginWebViewScreenState extends State<YtLoginWebViewScreen> {
  final GlobalKey _webViewKey = GlobalKey();
  InAppWebViewController? _webViewController;
  final TextEditingController _manualCookieController = TextEditingController();

  /// `flutter_inappwebview` has no Linux native implementation; calling
  /// `InAppWebView` there surfaces `MissingPluginException`. We detect this
  /// at runtime and swap to a paste-from-clipboard flow.
  late final bool _linux;

  bool _isLoading = true;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _linux = !kIsWeb && Platform.isLinux;

    if (!_linux) {
      CookieManager.instance().deleteAllCookies();
    }
  }

  @override
  void dispose() {
    _manualCookieController.dispose();
    super.dispose();
  }

  String get _userAgent => _linux
      ? 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
      : 'Mozilla/5.0 (Linux; Android 10; Pixel 6) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  Future<void> _handleResult(YtLoginResult result) async {
    if (!mounted) return;
    if (result.success) {
      ToastService.show(
        result.username != null
            ? 'Connected as ${result.username}'
            : 'YouTube Music Account connected successfully!',
        variant: AppToastVariant.success,
      );
      if (context.canPop()) {
        context.pop();
      } else {
        navigateTab(context, AppRoutes.settingsIntegrations);
      }
      return;
    }
    setState(() {
      _isLoading = false;
      _statusMessage = result.error ?? 'Sign-in failed. Please try again.';
    });
  }

  Future<void> _verifyNow() async {
    final result = await ytLoginCoordinator.finalizeFromCookies();
    if (!mounted) return;
    if (result == null) {
      ToastService.show(
        'No sign-in cookies detected yet. Please complete sign-in first.',
        variant: AppToastVariant.warning,
      );
      return;
    }
    await _handleResult(result);
  }

  Future<void> _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboardData?.text ?? '';
    if (text.isEmpty) {
      _showInstructions();
      return;
    }
    if (!text.contains('=') || text.contains('<') || text.contains('>')) {
      _showInstructions();
      return;
    }
    final sanitized = text.trim().replaceAll(RegExp(r'[^\x20-\x7E]'), '');
    await _submitCookie(sanitized: sanitized, fromClipboard: true);
  }

  Future<void> _submitManualEntry() async {
    final raw = _manualCookieController.text.trim();
    if (raw.isEmpty) {
      _showInstructions();
      return;
    }
    final sanitized = raw.replaceAll(RegExp(r'[^\x20-\x7E]'), '');
    await _submitCookie(sanitized: sanitized, fromClipboard: false);
  }

  Future<void> _submitCookie({
    required String sanitized,
    required bool fromClipboard,
  }) async {
    final result = await ytLoginCoordinator.acceptManualCookie(sanitized);
    if (!mounted) return;
    if (result.success) {
      await _handleResult(result);
      return;
    }
    ToastService.show(
      result.error ??
          (fromClipboard
              ? 'Clipboard does not contain a YouTube cookie.'
              : 'Cookie string invalid.'),
      variant: AppToastVariant.error,
    );
  }

  Future<void> _openYtmInBrowser() async {
    final uri = YtLoginCoordinator.signInUri;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ToastService.show(
        'Could not open the system browser.',
        variant: AppToastVariant.error,
      );
    }
  }

  void _showInstructions() {
    overlaySignal.push(ActiveOverlay.ytLoginInstructions);

    showDialog(
      context: context,
      useRootNavigator: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (dialogContext) => AppDialog(
        titleIcon: Icon(
          Icons.help_outline,
          color: Theme.of(dialogContext).colorScheme.secondary,
        ),
        title: 'How to get your YouTube Music cookie',
        maxWidth: 480,
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('1. Open your browser and go to music.youtube.com'),
              const SizedBox(height: 8),
              const Text('2. Sign in to your Google account'),
              const SizedBox(height: 8),
              const Text(
                '3a. On desktop: open Developer Tools (F12) -> Network tab, '
                'refresh, click any request to music.youtube.com, and copy '
                'the entire value of the "cookie" request header.',
              ),
              const SizedBox(height: 8),
              const Text(
                '3b. On mobile (Chrome): tap the lock icon in the address '
                'bar -> Cookies -> music.youtube.com, then find and copy '
                'the value of "SAPISID".',
              ),
              const SizedBox(height: 8),
              const Text('4. Tap the paste button above to save the cookie.'),
              const SizedBox(height: 16),
              Text(
                'The cookie string should look like:\n'
                'SAPISID=abc123...; __Secure-1PAPISID=def456...; __Secure-3PAPISID=ghi789...',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    dialogContext,
                  ).colorScheme.secondary.withValues(alpha: 0.6),
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              overlaySignal.pop(ActiveOverlay.ytLoginInstructions);
              Navigator.of(dialogContext).pop();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(
                dialogContext,
              ).colorScheme.secondary.withValues(alpha: 0.8),
              foregroundColor: Theme.of(dialogContext).colorScheme.surface,
              shape: const StadiumBorder(),
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _linux ? _buildLinuxBody() : _buildWebViewBody();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          SliverPageHeader(
            title: 'YouTube Music Login',
            maxWidth: 600,
            actions: _linux
                ? null
                : [
                    IconButton(
                      icon: const Icon(Icons.help_outline),
                      tooltip: 'How to get cookie',
                      onPressed: _showInstructions,
                    ),
                    IconButton(
                      icon: const Icon(Icons.content_paste),
                      tooltip: 'Paste cookie string',
                      onPressed: _pasteFromClipboard,
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Reload',
                      onPressed: () => _webViewController?.reload(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.check),
                      tooltip: 'I have signed in',
                      onPressed: _verifyNow,
                    ),
                  ],
            bottom: _StatusBanner(
              isLoading: _isLoading,
              isLinux: _linux,
              statusMessage: _statusMessage,
            ),
          ),
          SliverFillRemaining(hasScrollBody: _linux, child: body),
          SliverToBoxAdapter(
            child: SignalBuilder(builder: (context) => SizedBox(height: audioSignal.reservedHeight.value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinuxBody() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.computer,
                size: 56,
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(height: 16),
              Text(
                'Manual sign-in for Linux',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                'Flutter cannot display an embedded webview on Linux yet. '
                'Open YouTube Music in your browser, get the cookie string, '
                'then paste the cookie string below.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _openYtmInBrowser,
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.secondary.withValues(alpha: 0.8),
                  foregroundColor: Theme.of(context).colorScheme.surface,
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(Icons.open_in_browser),
                label: const Text('Open music.youtube.com/signin'),
              ),
              const SizedBox(height: 24),
              const Text(
                'Paste your cookie string:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _manualCookieController,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  hintText:
                      'SAPISID=…; __Secure-1PAPISID=…; __Secure-3PAPISID=…',
                ),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pasteFromClipboard,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: Theme.of(
                            context,
                          ).colorScheme.secondary.withValues(alpha: 0.2),
                        ),
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.secondary,
                        shape: const StadiumBorder(),
                      ),
                      icon: const Icon(Icons.content_paste),
                      label: const Text('Paste from clipboard'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _submitManualEntry,
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.secondary.withValues(alpha: 0.8),
                        foregroundColor: Theme.of(context).colorScheme.surface,
                        shape: const StadiumBorder(),
                      ),
                      icon: const Icon(Icons.check),
                      label: const Text('Save'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton.icon(
                  onPressed: _showInstructions,
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.secondary,
                  ),
                  icon: const Icon(Icons.help_outline, size: 16),
                  label: const Text('How do I get the cookie string?'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebViewBody() {
    return InAppWebView(
      key: _webViewKey,
      initialUrlRequest: URLRequest(
        url: WebUri(YtLoginCoordinator.signInUri.toString()),
      ),
      initialSettings: InAppWebViewSettings(
        userAgent: _userAgent,
        transparentBackground: true,
      ),
      onWebViewCreated: (controller) {
        _webViewController = controller;
      },
      onLoadStart: (controller, url) {
        if (mounted) {
          setState(() {
            _isLoading = true;
            if (_statusMessage.isNotEmpty) _statusMessage = '';
          });
        }
      },
      onLoadStop: (controller, url) async {
        if (!mounted) return;
        setState(() => _isLoading = false);
        final result = await ytLoginCoordinator.finalizeFromCookies();
        if (result == null || !mounted) return;
        await _handleResult(result);
      },
      onReceivedError: (controller, request, error) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _statusMessage =
              'Page failed to load (${error.description}). Try again or paste a cookie manually.';
        });
      },
    );
  }
}

/// Pinned banner that lives in [SliverPageHeader.bottom] and shows either a
/// loading bar or an error message under the page title.
class _StatusBanner extends StatelessWidget implements PreferredSizeWidget {
  const _StatusBanner({
    required this.isLoading,
    required this.isLinux,
    required this.statusMessage,
  });

  final bool isLoading;
  final bool isLinux;
  final String statusMessage;

  @override
  Size get preferredSize {
    if (isLinux) return Size.zero;
    if (isLoading) return const Size.fromHeight(4);
    if (statusMessage.isNotEmpty) return const Size.fromHeight(40);
    return Size.zero;
  }

  @override
  Widget build(BuildContext context) {
    if (isLinux) return const SizedBox.shrink();
    if (isLoading) {
      return LinearProgressIndicator(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        color: Theme.of(context).colorScheme.secondary,
      );
    }
    if (statusMessage.isNotEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: Theme.of(
          context,
        ).colorScheme.errorContainer.withValues(alpha: 0.4),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 16,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                statusMessage,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
