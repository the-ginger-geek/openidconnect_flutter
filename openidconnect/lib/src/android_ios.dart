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
    bool hideWebView = false,
  }) async {
    final result = await showDialog<String>(
      context: context,
      useSafeArea: false,
      barrierDismissible: true,
      barrierColor:
          hideWebView ? Colors.transparent : Colors.black.withOpacity(0.3),
      builder: (dialogContext) {
        return Visibility(
          visible: !hideWebView,
          maintainState: true,
          maintainSize: true,
          maintainAnimation: true,
          maintainInteractivity: true,
          maintainSemantics: true,
          child: Column(
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
              Container(
                color: Colors.white,
                height: MediaQuery.of(context).size.height -
                    (Platform.isIOS ? 130 : 105),
                child: flutterWebView.WebViewWidget(
                  controller: _webViewController(
                    cookiesCallback,
                    redirectUrl,
                    context,
                    authorizationUrl,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (result == null) throw AuthenticationException(ERROR_USER_CLOSED);

    return result;
  }

  static flutterWebView.WebViewController _webViewController(
      Function? cookiesCallback,
      String redirectUrl,
      BuildContext context,
      String authorizationUrl) {
    return flutterWebView.WebViewController()
      ..setJavaScriptMode(flutterWebView.JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        // Because of a bug on the flutter WebView we have to use the navigationDelegate
        // callback to catch the redirect URL for iOS and the onPageFinished callback
        // for android.
        flutterWebView.NavigationDelegate(
          onPageFinished: (String url) async {
            final cookies =
                await CookieManager.WebviewCookieManager().getCookies(url);
            if (cookies.isNotEmpty) {
              cookiesCallback?.call(cookies);
            }

            if (Platform.isAndroid && url.startsWith(redirectUrl)) {
              if (context.mounted) {
                Navigator.of(context, rootNavigator: true).pop(url);
              }
            }
          },
          onNavigationRequest: (flutterWebView.NavigationRequest request) {
            if (request.url.startsWith(redirectUrl) && Platform.isIOS) {
              if (context.mounted) {
                Navigator.of(context, rootNavigator: true).pop(request.url);
              }
              return flutterWebView.NavigationDecision.prevent;
            }

            return flutterWebView.NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(authorizationUrl));
  }
}
