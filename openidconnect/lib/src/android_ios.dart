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
    final cookieManager = CookieManager.WebviewCookieManager();
    final controller = flutterWebView.WebViewController()
      ..setJavaScriptMode(flutterWebView.JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        flutterWebView.NavigationDelegate(
          onPageFinished: (String url) async {
            final cookies = await cookieManager.getCookies(url);
            if (cookies.isNotEmpty) {
              cookiesCallback?.call(cookies);
            }
            if (url.startsWith(redirectUrl)) {
              Navigator.of(context, rootNavigator: true).pop(url);
            }
          },
          onNavigationRequest: (flutterWebView.NavigationRequest request) {
            // Because of a bug on the flutter webview we have to use the navigateionDelegate
            // callback to catch the redirect URL for iOS and the onPageFinished callback
            // for android.
            if (request.url.startsWith(redirectUrl) && Platform.isIOS) {
              Navigator.of(context, rootNavigator: true).pop(request.url);
              return flutterWebView.NavigationDecision.prevent;
            }

            return flutterWebView.NavigationDecision.navigate;
          },
        ),
      )..loadRequest(Uri.parse(authorizationUrl));

    final result = await showDialog<String>(
      context: context,
      useSafeArea: false,
      barrierDismissible: true,
      barrierColor: hideWebView ? Colors.transparent : Colors.black.withOpacity(0.3),
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
                height: MediaQuery.of(context).size.height - (Platform.isIOS ? 130 : 105),
                child: flutterWebView.WebViewWidget(controller: controller),
              ),
            ],
          ),
        );
      },
    );

    if (result == null) throw AuthenticationException(ERROR_USER_CLOSED);

    return result;
  }
}