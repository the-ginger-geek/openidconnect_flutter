part of openidconnect;

class OpenIdConnectAndroidiOS {
  static Future<String> authorizeInteractive({
    required BuildContext context,
    required String title,
    required String authorizationUrl,
    required String redirectUrl,
    required int popupWidth,
    required int popupHeight,
    Color? appBarBackgroundColor,
    Color? appBarForegroundColor,
    Function? cookiesCallback,
  }) async {
    final cookieManager = CookieManager.WebviewCookieManager();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return Column(
          children: [
            AppBar(
              foregroundColor: appBarForegroundColor,
              backgroundColor: appBarBackgroundColor,
              actions: [
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ],
              title: Text(authorizationUrl, overflow: TextOverflow.ellipsis),
              centerTitle: true,
              automaticallyImplyLeading: false,
            ),
            SizedBox(
              height: MediaQuery.of(context).size.height - (Platform.isIOS ? 103 : 98),
              child: flutterWebView.WebView(
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
              ),
            ),
          ],
        );
      },
    );

    if (result == null) throw AuthenticationException(ERROR_USER_CLOSED);

    return result;
  }
}
