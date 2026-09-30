import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../language.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({
    super.key,
    this.initialCrop = '',
    this.initialDisease = '',
    this.initialConfidence = 0,
  });

  final String initialCrop;
  final String initialDisease;
  final double initialConfidence;

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  static const String backendUrl = 'https://krishi-rakshak-api.onrender.com';

  final TextEditingController controller = TextEditingController();
  final ScrollController scroll = ScrollController();

  final List<Map<String, String>> messages = [];

  bool loading = false;
  bool _languageInitialized = false;

  String selectedLanguage = 'en';

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final lang = LanguageScope.of(context).value;

    if (!_languageInitialized || selectedLanguage != lang) {
      selectedLanguage = lang;
      _languageInitialized = true;

      if (messages.isEmpty) {
        messages.add({
          'role': 'assistant',
          'content': tr(context, 'aiGreeting'),
        });
      }
    }
  }

  // ============================================================
  // SEND MESSAGE
  // ============================================================

  Future<void> send() async {
    final text = controller.text.trim();

    if (text.isEmpty || loading) {
      return;
    }

    controller.clear();

    setState(() {
      messages.add({
        'role': 'user',
        'content': text,
      });
      loading = true;
    });

    _scrollToBottom();

    try {
      final response = await http
          .post(
            Uri.parse('$backendUrl/api/chat'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'message': text,
              'language': _detectQueryLanguage(text, selectedLanguage),
              'context': {
                'crop': widget.initialCrop,
                'disease': widget.initialDisease,
                'confidence': widget.initialConfidence,
              },
              'history': messages,
            }),
          )
          .timeout(
            const Duration(seconds: 35),
          );

      debugPrint('AI CHAT HTTP: ${response.statusCode}');
      debugPrint('AI CHAT RESPONSE: ${response.body}');

      final decoded = jsonDecode(response.body);

      if (response.statusCode != 200 ||
          decoded is! Map ||
          decoded['success'] != true) {
        throw Exception(
          decoded is Map
              ? decoded['error']?.toString() ?? 'AI server error'
              : 'AI server error',
        );
      }

      final answer = decoded['reply']?.toString().trim();

      if (answer == null || answer.isEmpty) {
        throw Exception('Empty AI response');
      }

      if (!mounted) {
        return;
      }

      setState(() {
        messages.add({
          'role': 'assistant',
          'content': answer,
        });
        loading = false;
      });

      _scrollToBottom();
    } catch (e) {
      debugPrint('AI CHAT FAILED: $e');

      if (!mounted) {
        return;
      }

      setState(() {
        messages.add({
          'role': 'assistant',
          'content': 'AI response could not be loaded right now. Please try again.',
        });
        loading = false;
      });

      _scrollToBottom();
    }
  }

  // ============================================================
  // LOCAL AI FALLBACK
  // ============================================================

  String _localAiReply(String question) {
    final q = question.toLowerCase();

    final disease = widget.initialDisease.isNotEmpty
        ? diseaseLabel(widget.initialDisease, selectedLanguage)
        : '';

    final crop = widget.initialCrop.isNotEmpty
        ? widget.initialCrop
        : '';

    switch (selectedLanguage) {
      case 'hi':
        return _hindiReply(q, crop, disease);

      case 'pa':
        return _punjabiReply(q, crop, disease);

      case 'mr':
        return _marathiReply(q, crop, disease);

      case 'bn':
        return _bengaliReply(q, crop, disease);

      case 'gu':
        return _gujaratiReply(q, crop, disease);

      case 'ta':
        return _tamilReply(q, crop, disease);

      case 'te':
        return _teluguReply(q, crop, disease);

      case 'kn':
        return _kannadaReply(q, crop, disease);

      case 'ml':
        return _malayalamReply(q, crop, disease);

      case 'en':
      default:
        return _englishReply(q, crop, disease);
    }
  }

  String _englishReply(
    String question,
    String crop,
    String disease,
  ) {
    if (_containsAny(question, [
      'treatment',
      'medicine',
      'spray',
      'cure',
      'treat',
    ])) {
      return 'For ${disease.isEmpty ? 'this condition' : disease}, first confirm the symptoms. Remove severely affected plant material where practical, maintain field sanitation, and use only a locally registered crop-protection product according to its label and local agricultural guidance.';
    }

    if (_containsAny(question, [
      'prevent',
      'prevention',
      'avoid',
      'protect',
    ])) {
      return 'Use healthy planting material, maintain field sanitation, avoid unnecessary leaf wetness, provide suitable spacing and drainage, and inspect nearby plants regularly.';
    }

    return 'Krishi Rakshak detected ${disease.isEmpty ? 'a possible crop problem' : disease}${crop.isEmpty ? '' : ' in $crop'}. Check the visible symptoms carefully and consult a local agriculture officer before applying any chemical treatment.';
  }

  String _hindiReply(
    String question,
    String crop,
    String disease,
  ) {
    if (_containsAny(question, [
      'à¤‡à¤²à¤¾à¤œ',
      'à¤¦à¤µà¤¾',
      'à¤¸à¥à¤ªà¥à¤°à¥‡',
      'treatment',
      'medicine',
      'spray',
    ])) {
      return '${disease.isEmpty ? 'à¤‡à¤¸ à¤¸à¤®à¤¸à¥à¤¯à¤¾' : disease} à¤•à¥‡ à¤²à¤¿à¤ à¤ªà¤¹à¤²à¥‡ à¤²à¤•à¥à¤·à¤£à¥‹à¤‚ à¤•à¥€ à¤ªà¥à¤·à¥à¤Ÿà¤¿ à¤•à¤°à¥‡à¤‚à¥¤ à¤¬à¤¹à¥à¤¤ à¤…à¤§à¤¿à¤• à¤ªà¥à¤°à¤­à¤¾à¤µà¤¿à¤¤ à¤ªà¥Œà¤§à¥‹à¤‚ à¤¯à¤¾ à¤­à¤¾à¤—à¥‹à¤‚ à¤•à¥‹ à¤œà¤¹à¤¾à¤ à¤¸à¤‚à¤­à¤µ à¤¹à¥‹ à¤¸à¥à¤°à¤•à¥à¤·à¤¿à¤¤ à¤¤à¤°à¥€à¤•à¥‡ à¤¸à¥‡ à¤¹à¤Ÿà¤¾à¤à¤, à¤–à¥‡à¤¤ à¤•à¥€ à¤¸à¥à¤µà¤šà¥à¤›à¤¤à¤¾ à¤¬à¤¨à¤¾à¤ à¤°à¤–à¥‡à¤‚ à¤”à¤° à¤•à¤¿à¤¸à¥€ à¤­à¥€ à¤•à¥ƒà¤·à¤¿ à¤°à¤¸à¤¾à¤¯à¤¨ à¤•à¤¾ à¤‰à¤ªà¤¯à¥‹à¤— à¤•à¥‡à¤µà¤² à¤¸à¥à¤¥à¤¾à¤¨à¥€à¤¯ à¤°à¥‚à¤ª à¤¸à¥‡ à¤ªà¤‚à¤œà¥€à¤•à¥ƒà¤¤ à¤‰à¤¤à¥à¤ªà¤¾à¤¦ à¤•à¥‡ à¤²à¥‡à¤¬à¤² à¤¤à¤¥à¤¾ à¤•à¥ƒà¤·à¤¿ à¤µà¤¿à¤­à¤¾à¤— à¤•à¥€ à¤¸à¤²à¤¾à¤¹ à¤•à¥‡ à¤…à¤¨à¥à¤¸à¤¾à¤° à¤•à¤°à¥‡à¤‚à¥¤';
    }

    if (_containsAny(question, [
      'à¤¬à¤šà¤¾à¤µ',
      'à¤°à¥‹à¤•à¤¥à¤¾à¤®',
      'prevent',
      'prevention',
      'avoid',
    ])) {
      return 'à¤¸à¥à¤µà¤¸à¥à¤¥ à¤”à¤° à¤°à¥‹à¤—à¤®à¥à¤•à¥à¤¤ à¤°à¥‹à¤ªà¤£ à¤¸à¤¾à¤®à¤—à¥à¤°à¥€ à¤•à¤¾ à¤‰à¤ªà¤¯à¥‹à¤— à¤•à¤°à¥‡à¤‚, à¤–à¥‡à¤¤ à¤•à¥€ à¤¸à¥à¤µà¤šà¥à¤›à¤¤à¤¾ à¤°à¤–à¥‡à¤‚, à¤…à¤¨à¤¾à¤µà¤¶à¥à¤¯à¤• à¤ªà¤¤à¥à¤¤à¤¿à¤¯à¥‹à¤‚ à¤•à¥€ à¤¨à¤®à¥€ à¤¸à¥‡ à¤¬à¤šà¥‡à¤‚, à¤‰à¤šà¤¿à¤¤ à¤¦à¥‚à¤°à¥€ à¤”à¤° à¤œà¤² à¤¨à¤¿à¤•à¤¾à¤¸à¥€ à¤°à¤–à¥‡à¤‚ à¤¤à¤¥à¤¾ à¤†à¤¸à¤ªà¤¾à¤¸ à¤•à¥‡ à¤ªà¥Œà¤§à¥‹à¤‚ à¤•à¥€ à¤¨à¤¿à¤¯à¤®à¤¿à¤¤ à¤œà¤¾à¤à¤š à¤•à¤°à¥‡à¤‚à¥¤';
    }

    return 'à¤•à¥ƒà¤·à¤¿ à¤°à¤•à¥à¤·à¤• à¤¨à¥‡ ${disease.isEmpty ? 'à¤«à¤¸à¤² à¤®à¥‡à¤‚ à¤¸à¤‚à¤­à¤¾à¤µà¤¿à¤¤ à¤¸à¤®à¤¸à¥à¤¯à¤¾' : disease} à¤•à¥€ à¤ªà¤¹à¤šà¤¾à¤¨ à¤•à¥€ à¤¹à¥ˆ${crop.isEmpty ? '' : 'à¥¤ à¤«à¤¸à¤²: $crop'}à¥¤ à¤¦à¤¿à¤–à¤¾à¤ˆ à¤¦à¥‡à¤¨à¥‡ à¤µà¤¾à¤²à¥‡ à¤²à¤•à¥à¤·à¤£à¥‹à¤‚ à¤•à¥€ à¤œà¤¾à¤à¤š à¤•à¤°à¥‡à¤‚ à¤”à¤° à¤•à¤¿à¤¸à¥€ à¤­à¥€ à¤°à¤¾à¤¸à¤¾à¤¯à¤¨à¤¿à¤• à¤‰à¤ªà¤šà¤¾à¤° à¤¸à¥‡ à¤ªà¤¹à¤²à¥‡ à¤¸à¥à¤¥à¤¾à¤¨à¥€à¤¯ à¤•à¥ƒà¤·à¤¿ à¤…à¤§à¤¿à¤•à¤¾à¤°à¥€ à¤•à¥€ à¤¸à¤²à¤¾à¤¹ à¤²à¥‡à¤‚à¥¤';
  }

  String _punjabiReply(
    String question,
    String crop,
    String disease,
  ) {
    if (_containsAny(question, [
      'à¨‡à¨²à¨¾à¨œ',
      'à¨¦à¨µà¨¾à¨ˆ',
      'à¨¸à¨ªà¨°à©‡',
      'treatment',
      'medicine',
      'spray',
    ])) {
      return '${disease.isEmpty ? 'à¨‡à¨¸ à¨¸à¨®à©±à¨¸à¨¿à¨†' : disease} à¨²à¨ˆ à¨ªà¨¹à¨¿à¨²à¨¾à¨‚ à¨²à©±à¨›à¨£à¨¾à¨‚ à¨¦à©€ à¨ªà©à¨¸à¨¼à¨Ÿà©€ à¨•à¨°à©‹à¥¤ à¨¬à¨¹à©à¨¤ à¨ªà©à¨°à¨­à¨¾à¨µà¨¿à¨¤ à¨ªà©Œà¨¦à¨¿à¨†à¨‚ à¨œà¨¾à¨‚ à¨¹à¨¿à©±à¨¸à¨¿à¨†à¨‚ à¨¨à©‚à©° à¨œà¨¿à©±à¨¥à©‡ à¨¸à©°à¨­à¨µ à¨¹à©‹à¨µà©‡ à¨¸à©à¨°à©±à¨–à¨¿à¨…à¨¤ à¨¢à©°à¨— à¨¨à¨¾à¨² à¨¹à¨Ÿà¨¾à¨“à¥¤ à¨–à©‡à¨¤ à¨¦à©€ à¨¸à¨«à¨¾à¨ˆ à¨°à©±à¨–à©‹ à¨…à¨¤à©‡ à¨•à¨¿à¨¸à©‡ à¨µà©€ à¨–à©‡à¨¤à©€à¨¬à¨¾à©œà©€ à¨¦à¨µà¨¾à¨ˆ à¨¦à©€ à¨µà¨°à¨¤à©‹à¨‚ à¨¸à¨¿à¨°à¨«à¨¼ à¨¸à¨¥à¨¾à¨¨à¨• à¨¤à©Œà¨° à¨¤à©‡ à¨°à¨œà¨¿à¨¸à¨Ÿà¨° à¨•à©€à¨¤à©‡ à¨‰à¨¤à¨ªà¨¾à¨¦ à¨¦à©‡ à¨²à©‡à¨¬à¨² à¨…à¨¤à©‡ à¨–à©‡à¨¤à©€à¨¬à¨¾à©œà©€ à¨µà¨¿à¨­à¨¾à¨— à¨¦à©€ à¨¸à¨²à¨¾à¨¹ à¨…à¨¨à©à¨¸à¨¾à¨° à¨•à¨°à©‹à¥¤';
    }

    if (_containsAny(question, [
      'à¨¬à¨šà¨¾à¨…',
      'à¨°à©‹à¨•à¨¥à¨¾à¨®',
      'prevent',
      'prevention',
    ])) {
      return 'à¨¸à¨¿à¨¹à¨¤à¨®à©°à¨¦ à¨…à¨¤à©‡ à¨°à©‹à¨—à¨®à©à¨•à¨¤ à¨ªà©Œà¨§à¨¾ à¨¸à¨®à©±à¨—à¨°à©€ à¨µà¨°à¨¤à©‹, à¨–à©‡à¨¤ à¨¦à©€ à¨¸à¨«à¨¾à¨ˆ à¨°à©±à¨–à©‹, à¨ªà©±à¨¤à¨¿à¨†à¨‚ à¨‰à©±à¨¤à©‡ à¨¬à©‡à¨²à©‹à©œà©€ à¨¨à¨®à©€ à¨¤à©‹à¨‚ à¨¬à¨šà©‹, à¨ à©€à¨• à¨¦à©‚à¨°à©€ à¨…à¨¤à©‡ à¨ªà¨¾à¨£à©€ à¨¦à©€ à¨¨à¨¿à¨•à¨¾à¨¸à©€ à¨°à©±à¨–à©‹ à¨…à¨¤à©‡ à¨¨à©‡à©œà¨²à©‡ à¨ªà©Œà¨¦à¨¿à¨†à¨‚ à¨¦à©€ à¨¨à¨¿à¨¯à¨®à¨¿à¨¤ à¨œà¨¾à¨‚à¨š à¨•à¨°à©‹à¥¤';
    }

    return 'à¨•à©à¨°à¨¿à¨¸à¨¼à©€ à¨°à¨•à¨¸à¨¼à¨• à¨¨à©‡ ${disease.isEmpty ? 'à¨«à¨¸à¨² à¨µà¨¿à©±à¨š à¨¸à©°à¨­à¨¾à¨µà¨¿à¨¤ à¨¸à¨®à©±à¨¸à¨¿à¨†' : disease} à¨¦à©€ à¨ªà¨›à¨¾à¨£ à¨•à©€à¨¤à©€ à¨¹à©ˆ${crop.isEmpty ? '' : 'à¥¤ à¨«à¨¸à¨²: $crop'}à¥¤ à¨²à©±à¨›à¨£à¨¾à¨‚ à¨¦à©€ à¨œà¨¾à¨‚à¨š à¨•à¨°à©‹ à¨…à¨¤à©‡ à¨°à¨¸à¨¾à¨‡à¨£à¨• à¨‡à¨²à¨¾à¨œ à¨¤à©‹à¨‚ à¨ªà¨¹à¨¿à¨²à¨¾à¨‚ à¨¸à¨¥à¨¾à¨¨à¨• à¨–à©‡à¨¤à©€à¨¬à¨¾à©œà©€ à¨…à¨§à¨¿à¨•à¨¾à¨°à©€ à¨¦à©€ à¨¸à¨²à¨¾à¨¹ à¨²à¨µà©‹à¥¤';
  }

  String _marathiReply(
    String question,
    String crop,
    String disease,
  ) {
    if (_containsAny(question, [
      'à¤‰à¤ªà¤šà¤¾à¤°',
      'à¤”à¤·à¤§',
      'à¤«à¤µà¤¾à¤°à¤£à¥€',
      'treatment',
      'medicine',
      'spray',
    ])) {
      return '${disease.isEmpty ? 'à¤¯à¤¾ à¤¸à¤®à¤¸à¥à¤¯à¥‡à¤¸à¤¾à¤ à¥€' : disease} à¤ªà¥à¤°à¤¥à¤® à¤²à¤•à¥à¤·à¤£à¤¾à¤‚à¤šà¥€ à¤–à¤¾à¤¤à¥à¤°à¥€ à¤•à¤°à¤¾. à¤œà¤¾à¤¸à¥à¤¤ à¤¬à¤¾à¤§à¤¿à¤¤ à¤à¤¾à¤¡à¤¾à¤‚à¤šà¥‡ à¤•à¤¿à¤‚à¤µà¤¾ à¤­à¤¾à¤—à¤¾à¤‚à¤šà¥‡ à¤¨à¥à¤•à¤¸à¤¾à¤¨ à¤à¤¾à¤²à¥‡à¤²à¥‡ à¤¸à¤¾à¤¹à¤¿à¤¤à¥à¤¯ à¤¶à¤•à¥à¤¯ à¤…à¤¸à¤²à¥à¤¯à¤¾à¤¸ à¤¸à¥à¤°à¤•à¥à¤·à¤¿à¤¤à¤ªà¤£à¥‡ à¤•à¤¾à¤¢à¥‚à¤¨ à¤Ÿà¤¾à¤•à¤¾. à¤¶à¥‡à¤¤à¤¾à¤šà¥€ à¤¸à¥à¤µà¤šà¥à¤›à¤¤à¤¾ à¤ à¥‡à¤µà¤¾ à¤†à¤£à¤¿ à¤•à¥‹à¤£à¤¤à¥‡à¤¹à¥€ à¤•à¥ƒà¤·à¥€ à¤°à¤¸à¤¾à¤¯à¤¨ à¤«à¤•à¥à¤¤ à¤¸à¥à¤¥à¤¾à¤¨à¤¿à¤• à¤¨à¥‹à¤‚à¤¦à¤£à¥€à¤•à¥ƒà¤¤ à¤‰à¤¤à¥à¤ªà¤¾à¤¦à¤¨à¤¾à¤šà¥à¤¯à¤¾ à¤²à¥‡à¤¬à¤²à¤¨à¥à¤¸à¤¾à¤° à¤µ à¤•à¥ƒà¤·à¥€ à¤µà¤¿à¤­à¤¾à¤—à¤¾à¤šà¥à¤¯à¤¾ à¤¸à¤²à¥à¤²à¥à¤¯à¤¾à¤¨à¥‡ à¤µà¤¾à¤ªà¤°à¤¾.';
    }

    if (_containsAny(question, [
      'à¤ªà¥à¤°à¤¤à¤¿à¤¬à¤‚à¤§',
      'à¤¬à¤šà¤¾à¤µ',
      'prevent',
      'prevention',
    ])) {
      return 'à¤¨à¤¿à¤°à¥‹à¤—à¥€ à¤µ à¤°à¥‹à¤—à¤®à¥à¤•à¥à¤¤ à¤²à¤¾à¤—à¤µà¤¡ à¤¸à¤¾à¤¹à¤¿à¤¤à¥à¤¯ à¤µà¤¾à¤ªà¤°à¤¾, à¤¶à¥‡à¤¤à¤¾à¤šà¥€ à¤¸à¥à¤µà¤šà¥à¤›à¤¤à¤¾ à¤ à¥‡à¤µà¤¾, à¤ªà¤¾à¤¨à¤¾à¤‚à¤µà¤° à¤…à¤¨à¤¾à¤µà¤¶à¥à¤¯à¤• à¤“à¤²à¤¾à¤µà¤¾ à¤Ÿà¤¾à¤³à¤¾, à¤¯à¥‹à¤—à¥à¤¯ à¤…à¤‚à¤¤à¤° à¤µ à¤¨à¤¿à¤šà¤°à¤¾ à¤ à¥‡à¤µà¤¾ à¤†à¤£à¤¿ à¤†à¤¸à¤ªà¤¾à¤¸à¤šà¥à¤¯à¤¾ à¤à¤¾à¤¡à¤¾à¤‚à¤šà¥€ à¤¨à¤¿à¤¯à¤®à¤¿à¤¤ à¤¤à¤ªà¤¾à¤¸à¤£à¥€ à¤•à¤°à¤¾.';
    }

    return 'à¤•à¥ƒà¤·à¥€ à¤°à¤•à¥à¤·à¤•à¤¨à¥‡ ${disease.isEmpty ? 'à¤ªà¤¿à¤•à¤¾à¤®à¤§à¥à¤¯à¥‡ à¤¸à¤‚à¤­à¤¾à¤µà¥à¤¯ à¤¸à¤®à¤¸à¥à¤¯à¤¾' : disease} à¤“à¤³à¤–à¤²à¥€ à¤†à¤¹à¥‡${crop.isEmpty ? '' : 'à¥¤ à¤ªà¥€à¤•: $crop'}à¥¤ à¤²à¤•à¥à¤·à¤£à¤¾à¤‚à¤šà¥€ à¤¤à¤ªà¤¾à¤¸à¤£à¥€ à¤•à¤°à¤¾ à¤†à¤£à¤¿ à¤°à¤¾à¤¸à¤¾à¤¯à¤¨à¤¿à¤• à¤‰à¤ªà¤šà¤¾à¤° à¤•à¤°à¤£à¥à¤¯à¤¾à¤ªà¥‚à¤°à¥à¤µà¥€ à¤¸à¥à¤¥à¤¾à¤¨à¤¿à¤• à¤•à¥ƒà¤·à¥€ à¤…à¤§à¤¿à¤•à¤¾à¤±à¥à¤¯à¤¾à¤‚à¤šà¤¾ à¤¸à¤²à¥à¤²à¤¾ à¤˜à¥à¤¯à¤¾.';
  }

  String _bengaliReply(
    String question,
    String crop,
    String disease,
  ) {
    if (_containsAny(question, [
      'à¦šà¦¿à¦•à¦¿à§Žà¦¸à¦¾',
      'à¦“à¦·à§à¦§',
      'à¦¸à§à¦ªà§à¦°à§‡',
      'treatment',
      'medicine',
      'spray',
    ])) {
      return '${disease.isEmpty ? 'à¦à¦‡ à¦¸à¦®à¦¸à§à¦¯à¦¾à¦°' : disease} à¦•à§à¦·à§‡à¦¤à§à¦°à§‡ à¦ªà§à¦°à¦¥à¦®à§‡ à¦²à¦•à§à¦·à¦£ à¦¨à¦¿à¦¶à§à¦šà¦¿à¦¤ à¦•à¦°à§à¦¨à¥¤ à¦¬à§‡à¦¶à¦¿ à¦†à¦•à§à¦°à¦¾à¦¨à§à¦¤ à¦—à¦¾à¦› à¦¬à¦¾ à¦…à¦‚à¦¶ à¦¸à¦®à§à¦­à¦¬ à¦¹à¦²à§‡ à¦¨à¦¿à¦°à¦¾à¦ªà¦¦à¦­à¦¾à¦¬à§‡ à¦¸à¦°à¦¿à¦¯à¦¼à§‡ à¦«à§‡à¦²à§à¦¨à¥¤ à¦œà¦®à¦¿à¦° à¦ªà¦°à¦¿à¦šà§à¦›à¦¨à§à¦¨à¦¤à¦¾ à¦¬à¦œà¦¾à¦¯à¦¼ à¦°à¦¾à¦–à§à¦¨ à¦à¦¬à¦‚ à¦•à§ƒà¦·à¦¿ à¦°à¦¾à¦¸à¦¾à¦¯à¦¼à¦¨à¦¿à¦• à¦¶à§à¦§à§à¦®à¦¾à¦¤à§à¦° à¦¸à§à¦¥à¦¾à¦¨à§€à¦¯à¦¼à¦­à¦¾à¦¬à§‡ à¦¨à¦¿à¦¬à¦¨à§à¦§à¦¿à¦¤ à¦ªà¦£à§à¦¯à§‡à¦° à¦²à§‡à¦¬à§‡à¦² à¦“ à¦•à§ƒà¦·à¦¿ à¦¬à¦¿à¦­à¦¾à¦—à§‡à¦° à¦ªà¦°à¦¾à¦®à¦°à§à¦¶ à¦…à¦¨à§à¦¯à¦¾à¦¯à¦¼à§€ à¦¬à§à¦¯à¦¬à¦¹à¦¾à¦° à¦•à¦°à§à¦¨à¥¤';
    }

    if (_containsAny(question, [
      'à¦ªà§à¦°à¦¤à¦¿à¦°à§‹à¦§',
      'à¦¬à¦¾à¦à¦šà¦¾à¦¨à§‹',
      'prevent',
      'prevention',
    ])) {
      return 'à¦°à§‹à¦—à¦®à§à¦•à§à¦¤ à¦°à§‹à¦ªà¦£ à¦‰à¦ªà¦•à¦°à¦£ à¦¬à§à¦¯à¦¬à¦¹à¦¾à¦° à¦•à¦°à§à¦¨, à¦œà¦®à¦¿ à¦ªà¦°à¦¿à¦·à§à¦•à¦¾à¦° à¦°à¦¾à¦–à§à¦¨, à¦ªà¦¾à¦¤à¦¾à¦¯à¦¼ à¦…à¦¤à¦¿à¦°à¦¿à¦•à§à¦¤ à¦†à¦°à§à¦¦à§à¦°à¦¤à¦¾ à¦à¦¡à¦¼à¦¿à¦¯à¦¼à§‡ à¦šà¦²à§à¦¨, à¦ªà¦°à§à¦¯à¦¾à¦ªà§à¦¤ à¦¦à§‚à¦°à¦¤à§à¦¬ à¦“ à¦¨à¦¿à¦·à§à¦•à¦¾à¦¶à¦¨ à¦¬à¦œà¦¾à¦¯à¦¼ à¦°à¦¾à¦–à§à¦¨ à¦à¦¬à¦‚ à¦†à¦¶à§‡à¦ªà¦¾à¦¶à§‡à¦° à¦—à¦¾à¦› à¦¨à¦¿à¦¯à¦¼à¦®à¦¿à¦¤ à¦ªà¦°à§€à¦•à§à¦·à¦¾ à¦•à¦°à§à¦¨à¥¤';
    }

    return 'à¦•à§ƒà¦·à¦¿ à¦°à¦•à§à¦·à¦• ${disease.isEmpty ? 'à¦«à¦¸à¦²à§‡ à¦à¦•à¦Ÿà¦¿ à¦¸à¦®à§à¦­à¦¾à¦¬à§à¦¯ à¦¸à¦®à¦¸à§à¦¯à¦¾' : disease} à¦¶à¦¨à¦¾à¦•à§à¦¤ à¦•à¦°à§‡à¦›à§‡${crop.isEmpty ? '' : 'à¥¤ à¦«à¦¸à¦²: $crop'}à¥¤ à¦¦à§ƒà¦¶à§à¦¯à¦®à¦¾à¦¨ à¦²à¦•à§à¦·à¦£ à¦ªà¦°à§€à¦•à§à¦·à¦¾ à¦•à¦°à§à¦¨ à¦à¦¬à¦‚ à¦°à¦¾à¦¸à¦¾à¦¯à¦¼à¦¨à¦¿à¦• à¦šà¦¿à¦•à¦¿à§Žà¦¸à¦¾à¦° à¦†à¦—à§‡ à¦¸à§à¦¥à¦¾à¦¨à§€à¦¯à¦¼ à¦•à§ƒà¦·à¦¿ à¦•à¦°à§à¦®à¦•à¦°à§à¦¤à¦¾à¦° à¦ªà¦°à¦¾à¦®à¦°à§à¦¶ à¦¨à¦¿à¦¨à¥¤';
  }

  String _gujaratiReply(
    String question,
    String crop,
    String disease,
  ) {
    if (_containsAny(question, [
      'àª¸àª¾àª°àªµàª¾àª°',
      'àª¦àªµàª¾',
      'àª›àª‚àªŸàª•àª¾àªµ',
      'treatment',
      'medicine',
      'spray',
    ])) {
      return '${disease.isEmpty ? 'àª† àª¸àª®àª¸à«àª¯àª¾ àª®àª¾àªŸà«‡' : disease} àªªàª¹à«‡àª²àª¾ àª²àª•à«àª·àª£à«‹àª¨à«€ àª–àª¾àª¤àª°à«€ àª•àª°à«‹. àªµàª§àª¾àª°à«‡ àª…àª¸àª°àª—à«àª°àª¸à«àª¤ àª›à«‹àª¡ àª…àª¥àªµàª¾ àª­àª¾àª—à«‹àª¨à«‡ àª¶àª•à«àª¯ àª¹à«‹àª¯ àª¤à«‹ àª¸à«àª°àª•à«àª·àª¿àª¤ àª°à«€àª¤à«‡ àª¦à«‚àª° àª•àª°à«‹. àª–à«‡àª¤àª°àª¨à«€ àª¸à«àªµàªšà«àª›àª¤àª¾ àªœàª¾àª³àªµà«‹ àª…àª¨à«‡ àª•à«‹àªˆàªªàª£ àª•à«ƒàª·àª¿ àª¦àªµàª¾àª¨à«‹ àª‰àªªàª¯à«‹àª— àª®àª¾àª¤à«àª° àª¸à«àª¥àª¾àª¨àª¿àª• àª°à«€àª¤à«‡ àª¨à«‹àª‚àª§àª¾àª¯à«‡àª² àª‰àª¤à«àªªàª¾àª¦àª¨àª¨àª¾ àª²à«‡àª¬àª² àª¤àª¥àª¾ àª•à«ƒàª·àª¿ àªµàª¿àª­àª¾àª—àª¨à«€ àª¸àª²àª¾àª¹ àª®à«àªœàª¬ àª•àª°à«‹.';
    }

    if (_containsAny(question, [
      'àª¬àªšàª¾àªµ',
      'àª¨àª¿àªµàª¾àª°àª£',
      'prevent',
      'prevention',
    ])) {
      return 'àª°à«‹àª—àª®à«àª•à«àª¤ àªµàª¾àªµà«‡àª¤àª° àª¸àª¾àª®àª—à«àª°à«€àª¨à«‹ àª‰àªªàª¯à«‹àª— àª•àª°à«‹, àª–à«‡àª¤àª°àª¨à«€ àª¸à«àªµàªšà«àª›àª¤àª¾ àªœàª¾àª³àªµà«‹, àªªàª¾àª‚àª¦àª¡àª¾àª‚ àªªàª° àª¬àª¿àª¨àªœàª°à«‚àª°à«€ àª­à«‡àªœ àªŸàª¾àª³à«‹, àª¯à«‹àª—à«àª¯ àª…àª‚àª¤àª° àª…àª¨à«‡ àªªàª¾àª£à«€àª¨à«‹ àª¨àª¿àª•àª¾àª² àª°àª¾àª–à«‹ àª…àª¨à«‡ àª†àª¸àªªàª¾àª¸àª¨àª¾ àª›à«‹àª¡àª¨à«€ àª¨àª¿àª¯àª®àª¿àª¤ àª¤àªªàª¾àª¸ àª•àª°à«‹.';
    }

    return 'àª•à«ƒàª·àª¿ àª°àª•à«àª·àª•à«‡ ${disease.isEmpty ? 'àªªàª¾àª•àª®àª¾àª‚ àª¸àª‚àª­àªµàª¿àª¤ àª¸àª®àª¸à«àª¯àª¾' : disease} àª“àª³àª–à«€ àª›à«‡${crop.isEmpty ? '' : 'à¥¤ àªªàª¾àª•: $crop'}à¥¤ àª¦à«‡àª–àª¾àª¤àª¾ àª²àª•à«àª·àª£à«‹àª¨à«€ àª¤àªªàª¾àª¸ àª•àª°à«‹ àª…àª¨à«‡ àª°àª¾àª¸àª¾àª¯àª£àª¿àª• àª¸àª¾àª°àªµàª¾àª° àªªàª¹à«‡àª²àª¾àª‚ àª¸à«àª¥àª¾àª¨àª¿àª• àª•à«ƒàª·àª¿ àª…àª§àª¿àª•àª¾àª°à«€àª¨à«€ àª¸àª²àª¾àª¹ àª²à«‹.';
  }

  String _tamilReply(
    String question,
    String crop,
    String disease,
  ) {
    if (_containsAny(question, [
      'à®šà®¿à®•à®¿à®šà¯à®šà¯ˆ',
      'à®®à®°à¯à®¨à¯à®¤à¯',
      'à®¤à¯†à®³à®¿à®ªà¯à®ªà¯',
      'treatment',
      'medicine',
      'spray',
    ])) {
      return '${disease.isEmpty ? 'à®‡à®¨à¯à®¤ à®ªà®¿à®°à®šà¯à®šà®©à¯ˆà®•à¯à®•à¯' : disease} à®®à¯à®¤à®²à®¿à®²à¯ à®…à®±à®¿à®•à¯à®±à®¿à®•à®³à¯ˆ à®‰à®±à¯à®¤à®¿ à®šà¯†à®¯à¯à®¯à¯à®™à¯à®•à®³à¯. à®®à®¿à®•à®µà¯à®®à¯ à®ªà®¾à®¤à®¿à®•à¯à®•à®ªà¯à®ªà®Ÿà¯à®Ÿ à®šà¯†à®Ÿà®¿à®•à®³à¯ à®…à®²à¯à®²à®¤à¯ à®ªà®•à¯à®¤à®¿à®•à®³à¯ˆ à®®à¯à®Ÿà®¿à®¨à¯à®¤à®¾à®²à¯ à®ªà®¾à®¤à¯à®•à®¾à®ªà¯à®ªà®¾à®• à®…à®•à®±à¯à®±à¯à®™à¯à®•à®³à¯. à®µà®¯à®²à¯ à®šà¯à®•à®¾à®¤à®¾à®°à®¤à¯à®¤à¯ˆ à®ªà®°à®¾à®®à®°à®¿à®¤à¯à®¤à¯, à®µà¯‡à®³à®¾à®£à¯ à®‡à®°à®šà®¾à®¯à®©à®™à¯à®•à®³à¯ˆ à®‰à®³à¯à®³à¯‚à®°à®¿à®²à¯ à®ªà®¤à®¿à®µà¯ à®šà¯†à®¯à¯à®¯à®ªà¯à®ªà®Ÿà¯à®Ÿ à®ªà¯Šà®°à¯à®³à®¿à®©à¯ à®²à¯‡à®ªà®¿à®³à¯ à®®à®±à¯à®±à¯à®®à¯ à®µà¯‡à®³à®¾à®£à¯ à®…à®¤à®¿à®•à®¾à®°à®¿à®¯à®¿à®©à¯ à®†à®²à¯‹à®šà®©à¯ˆà®ªà¯à®ªà®Ÿà®¿ à®®à®Ÿà¯à®Ÿà¯à®®à¯‡ à®ªà®¯à®©à¯à®ªà®Ÿà¯à®¤à¯à®¤à¯à®™à¯à®•à®³à¯.';
    }

    if (_containsAny(question, [
      'à®¤à®Ÿà¯à®ªà¯à®ªà¯',
      'à®ªà®¾à®¤à¯à®•à®¾à®ªà¯à®ªà¯',
      'prevent',
      'prevention',
    ])) {
      return 'à®¨à¯‹à®¯à®±à¯à®± à®¨à®Ÿà®µà¯ à®ªà¯Šà®°à¯à®Ÿà¯à®•à®³à¯ˆ à®ªà®¯à®©à¯à®ªà®Ÿà¯à®¤à¯à®¤à¯à®™à¯à®•à®³à¯, à®µà®¯à®²à¯ à®šà¯à®•à®¾à®¤à®¾à®°à®¤à¯à®¤à¯ˆ à®ªà®°à®¾à®®à®°à®¿à®¯à¯à®™à¯à®•à®³à¯, à®‡à®²à¯ˆà®•à®³à®¿à®²à¯ à®¤à¯‡à®µà¯ˆà®¯à®±à¯à®± à®ˆà®°à®ªà¯à®ªà®¤à®¤à¯à®¤à¯ˆ à®¤à®µà®¿à®°à¯à®•à¯à®•à¯à®™à¯à®•à®³à¯, à®šà®°à®¿à®¯à®¾à®© à®‡à®Ÿà¯ˆà®µà¯†à®³à®¿ à®®à®±à¯à®±à¯à®®à¯ à®µà®Ÿà®¿à®•à®¾à®²à¯ à®µà®šà®¤à®¿ à®µà¯ˆà®¤à¯à®¤à®¿à®°à¯à®™à¯à®•à®³à¯, à®…à®°à¯à®•à®¿à®²à¯à®³à¯à®³ à®šà¯†à®Ÿà®¿à®•à®³à¯ˆ à®¤à¯Šà®Ÿà®°à¯à®¨à¯à®¤à¯ à®•à®£à¯à®•à®¾à®£à®¿à®¯à¯à®™à¯à®•à®³à¯.';
    }

    return 'à®•à®¿à®°à¯à®·à®¿ à®°à®•à¯à®·à®•à¯ ${disease.isEmpty ? 'à®ªà®¯à®¿à®°à®¿à®²à¯ à®’à®°à¯ à®šà®¾à®¤à¯à®¤à®¿à®¯à®®à®¾à®© à®ªà®¿à®°à®šà¯à®šà®©à¯ˆà®¯à¯ˆ' : disease} à®•à®£à¯à®Ÿà®±à®¿à®¨à¯à®¤à¯à®³à¯à®³à®¤à¯${crop.isEmpty ? '' : 'à¥¤ à®ªà®¯à®¿à®°à¯: $crop'}à¥¤ à®¤à¯†à®°à®¿à®¯à¯à®®à¯ à®…à®±à®¿à®•à¯à®±à®¿à®•à®³à¯ˆ à®šà®°à®¿à®ªà®¾à®°à¯à®¤à¯à®¤à¯, à®‡à®°à®šà®¾à®¯à®© à®šà®¿à®•à®¿à®šà¯à®šà¯ˆà®•à¯à®•à¯ à®®à¯à®©à¯ à®‰à®³à¯à®³à¯‚à®°à¯ à®µà¯‡à®³à®¾à®£à¯ à®…à®¤à®¿à®•à®¾à®°à®¿à®¯à®¿à®©à¯ à®†à®²à¯‹à®šà®©à¯ˆà®¯à¯ˆ à®ªà¯†à®±à¯à®™à¯à®•à®³à¯.';
  }

  String _teluguReply(
    String question,
    String crop,
    String disease,
  ) {
    if (_containsAny(question, [
      'à°šà°¿à°•à°¿à°¤à±à°¸',
      'à°®à°‚à°¦à±',
      'à°¸à±à°ªà±à°°à±‡',
      'treatment',
      'medicine',
      'spray',
    ])) {
      return '${disease.isEmpty ? 'à°ˆ à°¸à°®à°¸à±à°¯à°•à±' : disease} à°®à±à°‚à°¦à±à°—à°¾ à°²à°•à±à°·à°£à°¾à°²à°¨à± à°¨à°¿à°°à±à°§à°¾à°°à°¿à°‚à°šà°‚à°¡à°¿. à°Žà°•à±à°•à±à°µà°—à°¾ à°ªà±à°°à°­à°¾à°µà°¿à°¤à°®à±ˆà°¨ à°®à±Šà°•à±à°•à°²à± à°²à±‡à°¦à°¾ à°­à°¾à°—à°¾à°²à°¨à± à°¸à°¾à°§à±à°¯à°®à±ˆà°¨à°ªà±à°ªà±à°¡à± à°¸à±à°°à°•à±à°·à°¿à°¤à°‚à°—à°¾ à°¤à±Šà°²à°—à°¿à°‚à°šà°‚à°¡à°¿. à°ªà±Šà°²à°‚ à°ªà°°à°¿à°¶à±à°­à±à°°à°¤à°¨à± à°ªà°¾à°Ÿà°¿à°‚à°šà°‚à°¡à°¿ à°®à°°à°¿à°¯à± à°µà±à°¯à°µà°¸à°¾à°¯ à°°à°¸à°¾à°¯à°¨à°¾à°²à°¨à± à°¸à±à°¥à°¾à°¨à°¿à°•à°‚à°—à°¾ à°¨à°®à±‹à°¦à± à°šà±‡à°¸à°¿à°¨ à°‰à°¤à±à°ªà°¤à±à°¤à°¿ à°²à±‡à°¬à±à°²à± à°®à°°à°¿à°¯à± à°µà±à°¯à°µà°¸à°¾à°¯ à°…à°§à°¿à°•à°¾à°°à±à°² à°¸à°²à°¹à°¾ à°ªà±à°°à°•à°¾à°°à°‚ à°®à°¾à°¤à±à°°à°®à±‡ à°‰à°ªà°¯à±‹à°—à°¿à°‚à°šà°‚à°¡à°¿.';
    }

    if (_containsAny(question, [
      'à°¨à°¿à°µà°¾à°°à°£',
      'à°°à°•à±à°·à°£',
      'prevent',
      'prevention',
    ])) {
      return 'à°µà±à°¯à°¾à°§à°¿ à°°à°¹à°¿à°¤ à°¨à°¾à°Ÿà±à°² à°ªà°¦à°¾à°°à±à°¥à°¾à°¨à±à°¨à°¿ à°‰à°ªà°¯à±‹à°—à°¿à°‚à°šà°‚à°¡à°¿, à°ªà±Šà°²à°‚ à°ªà°°à°¿à°¶à±à°­à±à°°à°‚à°—à°¾ à°‰à°‚à°šà°‚à°¡à°¿, à°†à°•à±à°²à°ªà±ˆ à°…à°µà°¸à°°à°‚ à°²à±‡à°¨à°¿ à°¤à±‡à°®à°¨à± à°¨à°¿à°µà°¾à°°à°¿à°‚à°šà°‚à°¡à°¿, à°¸à°°à±ˆà°¨ à°¦à±‚à°°à°‚ à°®à°°à°¿à°¯à± à°¨à±€à°Ÿà°¿ à°ªà°¾à°°à±à°¦à°² à°‰à°‚à°¡à±‡à°²à°¾ à°šà±‚à°¡à°‚à°¡à°¿, à°šà±à°Ÿà±à°Ÿà±à°ªà°•à±à°•à°² à°®à±Šà°•à±à°•à°²à°¨à± à°•à±à°°à°®à°‚ à°¤à°ªà±à°ªà°•à±à°‚à°¡à°¾ à°ªà°°à°¿à°¶à±€à°²à°¿à°‚à°šà°‚à°¡à°¿.';
    }

    return 'à°•à±ƒà°·à°¿ à°°à°•à±à°·à°•à± ${disease.isEmpty ? 'à°ªà°‚à°Ÿà°²à±‹ à°’à°• à°¸à°‚à°­à°¾à°µà±à°¯ à°¸à°®à°¸à±à°¯à°¨à±' : disease} à°—à±à°°à±à°¤à°¿à°‚à°šà°¿à°‚à°¦à°¿${crop.isEmpty ? '' : 'à¥¤ à°ªà°‚à°Ÿ: $crop'}à¥¤ à°•à°¨à°¿à°ªà°¿à°‚à°šà±‡ à°²à°•à±à°·à°£à°¾à°²à°¨à± à°ªà°°à°¿à°¶à±€à°²à°¿à°‚à°šà°¿, à°°à°¸à°¾à°¯à°¨ à°šà°¿à°•à°¿à°¤à±à°¸à°•à± à°®à±à°‚à°¦à± à°¸à±à°¥à°¾à°¨à°¿à°• à°µà±à°¯à°µà°¸à°¾à°¯ à°…à°§à°¿à°•à°¾à°°à°¿à°¨à°¿ à°¸à°‚à°ªà±à°°à°¦à°¿à°‚à°šà°‚à°¡à°¿.';
  }

  String _kannadaReply(
    String question,
    String crop,
    String disease,
  ) {
    if (_containsAny(question, [
      'à²šà²¿à²•à²¿à²¤à³à²¸à³†',
      'à²”à²·à²§à²¿',
      'à²¸à²¿à²‚à²ªà²¡à²£à³†',
      'treatment',
      'medicine',
      'spray',
    ])) {
      return '${disease.isEmpty ? 'à²ˆ à²¸à²®à²¸à³à²¯à³†à²—à³†' : disease} à²®à³Šà²¦à²²à³ à²²à²•à³à²·à²£à²—à²³à²¨à³à²¨à³ à²–à²šà²¿à²¤à²ªà²¡à²¿à²¸à²¿à²•à³Šà²³à³à²³à²¿. à²¹à³†à²šà³à²šà³ à²¹à²¾à²¨à²¿à²—à³Šà²³à²—à²¾à²¦ à²¸à²¸à³à²¯à²—à²³à³ à²…à²¥à²µà²¾ à²­à²¾à²—à²—à²³à²¨à³à²¨à³ à²¸à²¾à²§à³à²¯à²µà²¾à²¦à²°à³† à²¸à³à²°à²•à³à²·à²¿à²¤à²µà²¾à²—à²¿ à²¤à³†à²—à³†à²¦à³à²¹à²¾à²•à²¿. à²¹à³Šà²²à²¦ à²¸à³à²µà²šà³à²›à²¤à³†à²¯à²¨à³à²¨à³ à²•à²¾à²ªà²¾à²¡à²¿ à²®à²¤à³à²¤à³ à²•à³ƒà²·à²¿ à²°à²¾à²¸à²¾à²¯à²¨à²¿à²•à²—à²³à²¨à³à²¨à³ à²¸à³à²¥à²³à³€à²¯à²µà²¾à²—à²¿ à²¨à³‹à²‚à²¦à²¾à²¯à²¿à²¤ à²‰à²¤à³à²ªà²¨à³à²¨à²¦ à²²à³‡à²¬à²²à³ à²¹à²¾à²—à³‚ à²•à³ƒà²·à²¿ à²…à²§à²¿à²•à²¾à²°à²¿à²—à²³ à²¸à²²à²¹à³†à²¯à²‚à²¤à³† à²®à²¾à²¤à³à²° à²¬à²³à²¸à²¿.';
    }

    if (_containsAny(question, [
      'à²¤à²¡à³†à²—à²Ÿà³à²Ÿà³à²µà²¿à²•à³†',
      'à²°à²•à³à²·à²£à³†',
      'prevent',
      'prevention',
    ])) {
      return 'à²°à³‹à²—à²®à³à²•à³à²¤ à²¨à³†à²¡à³à²µ à²µà²¸à³à²¤à³à²—à²³à²¨à³à²¨à³ à²¬à²³à²¸à²¿, à²¹à³Šà²²à²¦ à²¸à³à²µà²šà³à²›à²¤à³† à²•à²¾à²ªà²¾à²¡à²¿, à²Žà²²à³†à²—à²³ à²®à³‡à²²à³† à²…à²¨à²—à²¤à³à²¯ à²¤à³‡à²µà²¾à²‚à²¶ à²¤à²ªà³à²ªà²¿à²¸à²¿, à²¸à²°à²¿à²¯à²¾à²¦ à²…à²‚à²¤à²° à²®à²¤à³à²¤à³ à²¨à³€à²°à³ à²¹à²°à²¿à²¯à³à²µ à²µà³à²¯à²µà²¸à³à²¥à³† à²‡à²°à²¿à²¸à²¿ à²¹à²¾à²—à³‚ à²¸à³à²¤à³à²¤à²®à³à²¤à³à²¤à²²à²¿à²¨ à²¸à²¸à³à²¯à²—à²³à²¨à³à²¨à³ à²¨à²¿à²¯à²®à²¿à²¤à²µà²¾à²—à²¿ à²ªà²°à²¿à²¶à³€à²²à²¿à²¸à²¿.';
    }

    return 'à²•à³ƒà²·à²¿ à²°à²•à³à²·à²• ${disease.isEmpty ? 'à²¬à³†à²³à³†à²¯à²²à³à²²à²¿ à²¸à²‚à²­à²µà²¨à³€à²¯ à²¸à²®à²¸à³à²¯à³†à²¯à²¨à³à²¨à³' : disease} à²—à³à²°à³à²¤à²¿à²¸à²¿à²¦à³†${crop.isEmpty ? '' : 'à¥¤ à²¬à³†à²³à³†: $crop'}à¥¤ à²•à²¾à²£à³à²µ à²²à²•à³à²·à²£à²—à²³à²¨à³à²¨à³ à²ªà²°à²¿à²¶à³€à²²à²¿à²¸à²¿ à²®à²¤à³à²¤à³ à²°à²¾à²¸à²¾à²¯à²¨à²¿à²• à²šà²¿à²•à²¿à²¤à³à²¸à³†à²—à³† à²®à³Šà²¦à²²à³ à²¸à³à²¥à²³à³€à²¯ à²•à³ƒà²·à²¿ à²…à²§à²¿à²•à²¾à²°à²¿à²¯ à²¸à²²à²¹à³† à²ªà²¡à³†à²¯à²¿à²°à²¿.';
  }

  String _malayalamReply(
    String question,
    String crop,
    String disease,
  ) {
    if (_containsAny(question, [
      'à´šà´¿à´•à´¿à´¤àµà´¸',
      'à´®à´°àµà´¨àµà´¨àµ',
      'à´¸àµà´ªàµà´°àµ‡',
      'treatment',
      'medicine',
      'spray',
    ])) {
      return '${disease.isEmpty ? 'à´ˆ à´ªàµà´°à´¶àµà´¨à´¤àµà´¤à´¿à´¨àµ' : disease} à´†à´¦àµà´¯à´‚ à´²à´•àµà´·à´£à´™àµà´™àµ¾ à´¸àµà´¥à´¿à´°àµ€à´•à´°à´¿à´•àµà´•àµà´•. à´—àµà´°àµà´¤à´°à´®à´¾à´¯à´¿ à´¬à´¾à´§à´¿à´šàµà´š à´šàµ†à´Ÿà´¿à´•à´³àµ‹ à´­à´¾à´—à´™àµà´™à´³àµ‹ à´¸à´¾à´§àµà´¯à´®àµ†à´™àµà´•à´¿àµ½ à´¸àµà´°à´•àµà´·à´¿à´¤à´®à´¾à´¯à´¿ à´¨àµ€à´•àµà´•à´‚ à´šàµ†à´¯àµà´¯àµà´•. à´•àµƒà´·à´¿à´¯à´¿à´Ÿà´¤àµà´¤à´¿à´¨àµà´±àµ† à´¶àµà´šà´¿à´¤àµà´µà´‚ à´ªà´¾à´²à´¿à´•àµà´•àµà´•à´¯àµà´‚ à´•à´¾àµ¼à´·à´¿à´• à´°à´¾à´¸à´µà´¸àµà´¤àµà´•àµà´•àµ¾ à´ªàµà´°à´¾à´¦àµ‡à´¶à´¿à´•à´®à´¾à´¯à´¿ à´°à´œà´¿à´¸àµà´±àµà´±àµ¼ à´šàµ†à´¯àµà´¤ à´‰àµ½à´ªàµà´ªà´¨àµà´¨à´¤àµà´¤à´¿à´¨àµà´±àµ† à´²àµ‡à´¬à´²àµà´‚ à´•à´¾àµ¼à´·à´¿à´• à´‰à´¦àµà´¯àµ‹à´—à´¸àµà´¥à´°àµà´Ÿàµ† à´¨à´¿àµ¼à´¦àµà´¦àµ‡à´¶à´µàµà´‚ à´…à´¨àµà´¸à´°à´¿à´šàµà´šàµ à´®à´¾à´¤àµà´°à´‚ à´‰à´ªà´¯àµ‹à´—à´¿à´•àµà´•àµà´•à´¯àµà´‚ à´šàµ†à´¯àµà´¯àµà´•.';
    }

    if (_containsAny(question, [
      'à´ªàµà´°à´¤à´¿à´°àµ‹à´§à´‚',
      'à´¸à´‚à´°à´•àµà´·à´£à´‚',
      'prevent',
      'prevention',
    ])) {
      return 'à´°àµ‹à´—à´®àµà´•àµà´¤à´®à´¾à´¯ à´¨à´Ÿàµ€àµ½ à´µà´¸àµà´¤àµà´•àµà´•àµ¾ à´‰à´ªà´¯àµ‹à´—à´¿à´•àµà´•àµà´•, à´•àµƒà´·à´¿à´¯à´¿à´Ÿ à´¶àµà´šà´¿à´¤àµà´µà´‚ à´ªà´¾à´²à´¿à´•àµà´•àµà´•, à´‡à´²à´•à´³à´¿àµ½ à´…à´¨à´¾à´µà´¶àµà´¯à´®à´¾à´¯ à´ˆàµ¼à´ªàµà´ªà´‚ à´’à´´à´¿à´µà´¾à´•àµà´•àµà´•, à´¶à´°à´¿à´¯à´¾à´¯ à´…à´•à´²à´µàµà´‚ à´¨àµ€àµ¼à´µà´¾àµ¼à´šàµà´šà´¯àµà´‚ à´‰à´±à´ªàµà´ªà´¾à´•àµà´•àµà´•, à´¸à´®àµ€à´ªà´¤àµà´¤àµ† à´šàµ†à´Ÿà´¿à´•àµ¾ à´ªà´¤à´¿à´µà´¾à´¯à´¿ à´ªà´°à´¿à´¶àµ‹à´§à´¿à´•àµà´•àµà´•.';
    }

    return 'à´•àµƒà´·à´¿ à´°à´•àµà´·à´•àµ ${disease.isEmpty ? 'à´µà´¿à´³à´¯à´¿àµ½ à´’à´°àµ à´¸à´¾à´§àµà´¯à´¤à´¯àµà´³àµà´³ à´ªàµà´°à´¶àµà´¨à´‚' : disease} à´•à´£àµà´Ÿàµ†à´¤àµà´¤à´¿à´¯à´¿à´Ÿàµà´Ÿàµà´£àµà´Ÿàµ${crop.isEmpty ? '' : 'à¥¤ à´µà´¿à´³: $crop'}à¥¤ à´•à´¾à´£àµà´¨àµà´¨ à´²à´•àµà´·à´£à´™àµà´™àµ¾ à´ªà´°à´¿à´¶àµ‹à´§à´¿à´•àµà´•àµà´•à´¯àµà´‚ à´°à´¾à´¸à´šà´¿à´•à´¿à´¤àµà´¸à´¯àµà´•àµà´•àµ à´®àµà´®àµà´ªàµ à´ªàµà´°à´¾à´¦àµ‡à´¶à´¿à´• à´•à´¾àµ¼à´·à´¿à´• à´‰à´¦àµà´¯àµ‹à´—à´¸àµà´¥à´°àµà´Ÿàµ† à´‰à´ªà´¦àµ‡à´¶à´‚ à´¤àµ‡à´Ÿàµà´•à´¯àµà´‚ à´šàµ†à´¯àµà´¯àµà´•.';
  }

  bool _containsAny(String text, List<String> words) {
    for (final word in words) {
      if (text.contains(word)) {
        return true;
      }
    }

    return false;
  }

  // ============================================================
  // SCROLL
  // ============================================================

  String _detectQueryLanguage(String text, String selected) {
    final q = text.trim();
    if (q.isEmpty) return selected;

    if (RegExp(r'[\\u0B80-\\u0BFF]').hasMatch(q)) return 'ta';
    if (RegExp(r'[\\u0C00-\\u0C7F]').hasMatch(q)) return 'te';
    if (RegExp(r'[\\u0C80-\\u0CFF]').hasMatch(q)) return 'kn';
    if (RegExp(r'[\\u0D00-\\u0D7F]').hasMatch(q)) return 'ml';
    if (RegExp(r'[\\u0980-\\u09FF]').hasMatch(q)) return 'bn';
    if (RegExp(r'[\\u0A80-\\u0AFF]').hasMatch(q)) return 'gu';
    if (RegExp(r'[\\u0A00-\\u0A7F]').hasMatch(q)) return 'pa';
    if (RegExp(r'[\\u0900-\\u097F]').hasMatch(q)) return selected == 'mr' ? 'mr' : 'hi';

    final lower = q.toLowerCase();
    final words = lower.split(RegExp(r'[^a-zA-Z]+')).where((w) => w.isNotEmpty).toSet();
    const hinglishWords = {
      'kya','kaise','kaisa','kaisi','kyu','kyon','kyunki','hai','hain','ho','hoga','hogi',
      'tha','thi','the','mein','me','mera','meri','mere','aap','apka','apki','tum','tumhara',
      'mujhe','mujhko','hum','hume','karna','karo','kare','karen','karta','karte','krna','krke',
      'ka','ke','ki','ko','se','par','ya','aur','bhi','bahut','acha','achha','chahiye','nahi',
      'nahin','haan','han','ab','kab','kahan','iska','uska','isliye','fir','phir','wala','wali',
      'wale','lagao','batao','bata','btao','samjhao','paani','pani','fasal','kheti','kisan','rog',
      'dawai','dawa','ilaaj','ilaj','upay','mitti','beej','sinchai','khad','gehun','gehu','chawal',
      'aam','tamatar','sabzi'
    };
    if (words.intersection(hinglishWords).isNotEmpty) return 'hinglish';

    return selected == 'hinglish' ? 'hinglish' : 'en';
  }

  Future<void> _scrollToBottom() async {
    await Future<void>.delayed(
      const Duration(milliseconds: 80),
    );

    if (!mounted || !scroll.hasClients) {
      return;
    }

    await scroll.animateTo(
      scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final lang = LanguageScope.of(context).value;

    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF2),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        title: Text(
          tr(context, 'askAI'),
        ),
      ),
      body: Column(
        children: [
          if (widget.initialDisease.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: const Color(0xFFE8F5E9),
              child: Text(
                '${tr(context, 'currentDisease')}: '
                '${diseaseLabel(widget.initialDisease, lang)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          Expanded(
            child: ListView.builder(
              controller: scroll,
              padding: const EdgeInsets.all(14),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];

                final isUser = message['role'] == 'user';
                final content = message['content'] ?? '';

                return Align(
                  alignment: isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(
                      bottom: 10,
                    ),
                    padding: const EdgeInsets.all(14),
                    constraints: const BoxConstraints(
                      maxWidth: 350,
                    ),
                    decoration: BoxDecoration(
                      color: isUser
                          ? const Color(0xFF2E7D32)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _buildMessageContent(
                      content,
                      isUser,
                    ),
                  ),
                );
              },
            ),
          ),

          if (loading)
            Padding(
              padding: const EdgeInsets.only(
                bottom: 6,
              ),
              child: Text(
                _thinkingText(),
                style: const TextStyle(
                  color: Colors.black54,
                ),
              ),
            ),

          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                10,
                6,
                10,
                10,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => send(),
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: tr(context, 'askHint'),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  IconButton.filled(
                    onPressed: loading ? null : send,
                    icon: const Icon(
                      Icons.send_rounded,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(String content, bool isUser) {
    final baseColor = isUser ? Colors.white : Colors.black87;
    final lines = content.split('\n');
    final spans = <TextSpan>[];

    for (int i = 0; i < lines.length; i++) {
      var line = lines[i].trimRight();
      final trimmedLine = line.trimLeft();

      TextStyle style = TextStyle(
        color: baseColor,
        height: 1.5,
        fontSize: 15,
      );

      if (trimmedLine.startsWith('### ')) {
        line = trimmedLine.substring(4);
        style = style.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w700,
        );
      } else if (trimmedLine.startsWith('## ')) {
        line = trimmedLine.substring(3);
        style = style.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w700,
        );
      } else if (trimmedLine.startsWith('# ')) {
        line = trimmedLine.substring(2);
        style = style.copyWith(
          fontSize: 19,
          fontWeight: FontWeight.w700,
        );
      } else if (trimmedLine.startsWith('* ') ||
          trimmedLine.startsWith('- ')) {
        line = '• ${trimmedLine.substring(2)}';
      }

      final boldPattern = RegExp(r'\\*\\*(.+?)\\*\\*');
      var cursor = 0;

      for (final match in boldPattern.allMatches(line)) {
        if (match.start > cursor) {
          spans.add(
            TextSpan(
              text: line.substring(cursor, match.start),
              style: style,
            ),
          );
        }

        spans.add(
          TextSpan(
            text: match.group(1),
            style: style.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        );

        cursor = match.end;
      }

      if (cursor < line.length) {
        spans.add(
          TextSpan(
            text: line.substring(cursor),
            style: style,
          ),
        );
      }

      if (i < lines.length - 1) {
        spans.add(
          TextSpan(
            text: '\n',
            style: style,
          ),
        );
      }
    }

    return SelectableText.rich(
      TextSpan(children: spans),
    );
  }

  String _thinkingText() {
    switch (selectedLanguage) {
      case 'hi':
        return 'à¤•à¥ƒà¤·à¤¿ à¤°à¤•à¥à¤·à¤• à¤¸à¥‹à¤š à¤°à¤¹à¤¾ à¤¹à¥ˆ...';

      case 'pa':
        return 'à¨•à©à¨°à¨¿à¨¸à¨¼à©€ à¨°à¨•à¨¸à¨¼à¨• à¨¸à©‹à¨š à¨°à¨¿à¨¹à¨¾ à¨¹à©ˆ...';

      case 'mr':
        return 'à¤•à¥ƒà¤·à¥€ à¤°à¤•à¥à¤·à¤• à¤µà¤¿à¤šà¤¾à¤° à¤•à¤°à¤¤ à¤†à¤¹à¥‡...';

      case 'bn':
        return 'à¦•à§ƒà¦·à¦¿ à¦°à¦•à§à¦·à¦• à¦šà¦¿à¦¨à§à¦¤à¦¾ à¦•à¦°à¦›à§‡...';

      case 'gu':
        return 'àª•à«ƒàª·àª¿ àª°àª•à«àª·àª• àªµàª¿àªšàª¾àª°à«€ àª°àª¹à«àª¯à«àª‚ àª›à«‡...';

      case 'ta':
        return 'à®•à®¿à®°à¯à®·à®¿ à®°à®•à¯à®·à®•à¯ à®¯à¯‹à®šà®¿à®•à¯à®•à®¿à®±à®¤à¯...';

      case 'te':
        return 'à°•à±ƒà°·à°¿ à°°à°•à±à°·à°•à± à°†à°²à±‹à°šà°¿à°¸à±à°¤à±‹à°‚à°¦à°¿...';

      case 'kn':
        return 'à²•à³ƒà²·à²¿ à²°à²•à³à²·à²• à²¯à³‹à²šà²¿à²¸à³à²¤à³à²¤à²¿à²¦à³†...';

      case 'ml':
        return 'à´•àµƒà´·à´¿ à´°à´•àµà´·à´•àµ à´šà´¿à´¨àµà´¤à´¿à´•àµà´•àµà´¨àµà´¨àµ...';

      case 'en':
      default:
        return 'Krishi Rakshak is thinking...';
    }
  }

  @override
  void dispose() {
    controller.dispose();
    scroll.dispose();

    super.dispose();
  }
}
