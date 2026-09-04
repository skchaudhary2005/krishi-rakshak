import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../language.dart';

class ExpertAgricultureScreen extends StatefulWidget {
  const ExpertAgricultureScreen({super.key});

  @override
  State<ExpertAgricultureScreen> createState() =>
      _ExpertAgricultureScreenState();
}

class _ExpertAgricultureScreenState extends State<ExpertAgricultureScreen> {
  String _query = '';

  String get _lang => LanguageScope.of(context).value;

  @override
  Widget build(BuildContext context) {
    final topics = _topics(_lang);
    final filtered = topics.where((topic) {
      final q = _query.trim().toLowerCase();
      if (q.isEmpty) return true;
      return topic.title.toLowerCase().contains(q) ||
          topic.summary.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF2),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        title: Text(_text(_lang, 'title')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 27,
                    backgroundColor: Color(0xFFE8F5E9),
                    child: Icon(
                      Icons.agriculture_rounded,
                      color: Color(0xFF2E7D32),
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _text(_lang, 'heading'),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B5E20),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _text(_lang, 'subtitle'),
                          style: const TextStyle(height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: _text(_lang, 'search'),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () => setState(() => _query = ''),
                      icon: const Icon(Icons.clear_rounded),
                    ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (filtered.isEmpty)
            _empty()
          else
            ...filtered.map(_topicCard),
          const SizedBox(height: 12),
          _buildExpertDirectory(),
          const SizedBox(height: 12),
          Card(
            color: const Color(0xFFFFF8E1),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _text(_lang, 'warning'),
                      style: const TextStyle(height: 1.4),
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

  Widget _topicCard(_ExpertTopic topic) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetails(topic),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFE8F5E9),
                child: Icon(topic.icon, color: const Color(0xFF2E7D32)),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      topic.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black54,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpertDirectory() {
    final experts = _expertContacts(_lang);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFE8F5E9),
                  child: Icon(
                    Icons.support_agent_rounded,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _text(_lang, 'expertDirectory'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              _text(_lang, 'expertDirectorySub'),
              style: const TextStyle(
                color: Colors.black54,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            ...experts.map(_expertCard),
          ],
        ),
      ),
    );
  }

  Widget _expertCard(_ExpertContact expert) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBF6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0EEDD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            expert.name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            expert.designation,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            expert.organization,
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 8),
          _contactRow(Icons.location_on_outlined, expert.location),
          const SizedBox(height: 4),
          _contactRow(Icons.phone_outlined, expert.phone),
          const SizedBox(height: 4),
          _contactRow(Icons.email_outlined, expert.email),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _callExpert(expert.phone),
                  icon: const Icon(Icons.call_rounded, size: 18),
                  label: Text(_text(_lang, 'call')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _emailExpert(expert.email),
                  icon: const Icon(Icons.email_rounded, size: 18),
                  label: Text(_text(_lang, 'email')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _contactRow(IconData icon, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: const Color(0xFF2E7D32)),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(height: 1.3),
          ),
        ),
      ],
    );
  }

  Future<void> _callExpert(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^0-9+]'), ''));
    try {
      if (!await launchUrl(uri)) {
        _showContactMessage(_text(_lang, 'contactUnavailable'));
      }
    } catch (_) {
      _showContactMessage(_text(_lang, 'contactUnavailable'));
    }
  }

  Future<void> _emailExpert(String email) async {
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: <String, String>{
        'subject': _text(_lang, 'emailSubject'),
      },
    );
    try {
      if (!await launchUrl(uri)) {
        _showContactMessage(_text(_lang, 'contactUnavailable'));
      }
    } catch (_) {
      _showContactMessage(_text(_lang, 'contactUnavailable'));
    }
  }

  void _showContactMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  static List<_ExpertContact> _expertContacts(String lang) {
    // Public institutional referral contacts. No private/personal numbers are
    // invented here. These can be replaced later with verified local KVK
    // contacts for the farmer's district.
    final label = lang == 'hi'
        ? 'कृषि विशेषज्ञ / संस्थागत सहायता'
        : 'Agriculture expert / institutional support';

    return [
      _ExpertContact(
        name: 'Kisan Call Centre',
        designation: label,
        organization: 'Ministry of Agriculture & Farmers Welfare, Government of India',
        location: 'India',
        phone: '18001801551',
        email: 'farmer-call@agri.gov.in',
      ),
      _ExpertContact(
        name: 'ICAR – Krishi Vigyan Kendra Network',
        designation: label,
        organization: 'Indian Council of Agricultural Research',
        location: 'India — contact the nearest KVK',
        phone: '011-25842778',
        email: 'icar@icar.gov.in',
      ),
      _ExpertContact(
        name: 'ICAR – Agricultural Technology Application Research Institute',
        designation: label,
        organization: 'Indian Council of Agricultural Research',
        location: 'India — regional agricultural support',
        phone: '011-25841416',
        email: 'dg.icar@icar.gov.in',
      ),
      _ExpertContact(
        name: 'National Horticulture Board',
        designation: label,
        organization: 'Ministry of Agriculture & Farmers Welfare',
        location: 'Gurugram, Haryana',
        phone: '0124-2342992',
        email: 'nhb@nic.in',
      ),
      _ExpertContact(
        name: 'Agricultural Scientists Recruitment Board / ICAR',
        designation: label,
        organization: 'ICAR',
        location: 'New Delhi, India',
        phone: '011-25843274',
        email: 'icar@icar.gov.in',
      ),
    ];
  }

  Widget _empty() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 60,
              color: Colors.green,
            ),
            const SizedBox(height: 10),
            Text(
              _text(_lang, 'noResults'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(_ExpertTopic topic) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.72,
            minChildSize: 0.45,
            maxChildSize: 0.94,
            builder: (_, controller) {
              return ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: const Color(0xFFE8F5E9),
                        child: Icon(
                          topic.icon,
                          color: const Color(0xFF2E7D32),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          topic.title,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B5E20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  ...topic.sections.map(
                    (section) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            section.heading,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            section.body,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  static String _text(String lang, String key) {
    const values = <String, Map<String, String>>{
      'en': {
        'title': 'Expert Agriculture',
        'heading': 'Expert Agriculture Information',
        'subtitle':
            'Practical guidance for crops, soil, irrigation, nutrients, pests, diseases, weather and post-harvest management.',
        'expertDirectory': 'Agriculture Expert Contacts',
        'expertDirectorySub': 'Contact official agricultural support when you need expert guidance.',
        'call': 'Call',
        'email': 'Email',
        'contactUnavailable': 'Could not open the phone or email app.',
        'emailSubject': 'Agriculture guidance request',
        'search': 'Search agriculture topics',
        'noResults': 'No agriculture topic matched your search.',
        'warning':
            'These are general expert-style guidelines. Crop variety, growth stage, soil, local climate and product labels can change the correct recommendation. For chemical treatment, verify the diagnosis and follow the current registered product label and local KVK/agriculture department advice.',
      },
      'hi': {
        'title': 'कृषि विशेषज्ञ जानकारी',
        'heading': 'कृषि विशेषज्ञ जानकारी',
        'subtitle':
            'फसल, मिट्टी, सिंचाई, पोषण, कीट, रोग, मौसम और कटाई के बाद प्रबंधन के लिए व्यावहारिक जानकारी।',
        'expertDirectory': 'कृषि विशेषज्ञ संपर्क',
        'expertDirectorySub': 'विशेषज्ञ सहायता के लिए आधिकारिक कृषि सहायता से संपर्क करें।',
        'call': 'कॉल करें',
        'email': 'ईमेल',
        'contactUnavailable': 'फोन या ईमेल ऐप नहीं खुल सका।',
        'emailSubject': 'कृषि सलाह के लिए अनुरोध',
        'search': 'कृषि विषय खोजें',
        'noResults': 'आपकी खोज से कोई कृषि विषय नहीं मिला।',
        'warning':
            'यह सामान्य विशेषज्ञ-आधारित मार्गदर्शन है। सही सलाह फसल की किस्म, अवस्था, मिट्टी, स्थानीय मौसम और उत्पाद के लेबल पर निर्भर हो सकती है। रासायनिक उपचार से पहले रोग की पुष्टि करें और वर्तमान पंजीकृत उत्पाद के लेबल तथा स्थानीय KVK/कृषि विभाग की सलाह का पालन करें।',
      },
      'pa': {
        'title': 'ਖੇਤੀ ਮਾਹਿਰ ਜਾਣਕਾਰੀ',
        'heading': 'ਖੇਤੀ ਮਾਹਿਰ ਜਾਣਕਾਰੀ',
        'subtitle':
            'ਫਸਲਾਂ, ਮਿੱਟੀ, ਸਿੰਚਾਈ, ਪੋਸ਼ਣ, ਕੀੜੇ, ਰੋਗ, ਮੌਸਮ ਅਤੇ ਕਟਾਈ ਬਾਅਦ ਪ੍ਰਬੰਧਨ ਲਈ ਵਿਹਾਰਕ ਜਾਣਕਾਰੀ।',
        'search': 'ਖੇਤੀ ਵਿਸ਼ੇ ਖੋਜੋ',
        'noResults': 'ਤੁਹਾਡੀ ਖੋਜ ਨਾਲ ਕੋਈ ਖੇਤੀ ਵਿਸ਼ਾ ਨਹੀਂ ਮਿਲਿਆ।',
        'warning':
            'ਇਹ ਆਮ ਮਾਹਿਰ-ਆਧਾਰਿਤ ਸਲਾਹ ਹੈ। ਸਹੀ ਸਿਫ਼ਾਰਸ਼ ਫਸਲ ਦੀ ਕਿਸਮ, ਅਵਸਥਾ, ਮਿੱਟੀ, ਸਥਾਨਕ ਮੌਸਮ ਅਤੇ ਉਤਪਾਦ ਦੇ ਲੇਬਲ ਉੱਤੇ ਨਿਰਭਰ ਕਰ ਸਕਦੀ ਹੈ। ਰਸਾਇਣਕ ਇਲਾਜ ਤੋਂ ਪਹਿਲਾਂ ਰੋਗ ਦੀ ਪੁਸ਼ਟੀ ਕਰੋ ਅਤੇ ਮੌਜੂਦਾ ਰਜਿਸਟਰਡ ਉਤਪਾਦ ਦੇ ਲੇਬਲ ਅਤੇ ਸਥਾਨਕ KVK/ਖੇਤੀਬਾੜੀ ਵਿਭਾਗ ਦੀ ਸਲਾਹ ਮੰਨੋ।',
      },
      'mr': {
        'title': 'कृषी तज्ज्ञ माहिती',
        'heading': 'कृषी तज्ज्ञ माहिती',
        'subtitle':
            'पिके, माती, सिंचन, पोषण, कीड, रोग, हवामान आणि काढणीनंतरच्या व्यवस्थापनासाठी व्यावहारिक माहिती.',
        'search': 'कृषी विषय शोधा',
        'noResults': 'तुमच्या शोधाशी जुळणारा कृषी विषय सापडला नाही.',
        'warning':
            'ही सामान्य तज्ज्ञ-आधारित मार्गदर्शक माहिती आहे. योग्य सल्ला पिकाची जात, अवस्था, माती, स्थानिक हवामान आणि उत्पादनाच्या लेबलवर अवलंबून असतो. रासायनिक उपचारापूर्वी निदानाची खात्री करा आणि सध्याच्या नोंदणीकृत उत्पादनाचे लेबल व स्थानिक KVK/कृषी विभागाचा सल्ला पाळा.',
      },
      'bn': {
        'title': 'কৃষি বিশেষজ্ঞ তথ্য',
        'heading': 'কৃষি বিশেষজ্ঞ তথ্য',
        'subtitle':
            'ফসল, মাটি, সেচ, পুষ্টি, পোকামাকড়, রোগ, আবহাওয়া ও ফসল কাটার পর ব্যবস্থাপনা সম্পর্কে ব্যবহারিক তথ্য।',
        'search': 'কৃষি বিষয় খুঁজুন',
        'noResults': 'আপনার অনুসন্ধানের সঙ্গে মেলে এমন বিষয় পাওয়া যায়নি।',
        'warning':
            'এটি সাধারণ বিশেষজ্ঞভিত্তিক নির্দেশনা। সঠিক পরামর্শ ফসলের জাত, বৃদ্ধি পর্যায়, মাটি, স্থানীয় আবহাওয়া ও পণ্যের লেবেলের ওপর নির্ভর করতে পারে। রাসায়নিক ব্যবহারের আগে রোগ নিশ্চিত করুন এবং বর্তমান নিবন্ধিত পণ্যের লেবেল ও স্থানীয় KVK/কৃষি দপ্তরের পরামর্শ মেনে চলুন।',
      },
      'gu': {
        'title': 'કૃષિ નિષ્ણાત માહિતી',
        'heading': 'કૃષિ નિષ્ણાત માહિતી',
        'subtitle':
            'પાક, જમીન, સિંચાઈ, પોષણ, જીવાત, રોગ, હવામાન અને લણણી પછીના સંચાલન માટે વ્યવહારુ માહિતી.',
        'search': 'કૃષિ વિષય શોધો',
        'noResults': 'તમારી શોધ સાથે મેળ ખાતો કોઈ કૃષિ વિષય મળ્યો નથી.',
        'warning':
            'આ સામાન્ય નિષ્ણાત આધારિત માર્ગદર્શન છે. યોગ્ય સલાહ પાકની જાત, વૃદ્ધિ અવસ્થા, જમીન, સ્થાનિક હવામાન અને ઉત્પાદનના લેબલ પર આધારિત હોઈ શકે છે. રાસાયણિક સારવાર પહેલાં રોગની ખાતરી કરો અને વર્તમાન નોંધાયેલ ઉત્પાદનના લેબલ તથા સ્થાનિક KVK/કૃષિ વિભાગની સલાહ અનુસરો.',
      },
      'ta': {
        'title': 'வேளாண் நிபுணர் தகவல்',
        'heading': 'வேளாண் நிபுணர் தகவல்',
        'subtitle':
            'பயிர்கள், மண், பாசனம், ஊட்டச்சத்து, பூச்சிகள், நோய்கள், வானிலை மற்றும் அறுவடைக்குப் பிந்தைய மேலாண்மைக்கான நடைமுறை தகவல்.',
        'search': 'வேளாண் தலைப்புகளைத் தேடுங்கள்',
        'noResults': 'உங்கள் தேடலுக்கு பொருந்தும் வேளாண் தலைப்பு இல்லை.',
        'warning':
            'இது பொதுவான நிபுணர் வழிகாட்டுதல். சரியான பரிந்துரை பயிர் வகை, வளர்ச்சி நிலை, மண், உள்ளூர் வானிலை மற்றும் தயாரிப்பு லேபிளைப் பொறுத்து மாறலாம். இரசாயன சிகிச்சைக்கு முன் நோயை உறுதிப்படுத்தி, தற்போதைய பதிவு செய்யப்பட்ட தயாரிப்பு லேபிள் மற்றும் உள்ளூர் KVK/வேளாண் துறை ஆலோசனையைப் பின்பற்றவும்.',
      },
      'te': {
        'title': 'వ్యవసాయ నిపుణుల సమాచారం',
        'heading': 'వ్యవసాయ నిపుణుల సమాచారం',
        'subtitle':
            'పంటలు, నేల, నీటిపారుదల, పోషకాలు, పురుగులు, వ్యాధులు, వాతావరణం మరియు కోత తర్వాత నిర్వహణపై ఉపయోగకరమైన సమాచారం.',
        'search': 'వ్యవసాయ అంశాలను వెతకండి',
        'noResults': 'మీ శోధనకు సరిపోయే వ్యవసాయ అంశం లేదు.',
        'warning':
            'ఇది సాధారణ నిపుణుల మార్గదర్శకం. సరైన సిఫార్సు పంట రకం, ఎదుగుదల దశ, నేల, స్థానిక వాతావరణం మరియు ఉత్పత్తి లేబుల్‌పై ఆధారపడి మారవచ్చు. రసాయన చికిత్సకు ముందు వ్యాధిని నిర్ధారించి, ప్రస్తుత నమోదిత ఉత్పత్తి లేబుల్ మరియు స్థానిక KVK/వ్యవసాయ శాఖ సూచనలను పాటించండి.',
      },
      'kn': {
        'title': 'ಕೃಷಿ ತಜ್ಞರ ಮಾಹಿತಿ',
        'heading': 'ಕೃಷಿ ತಜ್ಞರ ಮಾಹಿತಿ',
        'subtitle':
            'ಬೆಳೆಗಳು, ಮಣ್ಣು, ನೀರಾವರಿ, ಪೋಷಕಾಂಶಗಳು, ಕೀಟಗಳು, ರೋಗಗಳು, ಹವಾಮಾನ ಮತ್ತು ಕೊಯ್ಲಿನ ನಂತರದ ನಿರ್ವಹಣೆಯ ಬಗ್ಗೆ ಪ್ರಾಯೋಗಿಕ ಮಾಹಿತಿ.',
        'search': 'ಕೃಷಿ ವಿಷಯಗಳನ್ನು ಹುಡುಕಿ',
        'noResults': 'ನಿಮ್ಮ ಹುಡುಕಾಟಕ್ಕೆ ಹೊಂದುವ ಕೃಷಿ ವಿಷಯ ಸಿಗಲಿಲ್ಲ.',
        'warning':
            'ಇದು ಸಾಮಾನ್ಯ ತಜ್ಞರ ಮಾರ್ಗದರ್ಶನ. ಸರಿಯಾದ ಸಲಹೆ ಬೆಳೆ ತಳಿ, ಬೆಳವಣಿಗೆಯ ಹಂತ, ಮಣ್ಣು, ಸ್ಥಳೀಯ ಹವಾಮಾನ ಮತ್ತು ಉತ್ಪನ್ನದ ಲೇಬಲ್ ಮೇಲೆ ಅವಲಂಬಿತವಾಗಿರುತ್ತದೆ. ರಾಸಾಯನಿಕ ಚಿಕಿತ್ಸೆಗೆ ಮೊದಲು ರೋಗವನ್ನು ಖಚಿತಪಡಿಸಿ ಮತ್ತು ಪ್ರಸ್ತುತ ನೋಂದಾಯಿತ ಉತ್ಪನ್ನದ ಲೇಬಲ್ ಹಾಗೂ ಸ್ಥಳೀಯ KVK/ಕೃಷಿ ಇಲಾಖೆಯ ಸಲಹೆ ಅನುಸರಿಸಿ.',
      },
      'ml': {
        'title': 'കൃഷി വിദഗ്ധ വിവരങ്ങൾ',
        'heading': 'കൃഷി വിദഗ്ധ വിവരങ്ങൾ',
        'subtitle':
            'വിളകൾ, മണ്ണ്, ജലസേചനം, പോഷകങ്ങൾ, കീടങ്ങൾ, രോഗങ്ങൾ, കാലാവസ്ഥ, വിളവെടുപ്പിന് ശേഷമുള്ള പരിപാലനം എന്നിവയെക്കുറിച്ചുള്ള പ്രായോഗിക വിവരങ്ങൾ.',
        'search': 'കൃഷി വിഷയങ്ങൾ തിരയുക',
        'noResults': 'നിങ്ങളുടെ തിരച്ചിലിന് അനുയോജ്യമായ വിഷയം കണ്ടെത്താനായില്ല.',
        'warning':
            'ഇത് പൊതുവായ വിദഗ്ധ മാർഗനിർദ്ദേശമാണ്. ശരിയായ ശുപാർശ വിളയിനം, വളർച്ചാ ഘട്ടം, മണ്ണ്, പ്രാദേശിക കാലാവസ്ഥ, ഉൽപ്പന്ന ലേബൽ എന്നിവയെ ആശ്രയിച്ചിരിക്കും. രാസചികിത്സയ്ക്ക് മുമ്പ് രോഗം സ്ഥിരീകരിക്കുകയും നിലവിലെ രജിസ്റ്റർ ചെയ്ത ഉൽപ്പന്നത്തിന്റെ ലേബലും പ്രാദേശിക KVK/കൃഷിവകുപ്പ് നിർദേശങ്ങളും പാലിക്കുകയും ചെയ്യുക.',
      },
    };
    return values[lang]?[key] ?? values['en']![key]!;
  }

  static List<_ExpertTopic> _topics(String lang) {
    final data = _topicData[lang] ?? _topicData['en']!;
    return [
      _ExpertTopic(
        Icons.grass_rounded,
        data[0][0],
        data[0][1],
        [
          _Section(data[0][2], data[0][3]),
          _Section(data[0][4], data[0][5]),
        ],
      ),
      _ExpertTopic(
        Icons.water_drop_rounded,
        data[1][0],
        data[1][1],
        [
          _Section(data[1][2], data[1][3]),
          _Section(data[1][4], data[1][5]),
        ],
      ),
      _ExpertTopic(
        Icons.science_rounded,
        data[2][0],
        data[2][1],
        [
          _Section(data[2][2], data[2][3]),
          _Section(data[2][4], data[2][5]),
        ],
      ),
      _ExpertTopic(
        Icons.bug_report_rounded,
        data[3][0],
        data[3][1],
        [
          _Section(data[3][2], data[3][3]),
          _Section(data[3][4], data[3][5]),
        ],
      ),
      _ExpertTopic(
        Icons.health_and_safety_rounded,
        data[4][0],
        data[4][1],
        [
          _Section(data[4][2], data[4][3]),
          _Section(data[4][4], data[4][5]),
        ],
      ),
      _ExpertTopic(
        Icons.cloud_rounded,
        data[5][0],
        data[5][1],
        [
          _Section(data[5][2], data[5][3]),
          _Section(data[5][4], data[5][5]),
        ],
      ),
      _ExpertTopic(
        Icons.inventory_2_rounded,
        data[6][0],
        data[6][1],
        [
          _Section(data[6][2], data[6][3]),
          _Section(data[6][4], data[6][5]),
        ],
      ),
      _ExpertTopic(
        Icons.storefront_rounded,
        data[7][0],
        data[7][1],
        [
          _Section(data[7][2], data[7][3]),
          _Section(data[7][4], data[7][5]),
        ],
      ),
    ];
  }

  // Each row:
  // title, summary, section heading, section body, section heading, section body.
  static const Map<String, List<List<String>>> _topicData = {
    'en': [
      [
        'Crop Planning',
        'Choose a crop plan using season, soil, water and local market conditions.',
        'Before sowing',
        'Select a locally suitable variety. Check seed quality, expected crop duration, water availability and the previous crop. Prefer a soil test when available.',
        'Field practice',
        'Prepare a clean seedbed, maintain suitable spacing and avoid planting too early or too late for the local season. Keep records of sowing date, seed lot and field observations.',
      ],
      [
        'Irrigation & Water Management',
        'Use water according to crop stage, soil moisture and weather rather than a fixed routine.',
        'Practical approach',
        'Check soil moisture near the root zone before irrigating. Irrigation need changes with crop stage, soil type, temperature, wind and rainfall.',
        'Avoid losses',
        'Prevent standing water unless the crop specifically requires it. Keep drainage channels clear and prefer efficient irrigation methods where practical.',
      ],
      [
        'Soil & Plant Nutrition',
        'Build soil fertility through testing, balanced nutrients and organic matter.',
        'Nutrient planning',
        'Use soil-test results and the crop recommendation for nutrient planning. Do not assume that more fertilizer always means more yield.',
        'Good practice',
        'Split nitrogen where the crop and local recommendation support it, keep nutrients away from direct seed contact when required, and correct pH or micronutrient issues based on testing.',
      ],
      [
        'Pest Management',
        'Use integrated pest management instead of spraying automatically.',
        'Scout first',
        'Inspect leaves, stems, flowers and the underside of leaves regularly. Record the pest, affected area, crop stage and whether beneficial insects are present.',
        'Treatment decision',
        'Use non-chemical measures first when effective. If a pesticide is genuinely needed, identify the pest and crop correctly, use only a currently registered product for that use, and follow its label.',
      ],
      [
        'Disease Management',
        'Confirm symptoms and field pattern before deciding on treatment.',
        'Diagnosis',
        'Check the whole plant, symptom pattern, crop age, recent rain or humidity, soil moisture and how the problem is spreading. A single low-confidence AI image should not be treated as a confirmed diagnosis.',
        'Action',
        'Remove or manage severely affected material when appropriate, improve sanitation and airflow, and avoid unnecessary leaf wetness. For chemical treatment, follow the current label and local agricultural/KVK advice.',
      ],
      [
        'Weather-Based Farm Decisions',
        'Use short-term weather information to plan irrigation, spraying and field work.',
        'Before rain',
        'If substantial rain is expected, reassess irrigation and avoid unnecessary foliar applications immediately before rainfall.',
        'During severe weather',
        'Pause field operations during lightning or dangerous storms. Protect seedlings, drainage, structures and harvested produce according to the expected hazard.',
      ],
      [
        'Harvest & Storage',
        'Good harvesting and storage practices protect quality and reduce losses.',
        'Harvest',
        'Harvest at the crop-appropriate maturity and avoid unnecessary mechanical injury. Keep harvested produce clean and away from contaminated plant material.',
        'Storage',
        'Dry grains to a safe storage condition, keep stores clean and ventilated, monitor for moisture and pests, and use approved storage practices for the commodity.',
      ],
      [
        'Farm Records & Market Planning',
        'Simple records help farmers compare costs, yield and crop decisions.',
        'Record',
        'Track sowing date, variety, inputs, irrigation, pest or disease observations, harvest quantity and major expenses.',
        'Market decision',
        'Compare local market conditions, quality requirements, transport cost and expected price before choosing when and where to sell.',
      ],
    ],
    'hi': [
      [
        'फसल योजना',
        'मौसम, मिट्टी, पानी और स्थानीय बाजार को देखकर फसल की योजना बनाएं।',
        'बुवाई से पहले',
        'स्थानीय क्षेत्र के अनुकूल किस्म चुनें। बीज की गुणवत्ता, फसल अवधि, पानी की उपलब्धता और पिछली फसल देखें। संभव हो तो मिट्टी की जाँच कराएं।',
        'खेत की तैयारी',
        'साफ बीज-बेड तैयार करें, उचित दूरी रखें और स्थानीय मौसम के अनुसार सही समय पर बुवाई करें। बुवाई की तारीख और बीज की जानकारी दर्ज रखें।',
      ],
      [
        'सिंचाई और जल प्रबंधन',
        'सिंचाई फसल की अवस्था, मिट्टी की नमी और मौसम के अनुसार करें।',
        'व्यावहारिक तरीका',
        'जड़ क्षेत्र की मिट्टी की नमी देखकर सिंचाई की जरूरत तय करें। तापमान, हवा, मिट्टी और बारिश के अनुसार पानी की जरूरत बदलती है।',
        'पानी की बचत',
        'जहाँ फसल को पानी भराव की आवश्यकता न हो वहाँ खेत में पानी खड़ा न होने दें। नालियाँ साफ रखें और संभव हो तो कुशल सिंचाई पद्धति अपनाएं।',
      ],
      [
        'मिट्टी और पोषण',
        'मिट्टी की जाँच, संतुलित पोषण और जैविक पदार्थ से मिट्टी की उर्वरता बनाए रखें।',
        'पोषण योजना',
        'मिट्टी परीक्षण और फसल की अनुशंसित पोषण योजना के आधार पर खाद/उर्वरक तय करें। अधिक उर्वरक हमेशा अधिक उत्पादन नहीं देता।',
        'अच्छी प्रक्रिया',
        'जहाँ स्थानीय सलाह हो वहाँ नाइट्रोजन को भागों में दें। बीज के सीधे संपर्क से खाद को बचाएं और pH या सूक्ष्म पोषक तत्वों की कमी की पुष्टि परीक्षण से करें।',
      ],
      [
        'कीट प्रबंधन',
        'बिना जाँच के छिड़काव करने के बजाय समेकित कीट प्रबंधन अपनाएं।',
        'पहले निरीक्षण',
        'पत्तियों, तनों, फूलों और पत्तियों की निचली सतह की नियमित जाँच करें। कीट, प्रभावित क्षेत्र, फसल अवस्था और लाभकारी कीटों की मौजूदगी नोट करें।',
        'उपचार का निर्णय',
        'जहाँ प्रभावी हो वहाँ पहले गैर-रासायनिक उपाय अपनाएं। रसायन की जरूरत हो तो फसल और कीट की सही पहचान करके वर्तमान पंजीकृत उत्पाद का लेबल पालन करें।',
      ],
      [
        'रोग प्रबंधन',
        'उपचार तय करने से पहले लक्षण और खेत में रोग फैलने का तरीका देखें।',
        'पहचान',
        'पूधे के सभी भाग, लक्षण, फसल की उम्र, हाल की बारिश/नमी, मिट्टी की नमी और फैलाव देखें। कम विश्वसनीयता वाले एक AI फोटो परिणाम को पक्का निदान न मानें।',
        'कार्रवाई',
        'जहाँ उचित हो संक्रमित सामग्री का प्रबंधन करें, खेत की स्वच्छता और हवा का आवागमन सुधारें। रासायनिक उपचार के लिए वर्तमान लेबल और स्थानीय कृषि/KVK सलाह मानें।',
      ],
      [
        'मौसम आधारित खेती',
        'सिंचाई, छिड़काव और खेत के काम की योजना मौसम देखकर बनाएं।',
        'बारिश से पहले',
        'यदि अच्छी बारिश की संभावना हो तो सिंचाई की जरूरत दोबारा जाँचें और बारिश से ठीक पहले अनावश्यक पत्तियों पर छिड़काव न करें।',
        'खराब मौसम',
        'बिजली या तेज तूफान के दौरान खेत में काम रोकें। पौधों, जल निकासी, ढांचे और कटी फसल की सुरक्षा पर ध्यान दें।',
      ],
      [
        'कटाई और भंडारण',
        'सही कटाई और भंडारण से गुणवत्ता बनी रहती है और नुकसान कम होता है।',
        'कटाई',
        'फसल की उचित परिपक्वता पर कटाई करें और अनावश्यक चोट से बचें। कटी उपज को साफ रखें और संक्रमित पौध सामग्री से अलग रखें।',
        'भंडारण',
        'अनाज को सुरक्षित भंडारण स्थिति तक सुखाएं, भंडार साफ और हवादार रखें तथा नमी और कीट की नियमित जाँच करें।',
      ],
      [
        'खेत रिकॉर्ड और बाजार',
        'सरल रिकॉर्ड से लागत, उत्पादन और खेती के निर्णयों की तुलना की जा सकती है।',
        'रिकॉर्ड रखें',
        'बुवाई की तारीख, किस्म, खाद, सिंचाई, कीट/रोग, उत्पादन और प्रमुख खर्च लिखें।',
        'बाजार निर्णय',
        'बेचने से पहले स्थानीय बाजार, गुणवत्ता, परिवहन खर्च और संभावित कीमत की तुलना करें।',
      ],
    ],
  };
}

class _ExpertContact {
  const _ExpertContact({
    required this.name,
    required this.designation,
    required this.organization,
    required this.location,
    required this.phone,
    required this.email,
  });

  final String name;
  final String designation;
  final String organization;
  final String location;
  final String phone;
  final String email;
}

class _ExpertTopic {
  const _ExpertTopic(this.icon, this.title, this.summary, this.sections);

  final IconData icon;
  final String title;
  final String summary;
  final List<_Section> sections;
}

class _Section {
  const _Section(this.heading, this.body);

  final String heading;
  final String body;
}
