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
  static const String backendUrl = 'https://krishi-rakshak-vtla.onrender.com';

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
            },
            body: jsonEncode({
              'message': text,
              'language': selectedLanguage,
              'context': {
                'crop': widget.initialCrop,
                'disease': widget.initialDisease,
                'confidence': widget.initialConfidence,
              },
              'history': messages,
            }),
          )
          .timeout(
            const Duration(seconds: 60),
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

      String? answer;

      if (decoded['answer'] != null) {
        answer = decoded['answer'].toString().trim();
      } else if (decoded['reply'] != null) {
        answer = decoded['reply'].toString().trim();
      }

      if (answer == null || answer.isEmpty) {
        throw Exception('Empty AI response');
      }

      if (!mounted) {
        return;
      }

      setState(() {
        messages.add({
          'role': 'assistant',
          'content': answer!,
        });

        loading = false;
      });

      _scrollToBottom();
    } catch (e) {
      debugPrint('AI CHAT FAILED: $e');

      // ----------------------------------------------------------
      // INTERNET / SERVER FAILS
      // USE LOCAL LANGUAGE FALLBACK
      // ----------------------------------------------------------

      final localReply = _localAiReply(text);

      if (!mounted) {
        return;
      }

      setState(() {
        messages.add({
          'role': 'assistant',
          'content': localReply,
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
      'इलाज',
      'दवा',
      'स्प्रे',
      'treatment',
      'medicine',
      'spray',
    ])) {
      return '${disease.isEmpty ? 'इस समस्या' : disease} के लिए पहले लक्षणों की पुष्टि करें। बहुत अधिक प्रभावित पौधों या भागों को जहाँ संभव हो सुरक्षित तरीके से हटाएँ, खेत की स्वच्छता बनाए रखें और किसी भी कृषि रसायन का उपयोग केवल स्थानीय रूप से पंजीकृत उत्पाद के लेबल तथा कृषि विभाग की सलाह के अनुसार करें।';
    }

    if (_containsAny(question, [
      'बचाव',
      'रोकथाम',
      'prevent',
      'prevention',
      'avoid',
    ])) {
      return 'स्वस्थ और रोगमुक्त रोपण सामग्री का उपयोग करें, खेत की स्वच्छता रखें, अनावश्यक पत्तियों की नमी से बचें, उचित दूरी और जल निकासी रखें तथा आसपास के पौधों की नियमित जाँच करें।';
    }

    return 'कृषि रक्षक ने ${disease.isEmpty ? 'फसल में संभावित समस्या' : disease} की पहचान की है${crop.isEmpty ? '' : '। फसल: $crop'}। दिखाई देने वाले लक्षणों की जाँच करें और किसी भी रासायनिक उपचार से पहले स्थानीय कृषि अधिकारी की सलाह लें।';
  }

  String _punjabiReply(
    String question,
    String crop,
    String disease,
  ) {
    if (_containsAny(question, [
      'ਇਲਾਜ',
      'ਦਵਾਈ',
      'ਸਪਰੇ',
      'treatment',
      'medicine',
      'spray',
    ])) {
      return '${disease.isEmpty ? 'ਇਸ ਸਮੱਸਿਆ' : disease} ਲਈ ਪਹਿਲਾਂ ਲੱਛਣਾਂ ਦੀ ਪੁਸ਼ਟੀ ਕਰੋ। ਬਹੁਤ ਪ੍ਰਭਾਵਿਤ ਪੌਦਿਆਂ ਜਾਂ ਹਿੱਸਿਆਂ ਨੂੰ ਜਿੱਥੇ ਸੰਭਵ ਹੋਵੇ ਸੁਰੱਖਿਅਤ ਢੰਗ ਨਾਲ ਹਟਾਓ। ਖੇਤ ਦੀ ਸਫਾਈ ਰੱਖੋ ਅਤੇ ਕਿਸੇ ਵੀ ਖੇਤੀਬਾੜੀ ਦਵਾਈ ਦੀ ਵਰਤੋਂ ਸਿਰਫ਼ ਸਥਾਨਕ ਤੌਰ ਤੇ ਰਜਿਸਟਰ ਕੀਤੇ ਉਤਪਾਦ ਦੇ ਲੇਬਲ ਅਤੇ ਖੇਤੀਬਾੜੀ ਵਿਭਾਗ ਦੀ ਸਲਾਹ ਅਨੁਸਾਰ ਕਰੋ।';
    }

    if (_containsAny(question, [
      'ਬਚਾਅ',
      'ਰੋਕਥਾਮ',
      'prevent',
      'prevention',
    ])) {
      return 'ਸਿਹਤਮੰਦ ਅਤੇ ਰੋਗਮੁਕਤ ਪੌਧਾ ਸਮੱਗਰੀ ਵਰਤੋ, ਖੇਤ ਦੀ ਸਫਾਈ ਰੱਖੋ, ਪੱਤਿਆਂ ਉੱਤੇ ਬੇਲੋੜੀ ਨਮੀ ਤੋਂ ਬਚੋ, ਠੀਕ ਦੂਰੀ ਅਤੇ ਪਾਣੀ ਦੀ ਨਿਕਾਸੀ ਰੱਖੋ ਅਤੇ ਨੇੜਲੇ ਪੌਦਿਆਂ ਦੀ ਨਿਯਮਿਤ ਜਾਂਚ ਕਰੋ।';
    }

    return 'ਕ੍ਰਿਸ਼ੀ ਰਕਸ਼ਕ ਨੇ ${disease.isEmpty ? 'ਫਸਲ ਵਿੱਚ ਸੰਭਾਵਿਤ ਸਮੱਸਿਆ' : disease} ਦੀ ਪਛਾਣ ਕੀਤੀ ਹੈ${crop.isEmpty ? '' : '। ਫਸਲ: $crop'}। ਲੱਛਣਾਂ ਦੀ ਜਾਂਚ ਕਰੋ ਅਤੇ ਰਸਾਇਣਕ ਇਲਾਜ ਤੋਂ ਪਹਿਲਾਂ ਸਥਾਨਕ ਖੇਤੀਬਾੜੀ ਅਧਿਕਾਰੀ ਦੀ ਸਲਾਹ ਲਵੋ।';
  }

  String _marathiReply(
    String question,
    String crop,
    String disease,
  ) {
    if (_containsAny(question, [
      'उपचार',
      'औषध',
      'फवारणी',
      'treatment',
      'medicine',
      'spray',
    ])) {
      return '${disease.isEmpty ? 'या समस्येसाठी' : disease} प्रथम लक्षणांची खात्री करा. जास्त बाधित झाडांचे किंवा भागांचे नुकसान झालेले साहित्य शक्य असल्यास सुरक्षितपणे काढून टाका. शेताची स्वच्छता ठेवा आणि कोणतेही कृषी रसायन फक्त स्थानिक नोंदणीकृत उत्पादनाच्या लेबलनुसार व कृषी विभागाच्या सल्ल्याने वापरा.';
    }

    if (_containsAny(question, [
      'प्रतिबंध',
      'बचाव',
      'prevent',
      'prevention',
    ])) {
      return 'निरोगी व रोगमुक्त लागवड साहित्य वापरा, शेताची स्वच्छता ठेवा, पानांवर अनावश्यक ओलावा टाळा, योग्य अंतर व निचरा ठेवा आणि आसपासच्या झाडांची नियमित तपासणी करा.';
    }

    return 'कृषी रक्षकने ${disease.isEmpty ? 'पिकामध्ये संभाव्य समस्या' : disease} ओळखली आहे${crop.isEmpty ? '' : '। पीक: $crop'}। लक्षणांची तपासणी करा आणि रासायनिक उपचार करण्यापूर्वी स्थानिक कृषी अधिकाऱ्यांचा सल्ला घ्या.';
  }

  String _bengaliReply(
    String question,
    String crop,
    String disease,
  ) {
    if (_containsAny(question, [
      'চিকিৎসা',
      'ওষুধ',
      'স্প্রে',
      'treatment',
      'medicine',
      'spray',
    ])) {
      return '${disease.isEmpty ? 'এই সমস্যার' : disease} ক্ষেত্রে প্রথমে লক্ষণ নিশ্চিত করুন। বেশি আক্রান্ত গাছ বা অংশ সম্ভব হলে নিরাপদভাবে সরিয়ে ফেলুন। জমির পরিচ্ছন্নতা বজায় রাখুন এবং কৃষি রাসায়নিক শুধুমাত্র স্থানীয়ভাবে নিবন্ধিত পণ্যের লেবেল ও কৃষি বিভাগের পরামর্শ অনুযায়ী ব্যবহার করুন।';
    }

    if (_containsAny(question, [
      'প্রতিরোধ',
      'বাঁচানো',
      'prevent',
      'prevention',
    ])) {
      return 'রোগমুক্ত রোপণ উপকরণ ব্যবহার করুন, জমি পরিষ্কার রাখুন, পাতায় অতিরিক্ত আর্দ্রতা এড়িয়ে চলুন, পর্যাপ্ত দূরত্ব ও নিষ্কাশন বজায় রাখুন এবং আশেপাশের গাছ নিয়মিত পরীক্ষা করুন।';
    }

    return 'কৃষি রক্ষক ${disease.isEmpty ? 'ফসলে একটি সম্ভাব্য সমস্যা' : disease} শনাক্ত করেছে${crop.isEmpty ? '' : '। ফসল: $crop'}। দৃশ্যমান লক্ষণ পরীক্ষা করুন এবং রাসায়নিক চিকিৎসার আগে স্থানীয় কৃষি কর্মকর্তার পরামর্শ নিন।';
  }

  String _gujaratiReply(
    String question,
    String crop,
    String disease,
  ) {
    if (_containsAny(question, [
      'સારવાર',
      'દવા',
      'છંટકાવ',
      'treatment',
      'medicine',
      'spray',
    ])) {
      return '${disease.isEmpty ? 'આ સમસ્યા માટે' : disease} પહેલા લક્ષણોની ખાતરી કરો. વધારે અસરગ્રસ્ત છોડ અથવા ભાગોને શક્ય હોય તો સુરક્ષિત રીતે દૂર કરો. ખેતરની સ્વચ્છતા જાળવો અને કોઈપણ કૃષિ દવાનો ઉપયોગ માત્ર સ્થાનિક રીતે નોંધાયેલ ઉત્પાદનના લેબલ તથા કૃષિ વિભાગની સલાહ મુજબ કરો.';
    }

    if (_containsAny(question, [
      'બચાવ',
      'નિવારણ',
      'prevent',
      'prevention',
    ])) {
      return 'રોગમુક્ત વાવેતર સામગ્રીનો ઉપયોગ કરો, ખેતરની સ્વચ્છતા જાળવો, પાંદડાં પર બિનજરૂરી ભેજ ટાળો, યોગ્ય અંતર અને પાણીનો નિકાલ રાખો અને આસપાસના છોડની નિયમિત તપાસ કરો.';
    }

    return 'કૃષિ રક્ષકે ${disease.isEmpty ? 'પાકમાં સંભવિત સમસ્યા' : disease} ઓળખી છે${crop.isEmpty ? '' : '। પાક: $crop'}। દેખાતા લક્ષણોની તપાસ કરો અને રાસાયણિક સારવાર પહેલાં સ્થાનિક કૃષિ અધિકારીની સલાહ લો.';
  }

  String _tamilReply(
    String question,
    String crop,
    String disease,
  ) {
    if (_containsAny(question, [
      'சிகிச்சை',
      'மருந்து',
      'தெளிப்பு',
      'treatment',
      'medicine',
      'spray',
    ])) {
      return '${disease.isEmpty ? 'இந்த பிரச்சனைக்கு' : disease} முதலில் அறிகுறிகளை உறுதி செய்யுங்கள். மிகவும் பாதிக்கப்பட்ட செடிகள் அல்லது பகுதிகளை முடிந்தால் பாதுகாப்பாக அகற்றுங்கள். வயல் சுகாதாரத்தை பராமரித்து, வேளாண் இரசாயனங்களை உள்ளூரில் பதிவு செய்யப்பட்ட பொருளின் லேபிள் மற்றும் வேளாண் அதிகாரியின் ஆலோசனைப்படி மட்டுமே பயன்படுத்துங்கள்.';
    }

    if (_containsAny(question, [
      'தடுப்பு',
      'பாதுகாப்பு',
      'prevent',
      'prevention',
    ])) {
      return 'நோயற்ற நடவு பொருட்களை பயன்படுத்துங்கள், வயல் சுகாதாரத்தை பராமரியுங்கள், இலைகளில் தேவையற்ற ஈரப்பதத்தை தவிர்க்குங்கள், சரியான இடைவெளி மற்றும் வடிகால் வசதி வைத்திருங்கள், அருகிலுள்ள செடிகளை தொடர்ந்து கண்காணியுங்கள்.';
    }

    return 'கிருஷி ரக்ஷக் ${disease.isEmpty ? 'பயிரில் ஒரு சாத்தியமான பிரச்சனையை' : disease} கண்டறிந்துள்ளது${crop.isEmpty ? '' : '। பயிர்: $crop'}। தெரியும் அறிகுறிகளை சரிபார்த்து, இரசாயன சிகிச்சைக்கு முன் உள்ளூர் வேளாண் அதிகாரியின் ஆலோசனையை பெறுங்கள்.';
  }

  String _teluguReply(
    String question,
    String crop,
    String disease,
  ) {
    if (_containsAny(question, [
      'చికిత్స',
      'మందు',
      'స్ప్రే',
      'treatment',
      'medicine',
      'spray',
    ])) {
      return '${disease.isEmpty ? 'ఈ సమస్యకు' : disease} ముందుగా లక్షణాలను నిర్ధారించండి. ఎక్కువగా ప్రభావితమైన మొక్కలు లేదా భాగాలను సాధ్యమైనప్పుడు సురక్షితంగా తొలగించండి. పొలం పరిశుభ్రతను పాటించండి మరియు వ్యవసాయ రసాయనాలను స్థానికంగా నమోదు చేసిన ఉత్పత్తి లేబుల్ మరియు వ్యవసాయ అధికారుల సలహా ప్రకారం మాత్రమే ఉపయోగించండి.';
    }

    if (_containsAny(question, [
      'నివారణ',
      'రక్షణ',
      'prevent',
      'prevention',
    ])) {
      return 'వ్యాధి రహిత నాట్ల పదార్థాన్ని ఉపయోగించండి, పొలం పరిశుభ్రంగా ఉంచండి, ఆకులపై అవసరం లేని తేమను నివారించండి, సరైన దూరం మరియు నీటి పారుదల ఉండేలా చూడండి, చుట్టుపక్కల మొక్కలను క్రమం తప్పకుండా పరిశీలించండి.';
    }

    return 'కృషి రక్షక్ ${disease.isEmpty ? 'పంటలో ఒక సంభావ్య సమస్యను' : disease} గుర్తించింది${crop.isEmpty ? '' : '। పంట: $crop'}। కనిపించే లక్షణాలను పరిశీలించి, రసాయన చికిత్సకు ముందు స్థానిక వ్యవసాయ అధికారిని సంప్రదించండి.';
  }

  String _kannadaReply(
    String question,
    String crop,
    String disease,
  ) {
    if (_containsAny(question, [
      'ಚಿಕಿತ್ಸೆ',
      'ಔಷಧಿ',
      'ಸಿಂಪಡಣೆ',
      'treatment',
      'medicine',
      'spray',
    ])) {
      return '${disease.isEmpty ? 'ಈ ಸಮಸ್ಯೆಗೆ' : disease} ಮೊದಲು ಲಕ್ಷಣಗಳನ್ನು ಖಚಿತಪಡಿಸಿಕೊಳ್ಳಿ. ಹೆಚ್ಚು ಹಾನಿಗೊಳಗಾದ ಸಸ್ಯಗಳು ಅಥವಾ ಭಾಗಗಳನ್ನು ಸಾಧ್ಯವಾದರೆ ಸುರಕ್ಷಿತವಾಗಿ ತೆಗೆದುಹಾಕಿ. ಹೊಲದ ಸ್ವಚ್ಛತೆಯನ್ನು ಕಾಪಾಡಿ ಮತ್ತು ಕೃಷಿ ರಾಸಾಯನಿಕಗಳನ್ನು ಸ್ಥಳೀಯವಾಗಿ ನೋಂದಾಯಿತ ಉತ್ಪನ್ನದ ಲೇಬಲ್ ಹಾಗೂ ಕೃಷಿ ಅಧಿಕಾರಿಗಳ ಸಲಹೆಯಂತೆ ಮಾತ್ರ ಬಳಸಿ.';
    }

    if (_containsAny(question, [
      'ತಡೆಗಟ್ಟುವಿಕೆ',
      'ರಕ್ಷಣೆ',
      'prevent',
      'prevention',
    ])) {
      return 'ರೋಗಮುಕ್ತ ನೆಡುವ ವಸ್ತುಗಳನ್ನು ಬಳಸಿ, ಹೊಲದ ಸ್ವಚ್ಛತೆ ಕಾಪಾಡಿ, ಎಲೆಗಳ ಮೇಲೆ ಅನಗತ್ಯ ತೇವಾಂಶ ತಪ್ಪಿಸಿ, ಸರಿಯಾದ ಅಂತರ ಮತ್ತು ನೀರು ಹರಿಯುವ ವ್ಯವಸ್ಥೆ ಇರಿಸಿ ಹಾಗೂ ಸುತ್ತಮುತ್ತಲಿನ ಸಸ್ಯಗಳನ್ನು ನಿಯಮಿತವಾಗಿ ಪರಿಶೀಲಿಸಿ.';
    }

    return 'ಕೃಷಿ ರಕ್ಷಕ ${disease.isEmpty ? 'ಬೆಳೆಯಲ್ಲಿ ಸಂಭವನೀಯ ಸಮಸ್ಯೆಯನ್ನು' : disease} ಗುರುತಿಸಿದೆ${crop.isEmpty ? '' : '। ಬೆಳೆ: $crop'}। ಕಾಣುವ ಲಕ್ಷಣಗಳನ್ನು ಪರಿಶೀಲಿಸಿ ಮತ್ತು ರಾಸಾಯನಿಕ ಚಿಕಿತ್ಸೆಗೆ ಮೊದಲು ಸ್ಥಳೀಯ ಕೃಷಿ ಅಧಿಕಾರಿಯ ಸಲಹೆ ಪಡೆಯಿರಿ.';
  }

  String _malayalamReply(
    String question,
    String crop,
    String disease,
  ) {
    if (_containsAny(question, [
      'ചികിത്സ',
      'മരുന്ന്',
      'സ്പ്രേ',
      'treatment',
      'medicine',
      'spray',
    ])) {
      return '${disease.isEmpty ? 'ഈ പ്രശ്നത്തിന്' : disease} ആദ്യം ലക്ഷണങ്ങൾ സ്ഥിരീകരിക്കുക. ഗുരുതരമായി ബാധിച്ച ചെടികളോ ഭാഗങ്ങളോ സാധ്യമെങ്കിൽ സുരക്ഷിതമായി നീക്കം ചെയ്യുക. കൃഷിയിടത്തിന്റെ ശുചിത്വം പാലിക്കുകയും കാർഷിക രാസവസ്തുക്കൾ പ്രാദേശികമായി രജിസ്റ്റർ ചെയ്ത ഉൽപ്പന്നത്തിന്റെ ലേബലും കാർഷിക ഉദ്യോഗസ്ഥരുടെ നിർദ്ദേശവും അനുസരിച്ച് മാത്രം ഉപയോഗിക്കുകയും ചെയ്യുക.';
    }

    if (_containsAny(question, [
      'പ്രതിരോധം',
      'സംരക്ഷണം',
      'prevent',
      'prevention',
    ])) {
      return 'രോഗമുക്തമായ നടീൽ വസ്തുക്കൾ ഉപയോഗിക്കുക, കൃഷിയിട ശുചിത്വം പാലിക്കുക, ഇലകളിൽ അനാവശ്യമായ ഈർപ്പം ഒഴിവാക്കുക, ശരിയായ അകലവും നീർവാർച്ചയും ഉറപ്പാക്കുക, സമീപത്തെ ചെടികൾ പതിവായി പരിശോധിക്കുക.';
    }

    return 'കൃഷി രക്ഷക് ${disease.isEmpty ? 'വിളയിൽ ഒരു സാധ്യതയുള്ള പ്രശ്നം' : disease} കണ്ടെത്തിയിട്ടുണ്ട്${crop.isEmpty ? '' : '। വിള: $crop'}। കാണുന്ന ലക്ഷണങ്ങൾ പരിശോധിക്കുകയും രാസചികിത്സയ്ക്ക് മുമ്പ് പ്രാദേശിക കാർഷിക ഉദ്യോഗസ്ഥരുടെ ഉപദേശം തേടുകയും ചെയ്യുക.';
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
                    child: Text(
                      content,
                      style: TextStyle(
                        color: isUser
                            ? Colors.white
                            : Colors.black87,
                        height: 1.45,
                        fontSize: 15,
                      ),
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

  String _thinkingText() {
    switch (selectedLanguage) {
      case 'hi':
        return 'कृषि रक्षक सोच रहा है...';

      case 'pa':
        return 'ਕ੍ਰਿਸ਼ੀ ਰਕਸ਼ਕ ਸੋਚ ਰਿਹਾ ਹੈ...';

      case 'mr':
        return 'कृषी रक्षक विचार करत आहे...';

      case 'bn':
        return 'কৃষি রক্ষক চিন্তা করছে...';

      case 'gu':
        return 'કૃષિ રક્ષક વિચારી રહ્યું છે...';

      case 'ta':
        return 'கிருஷி ரக்ஷக் யோசிக்கிறது...';

      case 'te':
        return 'కృషి రక్షక్ ఆలోచిస్తోంది...';

      case 'kn':
        return 'ಕೃಷಿ ರಕ್ಷಕ ಯೋಚಿಸುತ್ತಿದೆ...';

      case 'ml':
        return 'കൃഷി രക്ഷക് ചിന്തിക്കുന്നു...';

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