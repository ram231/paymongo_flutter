import 'dart:async';

import 'package:flutter/material.dart';
import 'package:paymongo_sdk/paymongo_sdk.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

enum PaymentStatus { success, failed, cancelled }

class PayMongoWebPayment extends StatefulWidget {
  final String url;
  const PayMongoWebPayment({
    required this.url,
    Key? key,
  }) : super(key: key);

  @override
  _PayMongoWebPaymentState createState() => _PayMongoWebPaymentState();
}

class _PayMongoWebPaymentState extends State<PayMongoWebPayment> {
  final Completer<WebViewController> completer = Completer();
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, PaymentStatus.cancelled);
        return false;
      },
      child: SafeArea(
        child: Scaffold(
          body: WebView(
            onWebViewCreated: (controller) {
              completer.complete(controller);

              showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text("Notice"),
                      content: const Text(
                        "We are not liable of any disconnection or loss of data after this transaction.",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      actions: [
                        TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text("CLOSE")),
                      ],
                    );
                  });
            },
            javascriptMode: JavascriptMode.unrestricted,
            initialUrl: widget.url,
            navigationDelegate: (request) {
              if (request.url.contains('success')) {
                Navigator.pop(context, PaymentStatus.success);
                return NavigationDecision.prevent;
              } else if (request.url.contains('failed')) {
                Navigator.pop(context, PaymentStatus.failed);
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            },
          ),
        ),
      ),
    );
  }
}

class PayMongoFlutter extends PayMongoSDK {
  PayMongoFlutter(String secret) : super(secret);

  Future<bool> createGCashPayment(
    BuildContext context,
    Source data, {
    bool useWebView = true,
  }) async {
    try {
      final source = await createSource(data);
      final link = source.attributes?.redirect.checkoutUrl ?? "";
      if (link.isNotEmpty) {
        if (!useWebView) {
          return _openURL(link);
        } else {
          final result = await _showWebView(context, link);

          switch (result) {
            case PaymentStatus.cancelled:
              return false;
            case PaymentStatus.failed:
              return false;
            case PaymentStatus.success:
              return true;
            default:
              return false;
          }
        }
      } else {
        throw "URL NOT FOUND";
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> _openURL(String link) async {
    if (await canLaunch(link)) {
      return await launch(
        link,
        forceWebView: true,
        forceSafariVC: true,
      );
    }
    return false;
  }

  Future<PaymentStatus> _showWebView(BuildContext context, String link) async {
    final PaymentStatus result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return PayMongoWebPayment(url: link);
        },
      ),
    );
    return result;
  }
}
