import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../services/discord_service.dart';
import 'snackbar.dart';

class DiscordLoginDialog extends StatefulWidget {
  const DiscordLoginDialog({super.key});

  @override
  State<DiscordLoginDialog> createState() => _DiscordLoginDialogState();
}

class _DiscordLoginDialogState extends State<DiscordLoginDialog> {
  late final WebViewController _controller;
  bool _isLoading = true;
  Timer? _tokenCheckTimer;
  bool _tokenFound = false;
  bool _isCheckingToken = false;
  final Set<String> _rejectedTokens = {};

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(DiscordService.mobileUserAgent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (url) {
            if (mounted) setState(() => _isLoading = false);
            _checkForToken();
          },
          onNavigationRequest: (request) {
            return NavigationDecision.navigate;
          },
        ),
      );

    // Clear stale WebView cookies/storage first so a revoked session is not
    // immediately re-read instead of letting the user sign in fresh.
    Future(() async {
      try {
        await WebViewCookieManager().clearCookies();
      } catch (_) {}
      try {
        await _controller.clearLocalStorage();
      } catch (_) {}
      if (!mounted) return;
      await _controller.loadRequest(Uri.parse('https://discord.com/login'));
      _tokenCheckTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (!_tokenFound && !_isCheckingToken) {
          _checkForToken();
        }
      });
    });
  }

  Future<void> _checkForToken() async {
    if (_tokenFound || _isCheckingToken) return;
    _isCheckingToken = true;

    try {
      // Check localStorage/iframe first (written upon real login), then webpack TokenStore.
      const jsCode = """
      (function() {
        try {
          var ls = window.localStorage.getItem('token');
          if (ls) return ls.replace(/["']/g, '');
        } catch(e) {}
        try {
          var f = document.createElement('iframe');
          document.body.appendChild(f);
          var fls = f.contentWindow && f.contentWindow.localStorage.getItem('token');
          f.remove();
          if (fls) return fls.replace(/["']/g, '');
        } catch(e) {}
        try {
          var mods = [];
          webpackChunkdiscord_app.push([[''],{},function(e){
            for (var c in e.c) mods.push(e.c[c]);
          }]);
          for (var i = 0; i < mods.length; i++) {
            var exp = mods[i] && mods[i].exports;
            if (!exp) continue;
            if (exp.default && typeof exp.default.getToken === 'function') {
              var t1 = exp.default.getToken();
              if (typeof t1 === 'string' && t1.indexOf('.') !== -1 && t1.length > 30) return t1;
            }
            var vals = Object.values(exp);
            for (var j = 0; j < vals.length; j++) {
              if (vals[j] && typeof vals[j].getToken === 'function') {
                var t2 = vals[j].getToken();
                if (typeof t2 === 'string' && t2.indexOf('.') !== -1 && t2.length > 30) return t2;
              }
            }
          }
        } catch(e) {}
        return '';
      })();
      """;

      final result = await _controller.runJavaScriptReturningResult(jsCode);
      var rawToken = result.toString().replaceAll(r'\"', '');
      final token = DiscordService.sanitizeToken(rawToken);

      if (token.isNotEmpty &&
          token != 'null' &&
          token != 'undefined' &&
          !_rejectedTokens.contains(token) &&
          DiscordService.looksLikeDiscordToken(token)) {
        final verified = await DiscordService().verifyToken(token);
        if (verified == false) {
          _rejectedTokens.add(token);
          return;
        }
        if (verified == true) {
          _tokenFound = true;
          _tokenCheckTimer?.cancel();

          DiscordService().setToken(token);

          if (mounted) {
            Navigator.of(context).pop(true);
            ScaffoldMessenger.of(context).showSnackBar(
              snackbar(
                context,
                "discordLoginSuccess".tr,
                size: SanckBarSize.BIG,
              ),
            );
          }
        }
      }
    } catch (_) {
    } finally {
      _isCheckingToken = false;
    }
  }

  @override
  void dispose() {
    _tokenCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101422),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFF5865F2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.discord_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              "discordLoginTitle".tr,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
        bottom: _isLoading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5865F2)),
                  minHeight: 2,
                ),
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF161A2B),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline_rounded, color: Color(0xFF5865F2), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "discordLoginHint".tr,
                      style: TextStyle(fontSize: 11.5, color: Colors.white.withOpacity(0.75)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: WebViewWidget(controller: _controller),
            ),
          ],
        ),
      ),
    );
  }
}

