part of openidconnect;

class OpenIdConnectAndroidiOS {

  static Future<String> authorizeInteractive({
    required BuildContext context,
    required String title,
    required String authorizationUrl,
    required String redirectUrl,
    required int popupWidth,
    required int popupHeight,
    Function? cookiesCallback,
  }) async {
    final cookieManager = CookieManager.WebviewCookieManager();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return flutterWebView.WebView(
          javascriptMode: flutterWebView.JavascriptMode.unrestricted,
          initialUrl: authorizationUrl,
          onPageFinished: (url) async {
            final cookies = await cookieManager.getCookies(url);
            if (cookies.isNotEmpty) {
              cookiesCallback?.call(cookies);
            }
            if (url.startsWith(redirectUrl)) {
              Navigator.of(context, rootNavigator: true).pop(url);
            }
          },
        );
      },
    );

    if (result == null) throw AuthenticationException(ERROR_USER_CLOSED);

    return result;
  }
}
