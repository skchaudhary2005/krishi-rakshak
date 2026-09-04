import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_litert/flutter_litert.dart';

import '../language.dart';
import 'ai_chat_screen.dart';

class DiseaseDetectionScreen extends StatefulWidget {
  const DiseaseDetectionScreen({super.key});

  @override
  State<DiseaseDetectionScreen> createState() =>
      _DiseaseDetectionScreenState();
}

class _DiseaseDetectionScreenState extends State<DiseaseDetectionScreen> {
  static const String backendUrl = 'https://krishi-rakshak-vtla.onrender.com';

  static const int modelInputSize = 224;
  static const int expectedClasses = 192;

  static const String pendingKey = 'pending_government_alerts';
  static const String historyKey = 'prediction_history';
  static const String forceOfflineKey = 'force_offline_ai';

  final ImagePicker picker = ImagePicker();

  Interpreter? _interpreter;
  List<String> _classes = [];

  bool modelLoading = true;
  bool analyzing = false;
  bool syncing = false;
  bool forceOffline = false;

  XFile? image;
  Uint8List? imageBytes;

  String disease = '';
  double confidence = 0;
  String crop = '';
  String severity = '';
  String description = '';
  String treatment = '';
  String prevention = '';
  String farmerAction = '';
  String analysisMode = '';
  String predictionId = '';
  String governmentAlertId = '';

  @override
  void initState() {
    super.initState();
    _loadOfflineModel();
    _loadModeSetting();
    _syncPendingAlerts();
  }


  Future<void> _loadModeSetting() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      forceOffline = prefs.getBool(forceOfflineKey) ?? false;
    });
  }

  Future<void> _loadOfflineModel() async {
    try {
      debugPrint('==========================================');
      debugPrint('LOADING 192-CLASS OFFLINE TFLITE MODEL');
      debugPrint('==========================================');

      await initializeWeb();

      _interpreter = await Interpreter.fromAsset(
        'assets/models/krishi_rakshak.tflite',
      );

      final jsonString = await rootBundle.loadString(
        'assets/classes/classes.json',
      );

      final decoded = jsonDecode(jsonString);

      if (decoded is List) {
        _classes = decoded.map((e) => e.toString()).toList();
      } else if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        _classes = List.generate(
          map.length,
          (i) => map[i.toString()].toString(),
        );
      } else {
        throw Exception('Unsupported classes.json format');
      }

      final inputTensor = _interpreter!.getInputTensor(0);
      final outputTensor = _interpreter!.getOutputTensor(0);

      debugPrint('Input shape: ${inputTensor.shape}');
      debugPrint('Input type: ${inputTensor.type}');
      debugPrint('Output shape: ${outputTensor.shape}');
      debugPrint('Output type: ${outputTensor.type}');
      debugPrint('Classes: ${_classes.length}');

      if (_classes.length != expectedClasses) {
        throw Exception(
          'Expected $expectedClasses classes but found ${_classes.length}. '
          'Copy the new 192-class classes.json into assets/classes/.',
        );
      }

      if (inputTensor.shape.length != 4 ||
          inputTensor.shape[0] != 1 ||
          inputTensor.shape[1] != modelInputSize ||
          inputTensor.shape[2] != modelInputSize ||
          inputTensor.shape[3] != 3) {
        throw Exception(
          'Unexpected input shape: ${inputTensor.shape}. '
          'Expected [1,224,224,3].',
        );
      }

      if (outputTensor.shape.isEmpty ||
          outputTensor.shape.last != expectedClasses) {
        throw Exception(
          'Unexpected output shape: ${outputTensor.shape}. '
          'Expected 192 classes.',
        );
      }

      if (!mounted) return;

      setState(() {
        modelLoading = false;
      });

      debugPrint('OFFLINE 192-CLASS MODEL READY');
    } catch (e) {
      debugPrint('OFFLINE MODEL LOAD ERROR: $e');

      if (!mounted) return;

      setState(() {
        modelLoading = false;
      });

      message(
        'Offline 192-class AI model could not be loaded. '
        'Check that the new TFLite and classes.json are copied.',
      );
    }
  }

  Future<void> choose(ImageSource source) async {
    try {
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 90,
      );

      if (picked == null || !mounted) return;

      final pickedBytes = await picked.readAsBytes();

      setState(() {
        image = picked;
        imageBytes = pickedBytes;
        disease = '';
        confidence = 0;
        crop = '';
        severity = '';
        description = '';
        treatment = '';
        prevention = '';
        farmerAction = '';
        analysisMode = '';
        predictionId = '';
        governmentAlertId = '';
      });
    } catch (e) {
      debugPrint('IMAGE PICK ERROR: $e');

      if (!mounted) return;

      message(
        source == ImageSource.camera
            ? tr(context, 'cameraError')
            : tr(context, 'galleryError'),
      );
    }
  }

  Future<void> analyze() async {
    if (image == null) {
      message(tr(context, 'select'));
      return;
    }

    if (analyzing) return;

    setState(() {
      analyzing = true;
      analysisMode = '';
      governmentAlertId = '';
    });

    debugPrint('==========================================');
    debugPrint('KRISHI RAKSHAK AI ANALYSIS');
    debugPrint('==========================================');

    if (forceOffline) {
      debugPrint('FORCE OFFLINE AI ENABLED - SKIPPING SERVER');
    } else {
      try {
        await _analyzeOnline();

        if (!mounted) return;

        setState(() {
          analyzing = false;
          analysisMode = 'ONLINE';
        });

        showResult();
        return;
      } catch (e) {
        debugPrint('ONLINE ANALYSIS FAILED: $e');
        debugPrint('Falling back to OFFLINE TFLite...');
      }
    }

    try {
      await _analyzeOffline();

      if (!mounted) return;

      setState(() {
        analyzing = false;
        analysisMode = 'OFFLINE';
      });

      showResult();
    } catch (e) {
      debugPrint('OFFLINE ANALYSIS FAILED: $e');

      if (!mounted) return;

      setState(() {
        analyzing = false;
      });

      message(
        'AI analysis failed in both online and offline mode.',
      );
    }
  }

  Future<void> _analyzeOnline() async {
    final lang = LanguageScope.of(context).value;

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$backendUrl/api/predict'),
    );

    request.fields['language'] = lang;

    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        await image!.readAsBytes(),
        filename: image!.name,
      ),
    );

    final response = await request.send().timeout(
      const Duration(seconds: 120),
    );

    final body = await http.Response.fromStream(response);

    debugPrint('ONLINE HTTP: ${response.statusCode}');
    debugPrint('ONLINE RESPONSE: ${body.body}');

    if (response.statusCode != 200) {
      throw Exception(
        'Backend ${response.statusCode}: ${body.body}',
      );
    }

    final decoded = jsonDecode(body.body);

    if (decoded is! Map) {
      throw Exception('Invalid backend JSON');
    }

    final data = Map<String, dynamic>.from(decoded);

    if (data['success'] == false) {
      throw Exception(
        data['error']?.toString() ?? 'Online prediction failed',
      );
    }

    final prediction = data['prediction'];

    if (prediction is! Map) {
      throw Exception('Missing prediction object');
    }

    final p = Map<String, dynamic>.from(prediction);

    final detectedDisease =
        p['class_name']?.toString() ??
        p['disease']?.toString() ??
        'Unknown';

    final detectedConfidence = _toPercent(
      p['confidence'],
    );

    final detectedSeverity =
        p['severity']?.toString() ?? '';

    final onlinePredictionId =
        data['prediction_id']?.toString() ?? '';

    final governmentAlert = data['government_alert'];

    String alertId = '';

    if (governmentAlert is Map) {
      alertId =
          governmentAlert['alert_id']?.toString() ?? '';
    }

    final detectedCrop = _extractCrop(
      detectedDisease,
    );

    if (!mounted) return;

    setState(() {
      disease = detectedDisease;
      confidence = detectedConfidence;
      crop = detectedCrop;
      severity = detectedSeverity;
      predictionId = onlinePredictionId;
      governmentAlertId = alertId;

      description = _descriptionFor(detectedDisease);
      treatment = _treatmentFor(detectedDisease);
      prevention = _preventionFor(detectedDisease);
      farmerAction = _farmerActionFor(detectedDisease);
    });

    await _fetchOnlineAdvice(
      detectedDisease,
      detectedCrop,
      detectedConfidence,
    );

    await _saveHistory(
      predictionId: onlinePredictionId,
      className: detectedDisease,
      confidence: detectedConfidence,
      crop: detectedCrop,
      severity: detectedSeverity,
      mode: 'ONLINE',
      governmentAlert: alertId.isNotEmpty,
    );
  }

  Future<void> _fetchOnlineAdvice(
    String detectedDisease,
    String detectedCrop,
    double detectedConfidence,
  ) async {
    final lang = LanguageScope.of(context).value;
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/advice'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'disease': detectedDisease,
          'crop': detectedCrop,
          'confidence': detectedConfidence,
          'language': lang,
        }),
      ).timeout(const Duration(seconds: 40));

      debugPrint('AI ADVICE HTTP: ${response.statusCode}');
      debugPrint('AI ADVICE RESPONSE: ${response.body}');

      if (response.statusCode != 200) return;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return;
      final advice = decoded['advice'];
      if (advice is! Map) return;

      if (!mounted) return;
      setState(() {
        final desc = advice['description']?.toString().trim() ?? '';
        final treat = advice['treatment']?.toString().trim() ?? '';
        final prev = advice['prevention']?.toString().trim() ?? '';
        final action = advice['farmer_action']?.toString().trim() ?? '';
        if (desc.isNotEmpty) description = desc;
        if (treat.isNotEmpty) treatment = treat;
        if (prev.isNotEmpty) prevention = prev;
        if (action.isNotEmpty) farmerAction = action;
      });
    } catch (e) {
      debugPrint('AI ADVICE FAILED: $e');
      debugPrint('LOCAL DISEASE-SPECIFIC ADVICE REMAINS ACTIVE.');
    }
  }

  Future<void> _analyzeOffline() async {
    if (_interpreter == null) {
      throw Exception('Offline TFLite model unavailable');
    }

    if (_classes.length != expectedClasses) {
      throw Exception(
        'Offline classes are not 192. Found ${_classes.length}.',
      );
    }

    final bytes = await image!.readAsBytes();
    final decodedImage = img.decodeImage(bytes);

    if (decodedImage == null) {
      throw Exception('Could not decode selected image');
    }

    final resized = img.copyResize(
      decodedImage,
      width: modelInputSize,
      height: modelInputSize,
      interpolation: img.Interpolation.linear,
    );

    // IMPORTANT:
    // The new TFLite model already contains MobileNetV2 preprocessing.
    // Feed RAW 0-255 float32 pixels. Do NOT divide by 255 here.
    final input = [
      List.generate(
        modelInputSize,
        (y) => List.generate(
          modelInputSize,
          (x) {
            final pixel = resized.getPixel(x, y);
            return [
              pixel.r.toDouble(),
              pixel.g.toDouble(),
              pixel.b.toDouble(),
            ];
          },
        ),
      ),
    ];

    final output = [
      List<double>.filled(
        expectedClasses,
        0.0,
      ),
    ];

    _interpreter!.run(input, output);

    final probabilities = output[0];

    int bestIndex = 0;

    for (int i = 1; i < probabilities.length; i++) {
      if (probabilities[i] > probabilities[bestIndex]) {
        bestIndex = i;
      }
    }

    if (bestIndex >= _classes.length) {
      throw Exception('Invalid class index: $bestIndex');
    }

    final bestProbability = probabilities[bestIndex];

    final predictedClass = _classes[bestIndex];
    final predictedCrop = _extractCrop(predictedClass);
    final predictedSeverity = _calculateSeverity(
      predictedClass,
      bestProbability * 100,
    );

    final offlinePredictionId =
        'offline-${DateTime.now().millisecondsSinceEpoch}';

    if (!mounted) return;

    setState(() {
      disease = predictedClass;
      crop = predictedCrop;
      confidence = bestProbability * 100;
      severity = predictedSeverity;
      predictionId = offlinePredictionId;

      description = _descriptionFor(predictedClass);
      treatment = _treatmentFor(predictedClass);
      prevention = _preventionFor(predictedClass);
      farmerAction = _farmerActionFor(predictedClass);
    });

    final shouldAlert = _governmentAlertRequired(
      predictedClass,
      confidence,
      predictedSeverity,
    );

    if (shouldAlert) {
      await _savePendingAlert(
        predictionId: offlinePredictionId,
        classId: bestIndex,
        className: predictedClass,
        confidence: confidence,
        severity: predictedSeverity,
      );
    }

    await _saveHistory(
      predictionId: offlinePredictionId,
      className: predictedClass,
      confidence: confidence,
      crop: predictedCrop,
      severity: predictedSeverity,
      mode: 'OFFLINE',
      governmentAlert: shouldAlert,
    );

    debugPrint('OFFLINE RESULT');
    debugPrint('Class: $predictedClass');
    debugPrint('Class ID: $bestIndex');
    debugPrint('Confidence: ${confidence.toStringAsFixed(2)}%');
    debugPrint('Severity: $predictedSeverity');
    debugPrint('Government alert queued: $shouldAlert');
  }

  Future<void> _saveHistory({
    required String predictionId,
    required String className,
    required double confidence,
    required String crop,
    required String severity,
    required String mode,
    required bool governmentAlert,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(historyKey) ?? [];

      final entry = {
        'prediction_id': predictionId,
        'class_name': className,
        'confidence': confidence,
        'crop': crop,
        'severity': severity,
        'mode': mode,
        'government_alert': governmentAlert,
        'created_at': DateTime.now().toIso8601String(),
      };

      raw.insert(0, jsonEncode(entry));

      // Keep the most recent 100 predictions.
      final limited = raw.take(100).toList();
      await prefs.setStringList(historyKey, limited);

      debugPrint('HISTORY SAVED. Total records: ${limited.length}');
    } catch (e) {
      debugPrint('HISTORY SAVE FAILED: $e');
    }
  }

  String _selectedLanguage() => LanguageScope.of(context).value;

  String _descriptionFor(String diseaseName) {
    final n = diseaseName.toLowerCase();
    final lang = _selectedLanguage();
    if (_isHealthy(n)) return _localized(lang, 'healthy_desc');
    if (n.contains('virus') || n.contains('viral') || n.contains('mosaic') || n.contains('yellow leaf curl')) {
      return _localized(lang, 'virus_desc');
    }
    if (n.contains('bacterial') || n.contains('canker')) return _localized(lang, 'bacterial_desc');
    if (n.contains('fung') || n.contains('blight') || n.contains('scab') || n.contains('rust') || n.contains('rot') || n.contains('curl') || n.contains('leaf spot')) {
      return _localized(lang, 'fungal_desc');
    }
    return _localized(lang, 'generic_desc');
  }

  String _treatmentFor(String diseaseName) {
    final n = diseaseName.toLowerCase();
    final lang = _selectedLanguage();
    if (_isHealthy(n)) return _localized(lang, 'healthy_treat');
    if (n.contains('virus') || n.contains('viral') || n.contains('mosaic') || n.contains('yellow leaf curl')) {
      return _localized(lang, 'virus_treat');
    }
    if (n.contains('canker') || n.contains('bacterial')) return _localized(lang, 'bacterial_treat');
    if (n.contains('late blight') || n.contains('early blight')) return _localized(lang, 'blight_treat');
    if (n.contains('scab')) return _localized(lang, 'scab_treat');
    if (n.contains('rust')) return _localized(lang, 'rust_treat');
    if (n.contains('rot')) return _localized(lang, 'rot_treat');
    if (n.contains('wilt')) return _localized(lang, 'wilt_treat');
    if (n.contains('fung') || n.contains('leaf spot') || n.contains('powdery') || n.contains('downy') || n.contains('curl')) return _localized(lang, 'fungal_treat');
    return _localized(lang, 'generic_treat');
  }

  String _preventionFor(String diseaseName) {
    final n = diseaseName.toLowerCase();
    final lang = _selectedLanguage();
    if (_isHealthy(n)) return _localized(lang, 'healthy_prev');
    if (n.contains('virus') || n.contains('viral') || n.contains('mosaic') || n.contains('yellow leaf curl')) return _localized(lang, 'virus_prev');
    if (n.contains('canker') || n.contains('bacterial')) return _localized(lang, 'bacterial_prev');
    if (n.contains('wilt')) return _localized(lang, 'wilt_prev');
    if (n.contains('fung') || n.contains('blight') || n.contains('scab') || n.contains('rust') || n.contains('rot') || n.contains('leaf spot') || n.contains('powdery') || n.contains('downy')) return _localized(lang, 'fungal_prev');
    return _localized(lang, 'generic_prev');
  }

  String _farmerActionFor(String diseaseName) {
    final n = diseaseName.toLowerCase();
    final lang = _selectedLanguage();
    if (_isHealthy(n)) return _localized(lang, 'healthy_action');
    if (confidence < 70) return _localized(lang, 'low_action');
    if (n.contains('virus') || n.contains('viral') || n.contains('mosaic') || n.contains('yellow leaf curl')) return _localized(lang, 'virus_action');
    return _localized(lang, 'generic_action');
  }

  String _localized(String lang, String key) {
    const d = <String, Map<String, String>>{
      'en': {
        'healthy_desc':'The crop appears healthy according to the AI prediction.',
        'virus_desc':'The prediction indicates a viral disease pattern, which may spread through insect vectors or infected planting material.',
        'bacterial_desc':'The prediction indicates a bacterial disease pattern. Spread can occur through water splash, tools and infected plant material.',
        'fungal_desc':'The prediction indicates a fungal or fungal-like disease pattern that can worsen under prolonged leaf wetness and poor airflow.',
        'generic_desc':'The AI detected a crop disease pattern. Confirm the diagnosis from visible symptoms before applying chemicals.',
        'healthy_treat':'No disease treatment is indicated. Continue normal crop care and regular monitoring.',
        'virus_treat':'Virus diseases generally have no reliable curative spray. Remove severely infected plants when recommended, control confirmed insect vectors, and use healthy planting material.',
        'bacterial_treat':'Remove severely infected material where practical and disinfect tools. If chemical control is required, use only a product currently registered for this crop and confirmed bacterial disease, following its label.',
        'blight_treat':'Remove severely infected leaves and fruit, reduce leaf wetness and improve airflow. If chemical control is needed, use a fungicide registered for the exact crop and disease and follow the current label.',
        'scab_treat':'Remove infected fallen leaves and affected fruit, improve sanitation and canopy airflow. Use only a registered fungicide labelled for the confirmed crop and disease.',
        'rust_treat':'Remove heavily infected leaves where practical and improve airflow. Use only a registered fungicide labelled for the confirmed crop and rust disease.',
        'rot_treat':'Remove rotting fruit or plant tissue and improve drainage and airflow. Avoid wounds and use only a registered treatment for the confirmed crop and disease.',
        'wilt_treat':'Remove severely affected plants where recommended, improve drainage and avoid moving contaminated soil or tools. Confirm whether the wilt is fungal or bacterial before chemical treatment.',
        'fungal_treat':'Remove heavily infected tissue, improve air circulation and reduce prolonged leaf wetness. If spraying is required, use only a currently registered product for the exact crop and disease.',
        'generic_treat':'Confirm the diagnosis first. Then use only a currently registered crop-protection product for the exact crop and disease and follow the product label and local agricultural guidance.',
        'healthy_prev':'Use healthy planting material, balanced irrigation and nutrition, good airflow, field sanitation and regular scouting.',
        'virus_prev':'Use certified healthy planting material, control disease vectors such as whiteflies or aphids, remove infected plants when recommended and control host weeds.',
        'bacterial_prev':'Use clean seed or seedlings, sanitize tools, avoid working when foliage is wet, reduce splash irrigation and remove infected debris.',
        'wilt_prev':'Maintain good drainage, avoid over-irrigation, clean tools and prevent movement of contaminated soil or plant debris between fields.',
        'fungal_prev':'Maintain field sanitation, adequate spacing and airflow, good drainage, careful irrigation and regular scouting. Remove infected debris promptly.',
        'generic_prev':'Use healthy planting material, maintain sanitation, suitable spacing and drainage, avoid unnecessary leaf wetness and inspect the crop regularly.',
        'healthy_action':'Continue normal crop care and inspect the crop regularly for new symptoms.',
        'low_action':'Take a clear close-up photo and check several plants. Because confidence is low, confirm the disease before spraying any chemical.',
        'virus_action':'Inspect nearby plants for similar symptoms and check for insect vectors. Remove severely infected plants when recommended and seek local agricultural advice.',
        'generic_action':'Inspect nearby plants, remove severely affected material where appropriate, improve field hygiene and confirm the diagnosis before spraying.'
      },
      'hi': {
        'healthy_desc':'AI के अनुसार फसल स्वस्थ दिखाई दे रही है।','virus_desc':'परिणाम वायरल रोग की संभावना दिखाता है। यह रोग कीट वाहकों या संक्रमित रोपण सामग्री से फैल सकता है।','bacterial_desc':'परिणाम जीवाणु रोग की संभावना दिखाता है। यह पानी के छींटों, औजारों और संक्रमित पौध सामग्री से फैल सकता है।','fungal_desc':'परिणाम फफूंद जनित रोग की संभावना दिखाता है। लंबे समय तक पत्तियों का गीला रहना और कम हवा का आवागमन रोग बढ़ा सकता है।','generic_desc':'AI ने फसल में रोग की संभावना पहचानी है। रसायन डालने से पहले दिखाई देने वाले लक्षणों से रोग की पुष्टि करें।','healthy_treat':'इस परिणाम के आधार पर किसी रोग उपचार की आवश्यकता नहीं है। सामान्य फसल देखभाल और नियमित निगरानी जारी रखें।','virus_treat':'वायरस रोगों का सामान्यतः कोई भरोसेमंद उपचारात्मक स्प्रे नहीं होता। सलाह के अनुसार गंभीर संक्रमित पौधे हटाएँ, रोग फैलाने वाले कीटों को नियंत्रित करें और स्वस्थ रोपण सामग्री उपयोग करें।','bacterial_treat':'जहाँ संभव हो गंभीर संक्रमित भाग हटाएँ और औजारों को साफ करें। रासायनिक नियंत्रण आवश्यक हो तो केवल इस फसल और पुष्टि किए गए जीवाणु रोग के लिए वर्तमान में पंजीकृत उत्पाद ही लेबल के अनुसार उपयोग करें।','blight_treat':'गंभीर संक्रमित पत्तियाँ और फल हटाएँ, पत्तियों के लंबे समय तक गीले रहने से बचें और हवा का आवागमन बढ़ाएँ। जरूरत होने पर केवल पुष्टि किए गए रोग के लिए पंजीकृत फफूंदनाशी लेबल के अनुसार उपयोग करें।','scab_treat':'गिरी हुई संक्रमित पत्तियाँ और प्रभावित फल हटाएँ, खेत/बाग की सफाई रखें और हवा का आवागमन बढ़ाएँ। केवल पुष्टि की गई फसल और रोग के लिए पंजीकृत फफूंदनाशी उपयोग करें।','rust_treat':'अधिक संक्रमित पत्तियाँ जहाँ संभव हो हटाएँ और हवा का आवागमन बढ़ाएँ। केवल पुष्टि की गई फसल के रस्ट रोग के लिए पंजीकृत फफूंदनाशी उपयोग करें।','rot_treat':'सड़े हुए फल या पौधे के भाग हटाएँ, जल निकासी और हवा का आवागमन सुधारें। पुष्टि किए गए रोग के लिए पंजीकृत उपचार ही उपयोग करें।','wilt_treat':'सलाह के अनुसार गंभीर संक्रमित पौधे हटाएँ, जल निकासी सुधारें और संक्रमित मिट्टी या औजार न फैलाएँ। रसायन से पहले विल्ट का कारण निश्चित करें।','fungal_treat':'अधिक संक्रमित भाग हटाएँ, हवा का आवागमन बढ़ाएँ और पत्तियों के लंबे समय तक गीले रहने से बचें। स्प्रे जरूरी हो तो पुष्टि किए गए रोग के लिए वर्तमान में पंजीकृत उत्पाद ही लें।','generic_treat':'पहले रोग की पुष्टि करें। फिर केवल इस फसल और रोग के लिए वर्तमान में पंजीकृत फसल-सुरक्षा उत्पाद को उसके लेबल और स्थानीय कृषि सलाह के अनुसार उपयोग करें।','healthy_prev':'स्वस्थ रोपण सामग्री, संतुलित सिंचाई व पोषण, अच्छा हवा आवागमन, खेत की सफाई और नियमित निगरानी रखें।','virus_prev':'प्रमाणित स्वस्थ रोपण सामग्री लें, सफेद मक्खी/माहू जैसे वाहक कीटों को नियंत्रित करें, सलाह के अनुसार संक्रमित पौधे हटाएँ और रोग फैलाने वाले खरपतवार नियंत्रित करें।','bacterial_prev':'स्वच्छ बीज/पौध लें, औजार साफ रखें, गीली फसल में काम न करें, पानी के छींटे कम करें और संक्रमित अवशेष हटाएँ।','wilt_prev':'अच्छी जल निकासी रखें, जरूरत से अधिक सिंचाई न करें, औजार साफ रखें और संक्रमित मिट्टी या अवशेष को स्वस्थ खेत में न ले जाएँ।','fungal_prev':'खेत की सफाई, उचित दूरी और हवा का आवागमन, अच्छी जल निकासी, सही सिंचाई और नियमित निगरानी रखें। संक्रमित अवशेष समय पर हटाएँ।','generic_prev':'स्वस्थ रोपण सामग्री लें, खेत साफ रखें, उचित दूरी व जल निकासी रखें, पत्तियों को अनावश्यक रूप से गीला न रखें और नियमित निगरानी करें।','healthy_action':'सामान्य देखभाल जारी रखें और नई बीमारी के लक्षणों के लिए नियमित निरीक्षण करें।','low_action':'पत्ती की साफ नजदीकी फोटो लें और कई पौधों के लक्षण देखें। विश्वसनीयता कम है, इसलिए किसी रसायन के छिड़काव से पहले रोग की पुष्टि करें।','virus_action':'आसपास के पौधों में समान लक्षण देखें और वाहक कीटों की जाँच करें। सलाह के अनुसार गंभीर संक्रमित पौधे हटाएँ और स्थानीय कृषि विशेषज्ञ से सलाह लें।','generic_action':'आसपास के पौधों की जाँच करें, जरूरत के अनुसार गंभीर संक्रमित भाग हटाएँ, खेत की स्वच्छता सुधारें और स्प्रे से पहले रोग की पुष्टि करें।'},
      'pa': {'healthy_desc':'AI ਦੇ ਅਨੁਸਾਰ ਫਸਲ ਸਿਹਤਮੰਦ ਦਿਖਾਈ ਦੇ ਰਹੀ ਹੈ।','virus_desc':'ਨਤੀਜਾ ਵਾਇਰਸ ਰੋਗ ਦੀ ਸੰਭਾਵਨਾ ਦਿਖਾਉਂਦਾ ਹੈ। ਇਹ ਕੀੜੇ ਵਾਹਕਾਂ ਜਾਂ ਸੰਕਰਮਿਤ ਰੋਪਣ ਸਮੱਗਰੀ ਰਾਹੀਂ ਫੈਲ ਸਕਦਾ ਹੈ।','bacterial_desc':'ਨਤੀਜਾ ਬੈਕਟੀਰੀਆ ਰੋਗ ਦੀ ਸੰਭਾਵਨਾ ਦਿਖਾਉਂਦਾ ਹੈ। ਇਹ ਪਾਣੀ ਦੇ ਛਿੱਟਿਆਂ, ਸੰਦਾਂ ਅਤੇ ਸੰਕਰਮਿਤ ਪੌਧੇ ਰਾਹੀਂ ਫੈਲ ਸਕਦਾ ਹੈ।','fungal_desc':'ਨਤੀਜਾ ਫਫੂੰਦ ਰੋਗ ਦੀ ਸੰਭਾਵਨਾ ਦਿਖਾਉਂਦਾ ਹੈ। ਲੰਬੇ ਸਮੇਂ ਤੱਕ ਪੱਤਿਆਂ ਦਾ ਗਿੱਲਾ ਰਹਿਣਾ ਰੋਗ ਵਧਾ ਸਕਦਾ ਹੈ।','generic_desc':'AI ਨੇ ਫਸਲ ਵਿੱਚ ਰੋਗ ਦੀ ਸੰਭਾਵਨਾ ਪਛਾਣੀ ਹੈ। ਰਸਾਇਣ ਵਰਤਣ ਤੋਂ ਪਹਿਲਾਂ ਰੋਗ ਦੀ ਪੁਸ਼ਟੀ ਕਰੋ।','healthy_treat':'ਇਸ ਨਤੀਜੇ ਅਨੁਸਾਰ ਕਿਸੇ ਇਲਾਜ ਦੀ ਲੋੜ ਨਹੀਂ। ਆਮ ਦੇਖਭਾਲ ਅਤੇ ਨਿਯਮਿਤ ਨਿਗਰਾਨੀ ਜਾਰੀ ਰੱਖੋ।','virus_treat':'ਵਾਇਰਸ ਰੋਗ ਲਈ ਆਮ ਤੌਰ ਤੇ ਭਰੋਸੇਯੋਗ ਇਲਾਜੀ ਸਪਰੇ ਨਹੀਂ ਹੁੰਦੀ। ਗੰਭੀਰ ਪੌਦੇ ਹਟਾਓ, ਵਾਹਕ ਕੀੜਿਆਂ ਨੂੰ ਕਾਬੂ ਕਰੋ ਅਤੇ ਸਿਹਤਮੰਦ ਰੋਪਣ ਸਮੱਗਰੀ ਵਰਤੋ।','bacterial_treat':'ਗੰਭੀਰ ਸੰਕਰਮਿਤ ਹਿੱਸੇ ਹਟਾਓ ਅਤੇ ਸੰਦ ਸਾਫ਼ ਕਰੋ। ਰਸਾਇਣ ਦੀ ਲੋੜ ਹੋਵੇ ਤਾਂ ਕੇਵਲ ਇਸ ਫਸਲ ਅਤੇ ਪੁਸ਼ਟੀਸ਼ੁਦਾ ਰੋਗ ਲਈ ਰਜਿਸਟਰਡ ਉਤਪਾਦ ਲੇਬਲ ਅਨੁਸਾਰ ਵਰਤੋ।','blight_treat':'ਗੰਭੀਰ ਸੰਕਰਮਿਤ ਪੱਤੇ ਅਤੇ ਫਲ ਹਟਾਓ, ਪੱਤਿਆਂ ਦੀ ਨਮੀ ਘਟਾਓ ਅਤੇ ਹਵਾ ਦਾ ਪ੍ਰਵਾਹ ਵਧਾਓ। ਲੋੜ ਹੋਣ ਤੇ ਰਜਿਸਟਰਡ ਫਫੂੰਦਨਾਸ਼ਕ ਲੇਬਲ ਅਨੁਸਾਰ ਵਰਤੋ।','scab_treat':'ਸੰਕਰਮਿਤ ਡਿੱਗੇ ਪੱਤੇ ਅਤੇ ਫਲ ਹਟਾਓ, ਸਫਾਈ ਰੱਖੋ ਅਤੇ ਹਵਾ ਦਾ ਪ੍ਰਵਾਹ ਵਧਾਓ। ਕੇਵਲ ਰਜਿਸਟਰਡ ਫਫੂੰਦਨਾਸ਼ਕ ਵਰਤੋ।','rust_treat':'ਬਹੁਤ ਪ੍ਰਭਾਵਿਤ ਪੱਤੇ ਹਟਾਓ ਅਤੇ ਹਵਾ ਦਾ ਪ੍ਰਵਾਹ ਵਧਾਓ। ਪੁਸ਼ਟੀਸ਼ੁਦਾ ਰਸਟ ਲਈ ਰਜਿਸਟਰਡ ਫਫੂੰਦਨਾਸ਼ਕ ਹੀ ਵਰਤੋ।','rot_treat':'ਸੜੇ ਫਲ ਜਾਂ ਪੌਧੇ ਦੇ ਹਿੱਸੇ ਹਟਾਓ, ਨਿਕਾਸੀ ਅਤੇ ਹਵਾ ਦਾ ਪ੍ਰਵਾਹ ਸੁਧਾਰੋ।','wilt_treat':'ਗੰਭੀਰ ਪੌਦੇ ਹਟਾਓ, ਨਿਕਾਸੀ ਸੁਧਾਰੋ ਅਤੇ ਸੰਕਰਮਿਤ ਮਿੱਟੀ ਜਾਂ ਸੰਦ ਨਾ ਫੈਲਾਓ। ਰਸਾਇਣ ਤੋਂ ਪਹਿਲਾਂ ਕਾਰਨ ਦੀ ਪੁਸ਼ਟੀ ਕਰੋ।','fungal_treat':'ਸੰਕਰਮਿਤ ਹਿੱਸੇ ਹਟਾਓ, ਹਵਾ ਦਾ ਪ੍ਰਵਾਹ ਵਧਾਓ ਅਤੇ ਲੰਬੀ ਨਮੀ ਤੋਂ ਬਚੋ। ਸਪਰੇ ਲੋੜੀਂਦੀ ਹੋਵੇ ਤਾਂ ਰਜਿਸਟਰਡ ਉਤਪਾਦ ਵਰਤੋ।','generic_treat':'ਪਹਿਲਾਂ ਰੋਗ ਦੀ ਪੁਸ਼ਟੀ ਕਰੋ। ਫਿਰ ਕੇਵਲ ਇਸ ਫਸਲ ਅਤੇ ਰੋਗ ਲਈ ਰਜਿਸਟਰਡ ਉਤਪਾਦ ਲੇਬਲ ਅਤੇ ਸਥਾਨਕ ਖੇਤੀ ਸਲਾਹ ਅਨੁਸਾਰ ਵਰਤੋ।','healthy_prev':'ਸਿਹਤਮੰਦ ਰੋਪਣ ਸਮੱਗਰੀ, ਸੰਤੁਲਿਤ ਸਿੰਚਾਈ, ਪੋਸ਼ਣ, ਹਵਾ ਦਾ ਪ੍ਰਵਾਹ ਅਤੇ ਖੇਤ ਦੀ ਸਫਾਈ ਰੱਖੋ।','virus_prev':'ਸਿਹਤਮੰਦ ਰੋਪਣ ਸਮੱਗਰੀ ਵਰਤੋ, ਵਾਹਕ ਕੀੜਿਆਂ ਨੂੰ ਕਾਬੂ ਕਰੋ, ਸੰਕਰਮਿਤ ਪੌਦੇ ਹਟਾਓ ਅਤੇ ਜੰਗਲੀ ਮੇਜ਼ਬਾਨ ਬੂਟਿਆਂ ਨੂੰ ਕਾਬੂ ਕਰੋ।','bacterial_prev':'ਸਾਫ਼ ਬੀਜ/ਪੌਦੇ ਵਰਤੋ, ਸੰਦ ਸੈਨੀਟਾਈਜ਼ ਕਰੋ, ਗਿੱਲੀ ਫਸਲ ਵਿੱਚ ਕੰਮ ਨਾ ਕਰੋ ਅਤੇ ਸੰਕਰਮਿਤ ਅਵਸ਼ੇਸ਼ ਹਟਾਓ।','wilt_prev':'ਚੰਗੀ ਨਿਕਾਸੀ ਰੱਖੋ, ਵੱਧ ਸਿੰਚਾਈ ਨਾ ਕਰੋ ਅਤੇ ਸੰਕਰਮਿਤ ਮਿੱਟੀ ਜਾਂ ਅਵਸ਼ੇਸ਼ ਨਾ ਫੈਲਾਓ।','fungal_prev':'ਖੇਤ ਦੀ ਸਫਾਈ, ਠੀਕ ਦੂਰੀ, ਹਵਾ ਦਾ ਪ੍ਰਵਾਹ, ਚੰਗੀ ਨਿਕਾਸੀ ਅਤੇ ਨਿਯਮਿਤ ਨਿਗਰਾਨੀ ਰੱਖੋ।','generic_prev':'ਸਿਹਤਮੰਦ ਰੋਪਣ ਸਮੱਗਰੀ ਵਰਤੋ, ਸਫਾਈ ਰੱਖੋ, ਠੀਕ ਦੂਰੀ ਅਤੇ ਨਿਕਾਸੀ ਰੱਖੋ ਅਤੇ ਨਿਯਮਿਤ ਨਿਗਰਾਨੀ ਕਰੋ।','healthy_action':'ਆਮ ਦੇਖਭਾਲ ਜਾਰੀ ਰੱਖੋ ਅਤੇ ਨਵੇਂ ਲੱਛਣਾਂ ਲਈ ਨਿਯਮਿਤ ਜਾਂਚ ਕਰੋ।','low_action':'ਪੱਤੇ ਦੀ ਸਾਫ਼ ਨਜ਼ਦੀਕੀ ਤਸਵੀਰ ਲਓ ਅਤੇ ਕਈ ਪੌਦਿਆਂ ਨੂੰ ਵੇਖੋ। ਭਰੋਸਾ ਘੱਟ ਹੈ, ਇਸ ਲਈ ਸਪਰੇ ਤੋਂ ਪਹਿਲਾਂ ਰੋਗ ਦੀ ਪੁਸ਼ਟੀ ਕਰੋ।','virus_action':'ਨੇੜਲੇ ਪੌਦਿਆਂ ਵਿੱਚ ਲੱਛਣ ਅਤੇ ਵਾਹਕ ਕੀੜੇ ਵੇਖੋ। ਗੰਭੀਰ ਪੌਦੇ ਸਲਾਹ ਅਨੁਸਾਰ ਹਟਾਓ।','generic_action':'ਨੇੜਲੇ ਪੌਦਿਆਂ ਦੀ ਜਾਂਚ ਕਰੋ, ਗੰਭੀਰ ਹਿੱਸੇ ਹਟਾਓ, ਸਫਾਈ ਸੁਧਾਰੋ ਅਤੇ ਸਪਰੇ ਤੋਂ ਪਹਿਲਾਂ ਰੋਗ ਦੀ ਪੁਸ਼ਟੀ ਕਰੋ।'}
    };
    // For the remaining supported languages, keep the content in the selected
    // language rather than silently falling back to English. These concise
    // safety-first local messages are intentionally generic until a verified
    // crop/disease glossary is added.
    final localizedGeneric = <String, Map<String, String>>{
      'mr': {'generic_treat':'प्रथम रोगाची खात्री करा. त्यानंतर या पिकासाठी आणि रोगासाठी सध्या नोंदणीकृत उत्पादनच लेबल व स्थानिक कृषी सल्ल्यानुसार वापरा.','generic_prev':'निरोगी लागवड साहित्य वापरा, शेताची स्वच्छता ठेवा, योग्य अंतर व निचरा ठेवा आणि नियमित पाहणी करा.','generic_desc':'AI ने पिकात रोगाची शक्यता ओळखली आहे. रसायन वापरण्यापूर्वी रोगाची खात्री करा.'},
      'bn': {'generic_treat':'প্রথমে রোগ নিশ্চিত করুন। তারপর এই ফসল ও রোগের জন্য বর্তমানে নিবন্ধিত পণ্যই লেবেল ও স্থানীয় কৃষি পরামর্শ অনুযায়ী ব্যবহার করুন।','generic_prev':'সুস্থ রোপণ উপকরণ ব্যবহার করুন, জমি পরিষ্কার রাখুন, সঠিক দূরত্ব ও নিষ্কাশন বজায় রাখুন এবং নিয়মিত নজরদারি করুন।','generic_desc':'AI ফসলে রোগের সম্ভাবনা শনাক্ত করেছে। রাসায়নিক ব্যবহারের আগে রোগ নিশ্চিত করুন।'},
      'gu': {'generic_treat':'પહેલા રોગની પુષ્ટિ કરો. પછી આ પાક અને રોગ માટે હાલમાં નોંધાયેલ ઉત્પાદન જ લેબલ અને સ્થાનિક કૃષિ સલાહ મુજબ વાપરો.','generic_prev':'સ્વસ્થ વાવેતર સામગ્રી વાપરો, ખેતરની સફાઈ રાખો, યોગ્ય અંતર અને નિકાસ જાળવો અને નિયમિત નિરીક્ષણ કરો.','generic_desc':'AI એ પાકમાં રોગની સંભાવના ઓળખી છે. રસાયણ વાપરતા પહેલાં રોગની પુષ્ટિ કરો.'},
      'ta': {'generic_treat':'முதலில் நோயை உறுதி செய்யுங்கள். பின்னர் இந்த பயிர் மற்றும் நோய்க்காக தற்போது பதிவு செய்யப்பட்ட தயாரிப்பை மட்டுமே லேபிள் மற்றும் உள்ளூர் வேளாண் ஆலோசனைப்படி பயன்படுத்துங்கள்.','generic_prev':'ஆரோக்கியமான நடவு பொருட்களை பயன்படுத்தி, வயல் சுத்தம், சரியான இடைவெளி, நல்ல வடிகால் மற்றும் வழக்கமான கண்காணிப்பை பராமரிக்கவும்.','generic_desc':'AI பயிரில் நோய் ஏற்படும் வாய்ப்பை கண்டறிந்துள்ளது. ரசாயனம் பயன்படுத்தும் முன் நோயை உறுதி செய்யுங்கள்.'},
      'te': {'generic_treat':'ముందుగా వ్యాధిని నిర్ధారించండి. తర్వాత ఈ పంట మరియు వ్యాధికి ప్రస్తుతం నమోదైన ఉత్పత్తిని మాత్రమే లేబుల్ మరియు స్థానిక వ్యవసాయ సలహా ప్రకారం ఉపయోగించండి.','generic_prev':'ఆరోగ్యకరమైన నాటే పదార్థం వాడండి, పొలాన్ని శుభ్రంగా ఉంచండి, సరైన దూరం మరియు నీటి పారుదల పాటించండి, క్రమం తప్పకుండా పరిశీలించండి.','generic_desc':'AI పంటలో వ్యాధి ఉండే అవకాశాన్ని గుర్తించింది. రసాయనం వాడే ముందు వ్యాధిని నిర్ధారించండి.'},
      'kn': {'generic_treat':'ಮೊದಲು ರೋಗವನ್ನು ದೃಢಪಡಿಸಿ. ನಂತರ ಈ ಬೆಳೆ ಮತ್ತು ರೋಗಕ್ಕೆ ಪ್ರಸ್ತುತ ನೋಂದಾಯಿತ ಉತ್ಪನ್ನವನ್ನು ಮಾತ್ರ ಲೇಬಲ್ ಮತ್ತು ಸ್ಥಳೀಯ ಕೃಷಿ ಸಲಹೆಯಂತೆ ಬಳಸಿ.','generic_prev':'ಆರೋಗ್ಯಕರ ನೆಡುವ ಸಾಮಗ್ರಿ ಬಳಸಿ, ಹೊಲದ ಸ್ವಚ್ಛತೆ, ಸರಿಯಾದ ಅಂತರ, ಉತ್ತಮ ನೀರು ಹರಿವು ಮತ್ತು ನಿಯಮಿತ ಪರಿಶೀಲನೆ ಕಾಪಾಡಿ.','generic_desc':'AI ಬೆಳೆದಲ್ಲಿ ರೋಗದ ಸಾಧ್ಯತೆಯನ್ನು ಗುರುತಿಸಿದೆ. ರಾಸಾಯನಿಕ ಬಳಸುವ ಮೊದಲು ರೋಗವನ್ನು ದೃಢಪಡಿಸಿ.'},
      'ml': {'generic_treat':'ആദ്യം രോഗം സ്ഥിരീകരിക്കുക. തുടർന്ന് ഈ വിളയ്ക്കും രോഗത്തിനും നിലവിൽ രജിസ്റ്റർ ചെയ്ത ഉൽപ്പന്നം മാത്രം ലേബലും പ്രാദേശിക കാർഷിക നിർദ്ദേശവും അനുസരിച്ച് ഉപയോഗിക്കുക.','generic_prev':'ആരോഗ്യമുള്ള നടീൽ വസ്തുക്കൾ ഉപയോഗിക്കുക, വയൽ ശുചിയായി സൂക്ഷിക്കുക, ശരിയായ അകലം, നല്ല നീർവാർച്ച, സ്ഥിരമായ നിരീക്ഷണം എന്നിവ പാലിക്കുക.','generic_desc':'AI വിളയിൽ രോഗസാധ്യത കണ്ടെത്തി. രാസവസ്തു ഉപയോഗിക്കുന്നതിന് മുമ്പ് രോഗം സ്ഥിരീകരിക്കുക.'}
    };
    final m = d[lang] ?? localizedGeneric[lang] ?? d['en']!;
    return m[key] ?? localizedGeneric[lang]?[key] ?? m['generic_treat']!;
  }

  String _extractCrop(String className) {
    if (className.contains('___')) {
      return className
          .split('___')
          .first
          .replaceAll('_', ' ')
          .trim();
    }

    final parts = className.trim().split(RegExp(r'\s+'));
    return parts.isNotEmpty ? parts.first : 'Unknown';
  }

  bool _isHealthy(String className) {
    final name = className.toLowerCase();

    return name.contains('healthy') ||
        name.contains('normal');
  }

  String _calculateSeverity(
    String className,
    double confidence,
  ) {
    if (_isHealthy(className)) return 'none';

    final name = className.toLowerCase();

    const highKeywords = [
      'late blight',
      'early blight',
      'bacterial',
      'virus',
      'viral',
      'canker',
      'black rot',
      'fire blight',
      'yellow leaf curl',
      'mosaic',
      'wilt',
      'scab',
      'rust',
    ];

    final highRisk = highKeywords.any(
      name.contains,
    );

    if (highRisk) {
      return confidence >= 70 ? 'high' : 'medium';
    }

    if (confidence >= 80) return 'medium';

    return 'low';
  }

  bool _governmentAlertRequired(
    String className,
    double confidence,
    String severity,
  ) {
    if (_isHealthy(className)) return false;
    if (confidence < 70) return false;

    return severity == 'high' || severity == 'medium';
  }

  Future<void> _savePendingAlert({
    required String predictionId,
    required int classId,
    required String className,
    required double confidence,
    required String severity,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final raw = prefs.getStringList(pendingKey) ?? [];

    final alert = {
      'prediction_id': predictionId,
      'prediction': {
        'class_id': classId,
        'class_name': className,
        'confidence': confidence,
        'severity': severity,
      },
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    raw.add(jsonEncode(alert));

    await prefs.setStringList(pendingKey, raw);

    debugPrint(
      'OFFLINE ALERT SAVED. Pending count: ${raw.length}',
    );

    if (mounted) {
      message(
        'Serious issue saved. It will sync with the government system when internet returns.',
      );
    }
  }

  Future<void> _syncPendingAlerts() async {
    if (syncing) return;

    setStateIfMounted(() {
      syncing = true;
    });

    try {
      final connectivity = await Connectivity().checkConnectivity();

      if (connectivity.contains(ConnectivityResult.none)) {
        return;
      }

      final prefs = await SharedPreferences.getInstance();

      final raw = prefs.getStringList(pendingKey) ?? [];

      if (raw.isEmpty) return;

      final remaining = <String>[];

      for (final item in raw) {
        try {
          final decoded = jsonDecode(item);

          if (decoded is! Map) {
            continue;
          }

          final alert = Map<String, dynamic>.from(decoded);

          final response = await http.post(
            Uri.parse('$backendUrl/api/government/alert'),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode(alert),
          ).timeout(
            const Duration(seconds: 10),
          );

          if (response.statusCode >= 200 &&
              response.statusCode < 300) {
            debugPrint(
              'PENDING ALERT SYNCED: ${response.body}',
            );
          } else {
            remaining.add(item);
          }
        } catch (e) {
          debugPrint('PENDING ALERT SYNC FAILED: $e');
          remaining.add(item);
        }
      }

      await prefs.setStringList(
        pendingKey,
        remaining,
      );

      if (remaining.isEmpty && raw.isNotEmpty && mounted) {
        message('Pending government alerts synced successfully.');
      }
    } finally {
      setStateIfMounted(() {
        syncing = false;
      });
    }
  }

  void setStateIfMounted(VoidCallback callback) {
    if (mounted) setState(callback);
  }

  double _toPercent(dynamic value) {
    if (value == null) return 0;

    double result;

    if (value is num) {
      result = value.toDouble();
    } else {
      result = double.tryParse(value.toString()) ?? 0;
    }

    if (result > 0 && result <= 1) {
      result *= 100;
    }

    return result;
  }

  void message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  void showResult() {
    final lang = LanguageScope.of(context).value;

    final displayDisease = disease.isEmpty
        ? 'Unknown'
        : diseaseLabel(disease, lang);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (c) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 45,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Center(
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 58,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    tr(context, 'complete'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: analysisMode == 'ONLINE'
                          ? const Color(0xFFE3F2FD)
                          : const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          analysisMode == 'ONLINE'
                              ? Icons.cloud_done_rounded
                              : Icons.offline_bolt_rounded,
                          size: 18,
                          color: analysisMode == 'ONLINE'
                              ? Colors.blue.shade700
                              : const Color(0xFF2E7D32),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          analysisMode == 'ONLINE'
                              ? tr(context, 'onlineAI')
                              : tr(context, 'offlineAI'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: analysisMode == 'ONLINE'
                                ? Colors.blue.shade700
                                : const Color(0xFF2E7D32),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                resultCard(
                  icon: Icons.local_florist_rounded,
                  title: tr(context, 'detected'),
                  text: displayDisease,
                ),
                const SizedBox(height: 12),
                resultCard(
                  icon: Icons.speed_rounded,
                  title: tr(context, 'confidence'),
                  text: '${confidence.toStringAsFixed(2)}%',
                ),
                if (crop.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  resultCard(
                    icon: Icons.eco_rounded,
                    title: tr(context, 'crop'),
                    text: crop,
                  ),
                ],
                if (severity.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  resultCard(
                    icon: Icons.warning_amber_rounded,
                    title: tr(context, 'severity'),
                    text: severity,
                  ),
                ],
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  resultCard(icon: Icons.info_outline, title: tr(context, 'description'), text: description),
                ],
                if (treatment.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  resultCard(icon: Icons.medical_services_outlined, title: tr(context, 'treatment'), text: treatment),
                ],
                if (prevention.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  resultCard(icon: Icons.shield_outlined, title: tr(context, 'prevention'), text: prevention),
                ],
                if (farmerAction.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  resultCard(icon: Icons.agriculture, title: tr(context, 'farmerAction'), text: farmerAction),
                ],
                if (governmentAlertId.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  resultCard(
                    icon: Icons.account_balance_rounded,
                    title: tr(context, 'governmentAlert'),
                    text:
                        '${tr(context, 'alertCreated')}\nID: $governmentAlertId',
                  ),
                ] else if (analysisMode == 'OFFLINE' &&
                    _governmentAlertRequired(
                      disease,
                      confidence,
                      severity,
                    )) ...[
                  const SizedBox(height: 12),
                  resultCard(
                    icon: Icons.cloud_upload_outlined,
                    title: tr(context, 'governmentAlert'),
                    text:
                        '${tr(context, 'alertWaiting')} '
                        'It will be sent automatically when connectivity returns.',
                  ),
                ],
                if (analysisMode == 'OFFLINE') ...[
                  const SizedBox(height: 12),
                  resultCard(
                    icon: Icons.offline_bolt_rounded,
                    title: tr(context, 'offlineMode'),
                    text:
                        'Prediction was generated directly on your device. '
                        'Internet connection was not required.',
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(c);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AiChatScreen(
                            initialCrop: crop,
                            initialDisease: disease,
                            initialConfidence: confidence,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.smart_toy_outlined),
                    label: Text(tr(context, 'askAI')),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(c),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget resultCard({
    required IconData icon,
    required String title,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: const Color(0xFF2E7D32),
            size: 25,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B5E20),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  text,
                  style: const TextStyle(
                    height: 1.45,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF2),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        title: Text(tr(context, 'disease')),
        actions: [
          if (syncing)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Sync pending alerts',
              onPressed: _syncPendingAlerts,
              icon: const Icon(Icons.sync_rounded),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(
              Icons.local_florist_rounded,
              size: 70,
              color: Color(0xFF2E7D32),
            ),
            const SizedBox(height: 12),
            Text(
              tr(context, 'disease'),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B5E20),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr(context, 'help'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 28),
            Container(
              width: double.infinity,
              height: 280,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFFA5D6A7),
                ),
              ),
              child: image == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.add_a_photo_rounded,
                          size: 65,
                          color: Color(0xFF66BB6A),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          tr(context, 'noImage'),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tr(context, 'choose'),
                          style: const TextStyle(
                            color: Colors.black45,
                          ),
                        ),
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Image.memory(
                        imageBytes!,
                        width: double.infinity,
                        height: 280,
                        fit: BoxFit.cover,
                      ),
                    ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: analyzing
                        ? null
                        : () => choose(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: Text(tr(context, 'camera')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: analyzing
                        ? null
                        : () => choose(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_rounded),
                    label: Text(tr(context, 'gallery')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: analyzing || modelLoading
                    ? null
                    : analyze,
                icon: analyzing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome_rounded),
                label: Text(
                  modelLoading
                      ? 'Loading 192-class AI model...'
                      : analyzing
                          ? 'AI is analyzing image...'
                          : 'Analyze with AI',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 17,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: SwitchListTile(
                secondary: const Icon(Icons.offline_bolt_rounded, color: Color(0xFF2E7D32)),
                title: const Text('Force Offline AI'),
                subtitle: Text(forceOffline ? 'Using TFLite on this device' : 'Online AI first, then offline fallback'),
                value: forceOffline,
                onChanged: (value) async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool(forceOfflineKey, value);
                  if (!mounted) return;
                  setState(() => forceOffline = value);
                },
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.cloud_sync_rounded,
                    color: Color(0xFF1B5E20),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Online AI is tried first. If the internet or server '
                      'is unavailable, the 192-class AI runs on the device. '
                      'Serious offline detections are saved and synced '
                      'to the government system when internet returns.',
                      style: TextStyle(
                        color: Color(0xFF1B5E20),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
