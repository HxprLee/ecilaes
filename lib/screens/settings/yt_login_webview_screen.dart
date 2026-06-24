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
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:go_router/go_router.dart';
import 'package:signals/signals_flutter.dart';
import '../../signals/audio_signal.dart';
import '../../signals/settings_signal.dart';
import '../../widgets/components/window_title_bar.dart';

class YtLoginWebViewScreen extends StatefulWidget {
  const YtLoginWebViewScreen({super.key});

  @override
  State<YtLoginWebViewScreen> createState() => _YtLoginWebViewScreenState();
}

class _YtLoginWebViewScreenState extends State<YtLoginWebViewScreen> {
  final GlobalKey webViewKey = GlobalKey();
  InAppWebViewController? webViewController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Clear cookies before starting to ensure a clean login state
    CookieManager.instance().deleteAllCookies();
  }

  Future<void> _checkCookies() async {
    try {
      final cookies = await CookieManager.instance().getCookies(url: WebUri("https://music.youtube.com"));
      
      final cookieString = cookies.map((c) => '${c.name}=${c.value}').join('; ');
      
      // If we see YouTube authentication cookies, we consider it a success
      if (cookieString.contains('SAPISID') || cookieString.contains('__Secure-1PAPISID') || cookieString.contains('__Secure-3PAPISID')) {
        await settingsSignal.updateYtAuthCookie(cookieString);
        audioSignal.reindexLibrary();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('YouTube Music Account connected successfully!')),
          );
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/settings/library');
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking cookies: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          if (isDesktop) const WindowTitleBar(),
          AppBar(
            title: const Text('Sign in to YouTube Music'),
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/settings/library');
                }
              },
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  webViewController?.reload();
                },
              ),
              IconButton(
                icon: const Icon(Icons.check),
                tooltip: 'I have signed in',
                onPressed: _checkCookies,
              ),
            ],
          ),
          if (_isLoading) 
            LinearProgressIndicator(
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              color: Theme.of(context).colorScheme.secondary,
            ),
          Expanded(
            child: InAppWebView(
              key: webViewKey,
              initialUrlRequest: URLRequest(url: WebUri("https://music.youtube.com/")),
              initialSettings: InAppWebViewSettings(
                userAgent: 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                transparentBackground: true,
              ),
              onWebViewCreated: (controller) {
                webViewController = controller;
              },
              onLoadStart: (controller, url) {
                setState(() {
                  _isLoading = true;
                });
              },
              onLoadStop: (controller, url) async {
                setState(() {
                  _isLoading = false;
                });
                await _checkCookies();
              },
            ),
          ),
        ],
      ),
    );
  }
}