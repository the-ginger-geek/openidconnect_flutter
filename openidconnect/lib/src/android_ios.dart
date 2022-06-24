part of openidconnect;

class OpenIdConnectAndroidiOS {
  static Future<String> authorizeInteractive({
    required BuildContext context,
    required String title,
    required String authorizationUrl,
    required String redirectUrl,
    Color? appBarBackgroundColor,
    Color? appBarForegroundColor,
    Function? cookiesCallback,
  }) async {
    final cookieManager = CookieManager.WebviewCookieManager();
    final result = await showDialog<String>(
      context: context,
      useSafeArea: false,
      builder: (dialogContext) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Material(
              color: Colors.transparent,
              child: Container(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width * 0.6,
                        height: 65,
                        child: Center(
                          child: Text(
                            authorizationUrl,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.0,
                              color: appBarForegroundColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      color: appBarForegroundColor,
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
                decoration: BoxDecoration(
                  color: appBarBackgroundColor,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(15),
                    topRight: Radius.circular(15),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: MediaQuery.of(context).size.height - (Platform.isIOS ? 130 : 105),
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
                navigationDelegate: (flutterWebView.NavigationRequest request) {
                  if (request.url.startsWith(redirectUrl)) {
                    Navigator.of(context, rootNavigator: true).pop(request.url);
                    return flutterWebView.NavigationDecision.prevent;
                  }

                  return flutterWebView.NavigationDecision.navigate;
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