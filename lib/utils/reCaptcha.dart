import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';
import 'package:newpipeextractor_dart/utils/httpClient.dart';
import 'package:newpipeextractor_dart/utils/navigationService.dart';

bool _resolvingCaptcha = false;

class ReCaptchaPage extends StatefulWidget {
  const ReCaptchaPage({super.key});

  static Future<dynamic> checkInfo(
      info, Future<dynamic> Function() task) async {
    if (info == null) return [];
    if ((info as Map).containsKey("error")) {
      if (info["error"].contains("reCaptcha")) {
        if (!_resolvingCaptcha) {
          _resolvingCaptcha = true;
          final String url = info["error"].split(":").last.trim();
          await NavigationService.instance.navigateTo("reCaptcha", "http:$url");
          final newInfo = await task();
          _resolvingCaptcha = false;
          return newInfo;
        }
      }
    } else {
      return info;
    }
  }

  @override
  _ReCaptchaPageState createState() => _ReCaptchaPageState();
}

class _ReCaptchaPageState extends State<ReCaptchaPage> {
  InAppWebViewController? controller;
  String foundCookies = "";

  @override
  Widget build(BuildContext context) {
    final String url = ModalRoute.of(context)!.settings.arguments as String;
    return Material(
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          title: ListTile(
            title:
                const Text("reCaptcha", style: TextStyle(color: Colors.white)),
            subtitle: Text("Solve the reCaptcha and confirm",
                style: TextStyle(color: Colors.white.withOpacity(0.6))),
          ),
          backgroundColor: Colors.redAccent,
          actions: [
            IconButton(
              icon: const Icon(Icons.check_rounded),
              color: Colors.white,
              onPressed: () async {
                final String currentUrl =
                    await (controller?.getUrl() as FutureOr<String?>) ?? url;
                final info = await NewPipeExtractorDart.execute(
                    'getCookieByUrl', {"url": currentUrl});
                String? cookies = info['cookie'];
                handleCookies(cookies);
                // Sometimes cookies are inside the url
                final int abuseStart = currentUrl.indexOf("google_abuse=");
                if (abuseStart != -1) {
                  final int abuseEnd = currentUrl.indexOf("+path");
                  try {
                    String? abuseCookie =
                        currentUrl.substring(abuseStart + 12, abuseEnd);
                    abuseCookie = await (NewPipeExtractorDart.execute(
                            'decodeCookie', {"cookie": abuseCookie})
                        as FutureOr<String>);
                    handleCookies(abuseCookie);
                  } catch (_) {}
                }
                await NewPipeExtractorDart.execute(
                    'setCookie', {"cookie": foundCookies});
                Navigator.pop(context);
              },
            ),
          ],
        ),
        body: InAppWebView(
          initialUrlRequest: URLRequest(
              url: Uri.parse(url), headers: ExtractorHttpClient.defaultHeaders),
          onLoadStop: (cont, _) {
            controller = cont;
          },
        ),
      ),
    );
  }

  void handleCookies(String? cookies) {
    if (cookies == null) {
      return;
    }
    if (cookies.contains("s_gl=") ||
        cookies.contains("goojf=") ||
        cookies.contains("VISITOR_INFO1_LIVE=") ||
        cookies.contains("GOOGLE_ABUSE_EXEMPTION=")) {
      if (foundCookies.contains(cookies)) {
        return;
      }
      if (foundCookies.isEmpty || foundCookies.endsWith("; ")) {
        foundCookies += cookies;
      } else if (foundCookies.endsWith(";")) {
        foundCookies += " $cookies";
      } else {
        foundCookies += "; $cookies";
      }
    }
  }
}
