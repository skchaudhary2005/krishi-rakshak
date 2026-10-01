import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const KrishiRakshakApp());
}

class KrishiRakshakApp extends StatelessWidget {
  const KrishiRakshakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Krishi Rakshak',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const KrishiRakshakWebView(),
    );
  }
}

class KrishiRakshakWebView extends StatefulWidget {
  const KrishiRakshakWebView({super.key});

  @override
  State<KrishiRakshakWebView> createState() => _KrishiRakshakWebViewState();
}

class _KrishiRakshakWebViewState extends State<KrishiRakshakWebView> {
  late final WebViewController controller;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted);

    _setupAndroidWebView();

    controller.loadRequest(
      Uri.parse('https://krishi-rakshak-mobile.onrender.com'),
    );
  }

  void _setupAndroidWebView() {
    final platformController = controller.platform;

    if (platformController is AndroidWebViewController) {
      platformController.setAllowFileAccess(true);
      platformController.setAllowContentAccess(true);

      platformController.setOnShowFileSelector(
        (FileSelectorParams params) async {
          final picker = ImagePicker();

          if (params.mode == FileSelectorMode.openMultiple) {
            final images = await picker.pickMultiImage();
            return images
                .map((image) => Uri.file(image.path).toString())
                .toList();
          }

          final image =
              await picker.pickImage(source: ImageSource.gallery);

          if (image == null) {
            return <String>[];
          }

          return <String>[Uri.file(image.path).toString()];
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: WebViewWidget(controller: controller),
      ),
    );
  }
}
