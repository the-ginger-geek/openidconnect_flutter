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
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      barrierColor: hideWebView ? Colors.transparent : null,
      backgroundColor: Colors.transparent, // Transparent for rounded corners
      builder: (BuildContext context) {
        return OpenIdConnectOverlay(
          title: title,
          authorizationUrl: authorizationUrl,
          redirectUrl: redirectUrl,
          appBarBackgroundColor: appBarBackgroundColor,
          appBarForegroundColor: appBarForegroundColor,
          cookiesCallback: cookiesCallback,
          hideWebView: hideWebView,
        );
      },
    );

    if (result == null) throw AuthenticationException(ERROR_USER_CLOSED);
    return result;
  }
}

class OpenIdConnectOverlay extends StatefulWidget {
  final String title;
  final String authorizationUrl;
  final String redirectUrl;
  final Color? appBarBackgroundColor;
  final Color? appBarForegroundColor;
  final Function? cookiesCallback;
  final bool hideWebView;

  const OpenIdConnectOverlay({
    Key? key,
    required this.title,
    required this.authorizationUrl,
    required this.redirectUrl,
    this.appBarBackgroundColor,
    this.appBarForegroundColor,
    this.cookiesCallback,
    this.hideWebView = false,
  }) : super(key: key);

  @override
  _OpenIdConnectOverlayState createState() => _OpenIdConnectOverlayState();
}

class _OpenIdConnectOverlayState extends State<OpenIdConnectOverlay> {
  late flutterWebView.WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = flutterWebView.WebViewController()
      ..setJavaScriptMode(flutterWebView.JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        flutterWebView.NavigationDelegate(
          onPageFinished: (String url) async {
            final cookies = await CookieManager.WebviewCookieManager().getCookies(url);
            if (cookies.isNotEmpty) {
              widget.cookiesCallback?.call(cookies);
            }

            if (url.startsWith(widget.redirectUrl)) {
              if (mounted) {
                Navigator.of(context).pop(url); // Return result and close overlay
              }
            }
          },
          onNavigationRequest: (flutterWebView.NavigationRequest request) {
            if (request.url.startsWith(widget.redirectUrl)) {
              if (mounted) {
                Navigator.of(context).pop(request.url); // Return result
              }
              return flutterWebView.NavigationDecision.prevent;
            }
            return flutterWebView.NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authorizationUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: !widget.hideWebView,
      child: FractionallySizedBox(
        heightFactor: 0.9, // 90% of screen height
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(15)), // Rounded top corners
          child: Scaffold(
            appBar: AppBar(
              backgroundColor: widget.appBarBackgroundColor ?? Colors.white,
              foregroundColor: widget.appBarForegroundColor ?? Colors.black,
              automaticallyImplyLeading: false, // No back button
              title: Text(
                widget.authorizationUrl,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.close, color: Colors.black),
                  onPressed: () => Navigator.of(context).pop(), // Close overlay
                ),
              ],
            ),
            body: flutterWebView.WebViewWidget(controller: _controller),
          ),
        ),
      ),
    );
  }
}
