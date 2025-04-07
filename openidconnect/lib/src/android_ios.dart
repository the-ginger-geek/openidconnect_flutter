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
  flutterWebView.WebViewController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  bool _hasPopped = false;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  @override
  void dispose() {
    // Clear controller reference when disposed
    _controller = null;
    super.dispose();
  }

  void _initializeWebView() {
    _controller = flutterWebView.WebViewController()
      ..setJavaScriptMode(flutterWebView.JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        flutterWebView.NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
              });
            }
          },
          onPageFinished: (String url) async {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }

            final cookies = await CookieManager.WebviewCookieManager().getCookies(url);
            if (cookies.isNotEmpty) {
              widget.cookiesCallback?.call(cookies);
            }

            if (url.startsWith(widget.redirectUrl)) {
              if (mounted && !_hasPopped) {
                _hasPopped = true;
                Navigator.of(context).pop(url); // Return result and close overlay
              }
            }
          },
          onWebResourceError: (flutterWebView.WebResourceError error) {
            if (mounted) {
              setState(() {
                _hasError = true;
                _isLoading = false;
              });
            }
          },
          onNavigationRequest: (flutterWebView.NavigationRequest request) {
            if (request.url.startsWith(widget.redirectUrl)) {
              if (mounted && !_hasPopped) {
                _hasPopped = true;
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
                if (_hasError)
                  IconButton(
                    icon: Icon(Icons.refresh, color: Colors.black),
                    onPressed: () {
                      if (_controller != null) {
                        setState(() {
                          _hasError = false;
                          _isLoading = true;
                        });
                        _controller!.reload();
                      }
                    },
                  ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.black),
                  onPressed: () => Navigator.of(context).pop(), // Close overlay
                ),
              ],
            ),
            body: Stack(
              children: [
                if (_controller != null)
                  flutterWebView.WebViewWidget(controller: _controller!),
                if (_isLoading)
                  Center(
                    child: CircularProgressIndicator(),
                  ),
                if (_hasError)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.black),
                        SizedBox(height: 16),
                        Text(
                          "An error occurred while loading the page.",
                          style: TextStyle(fontSize: 16),
                        ),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            if (_controller != null) {
                              setState(() {
                                _hasError = false;
                                _isLoading = true;
                              });
                              _controller!.reload();
                            }
                          },
                          child: Text("Retry"),
                        )
                      ],
                    ),
                  )
              ],
            ),
          ),
        ),
      ),
    );
  }
}