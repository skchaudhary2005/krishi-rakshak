import 'package:flutter/material.dart';

class AppLanguage extends ValueNotifier<String> {
  AppLanguage() : super('en');
}

class LanguageScope extends InheritedNotifier<AppLanguage> {
  const LanguageScope({super.key, required AppLanguage language, required Widget child})
      : super(notifier: language, child: child);

  static AppLanguage of(BuildContext context) {
    final x = context.dependOnInheritedWidgetOfExactType<LanguageScope>();
    if (x == null) throw FlutterError('LanguageScope not found');
    return x.notifier!;
  }
}

const languages = <String, String>{
  'en': 'English', 'hi': 'हिन्दी', 'pa': 'ਪੰਜਾਬੀ', 'mr': 'मराठी',
  'bn': 'বাংলা', 'gu': 'ગુજરાતી', 'ta': 'தமிழ்', 'te': 'తెలుగు',
  'kn': 'ಕನ್ನಡ', 'ml': 'മലയാളം',
};

const T = <String, Map<String, String>>{
'en': {
'app':'Krishi Rakshak','home':'Home','detect':'Detect','history':'History','settings':'Settings',
'disease':'Disease Detection','scan':'Scan crop','namaste':'Namaste, Farmer 👋',
'tagline':'Protect your crops with smart technology.','protection':'Crop Protection',
'camera':'Camera','gallery':'Gallery','analyze':'Analyze Crop','analyzing':'Analyzing...',
'noImage':'No crop image selected','choose':'Choose camera or gallery below',
'help':'Take a clear photo of your crop leaf or select an image from your gallery.',
'complete':'Analysis Complete','detected':'Detected Disease','confidence':'Confidence',
'description':'Description','treatment':'Treatment','prevention':'Prevention','done':'Done',
'newScan':'New Scan','language':'Language','selectLanguage':'Select your language',
'updated':'Language updated','offline':'Disease detection runs offline using the trained AI model.',
'healthyDesc':'The model classified this crop image as healthy within the supported disease classes.',
'healthyTreat':'No disease treatment is indicated by this prediction. Continue normal crop care and monitoring.',
'healthyPrev':'Maintain balanced watering and nutrition, good airflow, sanitation, and regular crop scouting.',
'genericDesc':'The AI model detected a supported crop disease pattern.',
'genericTreat':'Verify the diagnosis before applying treatment and follow local agricultural guidance for the crop and disease.',
'genericPrev':'Maintain crop sanitation, balanced irrigation and nutrition, good airflow, and regular scouting.',
'low':'Low Confidence Warning','lowText':'Confidence is below 60%. Take a clear close-up leaf photo and verify the result before applying treatment.',
'select':'Please select a crop image first','model':'AI model is not loaded yet','modelError':'AI model could not be loaded',
'prediction':'Prediction failed. Check model input/output.','cameraError':'Unable to open camera','galleryError':'Unable to open gallery',
},
'hi': {
'app':'कृषि रक्षक','home':'होम','detect':'पहचान','history':'इतिहास','settings':'सेटिंग्स',
'disease':'रोग पहचान','scan':'फसल स्कैन करें','namaste':'नमस्ते, किसान जी 👋',
'tagline':'स्मार्ट तकनीक से अपनी फसलों की सुरक्षा करें।','protection':'फसल सुरक्षा',
'camera':'कैमरा','gallery':'गैलरी','analyze':'फसल का विश्लेषण करें','analyzing':'विश्लेषण हो रहा है...',
'noImage':'कोई फसल फोटो नहीं चुनी गई','choose':'नीचे कैमरा या गैलरी चुनें',
'help':'पत्ती की साफ फोटो लें या गैलरी से तस्वीर चुनें।','complete':'विश्लेषण पूरा','detected':'पहचाना गया रोग','confidence':'विश्वसनीयता',
'description':'विवरण','treatment':'उपचार','prevention':'बचाव','done':'हो गया','newScan':'नई स्कैन','language':'भाषा',
'selectLanguage':'अपनी भाषा चुनें','updated':'भाषा बदल दी गई','offline':'प्रशिक्षित एआई मॉडल से रोग पहचान ऑफलाइन चलती है।',
'healthyDesc':'मॉडल ने इस फसल की तस्वीर को उपलब्ध रोग वर्गों में स्वस्थ बताया है।','healthyTreat':'इस परिणाम के अनुसार किसी रोग का उपचार आवश्यक नहीं है। सामान्य देखभाल और निगरानी जारी रखें।',
'healthyPrev':'संतुलित सिंचाई और पोषण, अच्छा वायु प्रवाह, सफाई और नियमित निरीक्षण बनाए रखें।','genericDesc':'एआई मॉडल ने उपलब्ध फसल रोग का पैटर्न पहचाना है।',
'genericTreat':'उपचार से पहले पहचान की पुष्टि करें और स्थानीय कृषि सलाह का पालन करें।','genericPrev':'फसल की सफाई, संतुलित सिंचाई व पोषण, अच्छा वायु प्रवाह और नियमित निरीक्षण बनाए रखें।',
'low':'कम विश्वसनीयता चेतावनी','lowText':'विश्वसनीयता 60% से कम है। पत्ती की साफ नज़दीकी फोटो लें और उपचार से पहले परिणाम की पुष्टि करें।',
'select':'पहले फसल की फोटो चुनें','model':'एआई मॉडल अभी लोड नहीं हुआ है','modelError':'एआई मॉडल लोड नहीं हो सका',
'prediction':'रोग पहचान विफल हुई। मॉडल इनपुट/आउटपुट जांचें।','cameraError':'कैमरा नहीं खुल सका','galleryError':'गैलरी नहीं खुल सकी',
},
'pa': {
'app':'ਕ੍ਰਿਸ਼ੀ ਰਕਸ਼ਕ','home':'ਹੋਮ','detect':'ਪਛਾਣ','history':'ਇਤਿਹਾਸ','settings':'ਸੈਟਿੰਗਾਂ','disease':'ਰੋਗ ਪਛਾਣ','scan':'ਫਸਲ ਸਕੈਨ ਕਰੋ','namaste':'ਸਤ ਸ੍ਰੀ ਅਕਾਲ, ਕਿਸਾਨ ਜੀ 👋',
'tagline':'ਸਮਾਰਟ ਤਕਨਾਲੋਜੀ ਨਾਲ ਆਪਣੀਆਂ ਫਸਲਾਂ ਦੀ ਰੱਖਿਆ ਕਰੋ।','protection':'ਫਸਲ ਸੁਰੱਖਿਆ','camera':'ਕੈਮਰਾ','gallery':'ਗੈਲਰੀ','analyze':'ਫਸਲ ਦਾ ਵਿਸ਼ਲੇਸ਼ਣ ਕਰੋ','analyzing':'ਵਿਸ਼ਲੇਸ਼ਣ ਹੋ ਰਿਹਾ ਹੈ...',
'noImage':'ਕੋਈ ਫਸਲ ਫੋਟੋ ਨਹੀਂ ਚੁਣੀ','choose':'ਹੇਠਾਂ ਕੈਮਰਾ ਜਾਂ ਗੈਲਰੀ ਚੁਣੋ','help':'ਪੱਤੇ ਦੀ ਸਾਫ਼ ਫੋਟੋ ਲਓ ਜਾਂ ਗੈਲਰੀ ਤੋਂ ਤਸਵੀਰ ਚੁਣੋ।','complete':'ਵਿਸ਼ਲੇਸ਼ਣ ਪੂਰਾ','detected':'ਪਛਾਣਿਆ ਰੋਗ','confidence':'ਭਰੋਸੇਯੋਗਤਾ','description':'ਵੇਰਵਾ','treatment':'ਇਲਾਜ','prevention':'ਬਚਾਅ','done':'ਠੀਕ ਹੈ','newScan':'ਨਵਾਂ ਸਕੈਨ','language':'ਭਾਸ਼ਾ','selectLanguage':'ਆਪਣੀ ਭਾਸ਼ਾ ਚੁਣੋ','updated':'ਭਾਸ਼ਾ ਬਦਲ ਦਿੱਤੀ ਗਈ','offline':'ਟ੍ਰੇਨ ਕੀਤੇ ਏਆਈ ਮਾਡਲ ਨਾਲ ਰੋਗ ਪਛਾਣ ਆਫਲਾਈਨ ਚੱਲਦੀ ਹੈ।',
'healthyDesc':'ਮਾਡਲ ਨੇ ਇਸ ਫਸਲ ਦੀ ਤਸਵੀਰ ਨੂੰ ਉਪਲਬਧ ਰੋਗ ਵਰਗਾਂ ਵਿੱਚ ਸਿਹਤਮੰਦ ਦੱਸਿਆ ਹੈ।','healthyTreat':'ਇਸ ਨਤੀਜੇ ਅਨੁਸਾਰ ਕਿਸੇ ਰੋਗ ਦਾ ਇਲਾਜ ਲੋੜੀਂਦਾ ਨਹੀਂ। ਆਮ ਦੇਖਭਾਲ ਜਾਰੀ ਰੱਖੋ।','healthyPrev':'ਸੰਤੁਲਿਤ ਸਿੰਚਾਈ, ਪੋਸ਼ਣ, ਹਵਾ ਦਾ ਪ੍ਰਵਾਹ, ਸਫਾਈ ਅਤੇ ਨਿਯਮਿਤ ਜਾਂਚ ਰੱਖੋ।','genericDesc':'ਏਆਈ ਮਾਡਲ ਨੇ ਇੱਕ ਸਮਰਥਿਤ ਫਸਲ ਰੋਗ ਦਾ ਪੈਟਰਨ ਪਛਾਣਿਆ ਹੈ।','genericTreat':'ਇਲਾਜ ਤੋਂ ਪਹਿਲਾਂ ਪਛਾਣ ਦੀ ਪੁਸ਼ਟੀ ਕਰੋ ਅਤੇ ਸਥਾਨਕ ਖੇਤੀ ਸਲਾਹ ਦੀ ਪਾਲਣਾ ਕਰੋ।','genericPrev':'ਫਸਲ ਦੀ ਸਫਾਈ, ਸੰਤੁਲਿਤ ਸਿੰਚਾਈ ਅਤੇ ਪੋਸ਼ਣ, ਹਵਾ ਦਾ ਪ੍ਰਵਾਹ ਅਤੇ ਨਿਯਮਿਤ ਜਾਂਚ ਰੱਖੋ।','low':'ਘੱਟ ਭਰੋਸੇਯੋਗਤਾ ਚੇਤਾਵਨੀ','lowText':'ਭਰੋਸੇਯੋਗਤਾ 60% ਤੋਂ ਘੱਟ ਹੈ। ਸਾਫ਼ ਪੱਤੇ ਦੀ ਨੇੜਲੀ ਫੋਟੋ ਲਓ ਅਤੇ ਇਲਾਜ ਤੋਂ ਪਹਿਲਾਂ ਨਤੀਜਾ ਜਾਂਚੋ।','select':'ਪਹਿਲਾਂ ਫਸਲ ਦੀ ਫੋਟੋ ਚੁਣੋ','model':'ਏਆਈ ਮਾਡਲ ਅਜੇ ਲੋਡ ਨਹੀਂ ਹੋਇਆ','modelError':'ਏਆਈ ਮਾਡਲ ਲੋਡ ਨਹੀਂ ਹੋ ਸਕਿਆ','prediction':'ਰੋਗ ਪਛਾਣ ਅਸਫਲ ਹੋਈ। ਮਾਡਲ ਇਨਪੁਟ/ਆਉਟਪੁੱਟ ਜਾਂਚੋ।','cameraError':'ਕੈਮਰਾ ਨਹੀਂ ਖੁੱਲ ਸਕਿਆ','galleryError':'ਗੈਲਰੀ ਨਹੀਂ ਖੁੱਲ ਸਕੀ',
},
'mr': {
'app':'कृषी रक्षक','home':'होम','detect':'ओळख','history':'इतिहास','settings':'सेटिंग्ज','disease':'रोग ओळख','scan':'पीक स्कॅन करा','namaste':'नमस्कार, शेतकरी मित्रा 👋','tagline':'स्मार्ट तंत्रज्ञानाने आपल्या पिकांचे संरक्षण करा.','protection':'पीक संरक्षण','camera':'कॅमेरा','gallery':'गॅलरी','analyze':'पिकाचे विश्लेषण करा','analyzing':'विश्लेषण सुरू आहे...','noImage':'पीक फोटो निवडलेला नाही','choose':'खाली कॅमेरा किंवा गॅलरी निवडा','help':'पानाचा स्पष्ट फोटो घ्या किंवा गॅलरीमधून चित्र निवडा.','complete':'विश्लेषण पूर्ण','detected':'ओळखलेला रोग','confidence':'विश्वास पातळी','description':'वर्णन','treatment':'उपचार','prevention':'प्रतिबंध','done':'पूर्ण','newScan':'नवीन स्कॅन','language':'भाषा','selectLanguage':'आपली भाषा निवडा','updated':'भाषा बदलली','offline':'प्रशिक्षित एआय मॉडेलने रोग ओळख ऑफलाइन चालते.','healthyDesc':'मॉडेलने या पिकाच्या चित्राला निरोगी म्हणून ओळखले आहे.','healthyTreat':'या निकालानुसार रोगाचा उपचार आवश्यक नाही. सामान्य काळजी सुरू ठेवा.','healthyPrev':'संतुलित पाणी व पोषण, चांगली हवा, स्वच्छता आणि नियमित तपासणी ठेवा.','genericDesc':'एआय मॉडेलने पीक रोगाचा नमुना ओळखला आहे.','genericTreat':'उपचारापूर्वी निदानाची खात्री करा आणि स्थानिक कृषी सल्ल्याचे पालन करा.','genericPrev':'पीक स्वच्छता, संतुलित सिंचन व पोषण, चांगली हवा आणि नियमित तपासणी ठेवा.','low':'कमी विश्वास पातळी सूचना','lowText':'विश्वास पातळी 60% पेक्षा कमी आहे. पानाचा स्पष्ट फोटो घ्या आणि उपचारापूर्वी निकाल तपासा.','select':'प्रथम पिकाचा फोटो निवडा','model':'एआय मॉडेल अजून लोड झालेले नाही','modelError':'एआय मॉडेल लोड झाले नाही','prediction':'रोग ओळख अयशस्वी. मॉडेल इनपुट/आउटपुट तपासा.','cameraError':'कॅमेरा उघडता आला नाही','galleryError':'गॅलरी उघडता आली नाही',
},
'bn': {
'app':'কৃষি রক্ষক','home':'হোম','detect':'শনাক্ত','history':'ইতিহাস','settings':'সেটিংস','disease':'রোগ শনাক্তকরণ','scan':'ফসল স্ক্যান করুন','namaste':'নমস্কার, কৃষক 👋','tagline':'স্মার্ট প্রযুক্তির মাধ্যমে আপনার ফসল রক্ষা করুন।','protection':'ফসল সুরক্ষা','camera':'ক্যামেরা','gallery':'গ্যালারি','analyze':'ফসল বিশ্লেষণ করুন','analyzing':'বিশ্লেষণ চলছে...','noImage':'কোনো ফসলের ছবি নির্বাচন করা হয়নি','choose':'নিচে ক্যামেরা বা গ্যালারি বেছে নিন','help':'পাতার পরিষ্কার ছবি তুলুন বা গ্যালারি থেকে নির্বাচন করুন।','complete':'বিশ্লেষণ সম্পন্ন','detected':'শনাক্ত রোগ','confidence':'বিশ্বাসযোগ্যতা','description':'বিবরণ','treatment':'চিকিৎসা','prevention':'প্রতিরোধ','done':'সম্পন্ন','newScan':'নতুন স্ক্যান','language':'ভাষা','selectLanguage':'আপনার ভাষা নির্বাচন করুন','updated':'ভাষা পরিবর্তন হয়েছে','offline':'প্রশিক্ষিত এআই মডেল ব্যবহার করে রোগ শনাক্তকরণ অফলাইনে চলে।','healthyDesc':'মডেল এই ফসলের ছবিকে স্বাস্থ্যকর হিসেবে শনাক্ত করেছে।','healthyTreat':'এই ফলাফল অনুযায়ী রোগের চিকিৎসা দরকার নেই। স্বাভাবিক পরিচর্যা চালিয়ে যান।','healthyPrev':'সুষম সেচ ও পুষ্টি, ভালো বায়ু চলাচল, পরিচ্ছন্নতা এবং নিয়মিত পর্যবেক্ষণ বজায় রাখুন।','genericDesc':'এআই মডেল একটি সমর্থিত ফসল রোগের লক্ষণ শনাক্ত করেছে।','genericTreat':'চিকিৎসার আগে রোগ নির্ণয় নিশ্চিত করুন এবং স্থানীয় কৃষি পরামর্শ অনুসরণ করুন।','genericPrev':'ফসলের পরিচ্ছন্নতা, সুষম সেচ ও পুষ্টি, ভালো বায়ু চলাচল এবং নিয়মিত পর্যবেক্ষণ বজায় রাখুন।','low':'কম বিশ্বাসযোগ্যতার সতর্কতা','lowText':'বিশ্বাসযোগ্যতা 60%-এর নিচে। পরিষ্কার পাতার কাছের ছবি নিন এবং চিকিৎসার আগে ফলাফল যাচাই করুন।','select':'প্রথমে ফসলের ছবি নির্বাচন করুন','model':'এআই মডেল এখনও লোড হয়নি','modelError':'এআই মডেল লোড করা যায়নি','prediction':'রোগ শনাক্তকরণ ব্যর্থ। মডেল ইনপুট/আউটপুট পরীক্ষা করুন।','cameraError':'ক্যামেরা খোলা যায়নি','galleryError':'গ্যালারি খোলা যায়নি',
},
};


const extraT = <String, Map<String, String>>{
  'en': {
    'crop':'Crop','severity':'Severity','farmerAction':'Farmer Action','governmentAlert':'Government Alert','offlineMode':'Offline Mode','onlineAI':'ONLINE AI','offlineAI':'OFFLINE AI','alertCreated':'Alert created successfully.','alertWaiting':'Saved locally and waiting for internet.','askAI':'Ask Krishi Rakshak AI','currentDisease':'Current disease','askHint':'Ask about disease, treatment, fertilizer, pests...','aiGreeting':'Namaste! I am Krishi Rakshak AI. Ask me anything about your crop, disease, treatment, fertilizer, irrigation or pests.','aiError':'AI query failed. Please check the backend/internet connection.'
  },
  'hi': {
    'crop':'फसल','severity':'गंभीरता','farmerAction':'किसान के लिए सलाह','governmentAlert':'सरकारी अलर्ट','offlineMode':'ऑफलाइन मोड','onlineAI':'ऑनलाइन एआई','offlineAI':'ऑफलाइन एआई','alertCreated':'अलर्ट सफलतापूर्वक बनाया गया।','alertWaiting':'अलर्ट फोन में सेव है और इंटरनेट आने पर भेजा जाएगा।','askAI':'कृषि रक्षक एआई से पूछें','currentDisease':'वर्तमान रोग','askHint':'रोग, उपचार, खाद, कीट के बारे में पूछें...','aiGreeting':'नमस्ते! मैं कृषि रक्षक एआई हूँ। फसल, रोग, उपचार, खाद, सिंचाई या कीट से जुड़ा कोई भी सवाल पूछें।','aiError':'एआई सवाल का उत्तर नहीं मिल सका। बैकएंड/इंटरनेट जांचें।'
  },
  'pa': {'crop':'ਫਸਲ','severity':'ਗੰਭੀਰਤਾ','farmerAction':'ਕਿਸਾਨ ਲਈ ਸਲਾਹ','governmentAlert':'ਸਰਕਾਰੀ ਅਲਰਟ','offlineMode':'ਆਫਲਾਈਨ ਮੋਡ','onlineAI':'ਆਨਲਾਈਨ ਏਆਈ','offlineAI':'ਆਫਲਾਈਨ ਏਆਈ','askAI':'ਕ੍ਰਿਸ਼ੀ ਰਕਸ਼ਕ ਏਆਈ ਨੂੰ ਪੁੱਛੋ','currentDisease':'ਮੌਜੂਦਾ ਰੋਗ','askHint':'ਰੋਗ, ਇਲਾਜ, ਖਾਦ ਜਾਂ ਕੀੜਿਆਂ ਬਾਰੇ ਪੁੱਛੋ...','aiGreeting':'ਸਤ ਸ੍ਰੀ ਅਕਾਲ! ਮੈਂ ਕ੍ਰਿਸ਼ੀ ਰਕਸ਼ਕ ਏਆਈ ਹਾਂ। ਆਪਣੀ ਫਸਲ ਬਾਰੇ ਸਵਾਲ ਪੁੱਛੋ।','aiError':'ਏਆਈ ਜਵਾਬ ਨਹੀਂ ਦੇ ਸਕਿਆ। ਬੈਕਐਂਡ/ਇੰਟਰਨੈੱਟ ਜਾਂਚੋ।'},
  'mr': {'crop':'पीक','severity':'तीव्रता','farmerAction':'शेतकऱ्यासाठी सल्ला','governmentAlert':'सरकारी सूचना','offlineMode':'ऑफलाइन मोड','onlineAI':'ऑनलाइन एआय','offlineAI':'ऑफलाइन एआय','askAI':'कृषी रक्षक एआयला विचारा','currentDisease':'सध्याचा रोग','askHint':'रोग, उपचार, खत किंवा किडींबद्दल विचारा...','aiGreeting':'नमस्कार! मी कृषी रक्षक एआय आहे. आपल्या पिकाबद्दल प्रश्न विचारा.','aiError':'एआय उत्तर मिळाले नाही. बॅकएंड/इंटरनेट तपासा.'},
  'bn': {'crop':'ফসল','severity':'তীব্রতা','farmerAction':'কৃষকের পরামর্শ','governmentAlert':'সরকারি সতর্কতা','offlineMode':'অফলাইন মোড','onlineAI':'অনলাইন এআই','offlineAI':'অফলাইন এআই','askAI':'কৃষি রক্ষক এআইকে জিজ্ঞাসা করুন','currentDisease':'বর্তমান রোগ','askHint':'রোগ, চিকিৎসা, সার বা পোকা সম্পর্কে জিজ্ঞাসা করুন...','aiGreeting':'নমস্কার! আমি কৃষি রক্ষক এআই। আপনার ফসল সম্পর্কে প্রশ্ন করুন।','aiError':'এআই উত্তর দিতে পারেনি। ব্যাকএন্ড/ইন্টারনেট পরীক্ষা করুন।'},
  'gu': {'crop':'પાક','severity':'તીવ્રતા','farmerAction':'ખેડૂત માટે સલાહ','governmentAlert':'સરકારી ચેતવણી','offlineMode':'ઓફલાઇન મોડ','onlineAI':'ઓનલાઇન AI','offlineAI':'ઓફલાઇન AI','askAI':'કૃષિ રક્ષક AIને પૂછો','currentDisease':'હાલનો રોગ','askHint':'રોગ, સારવાર, ખાતર અથવા જીવાત વિશે પૂછો...','aiGreeting':'નમસ્તે! હું કૃષિ રક્ષક AI છું. તમારા પાક વિશે પ્રશ્ન પૂછો.','aiError':'AI જવાબ આપી શક્યું નથી. બેકએન્ડ/ઇન્ટરનેટ તપાસો.'},
  'ta': {'crop':'பயிர்','severity':'தீவிரம்','farmerAction':'விவசாயி ஆலோசனை','governmentAlert':'அரசு எச்சரிக்கை','offlineMode':'ஆஃப்லைன் முறை','onlineAI':'ஆன்லைன் AI','offlineAI':'ஆஃப்லைன் AI','askAI':'கிருஷி ரக்ஷக் AI-யிடம் கேளுங்கள்','currentDisease':'தற்போதைய நோய்','askHint':'நோய், சிகிச்சை, உரம் அல்லது பூச்சிகள் பற்றி கேளுங்கள்...','aiGreeting':'வணக்கம்! நான் கிருஷி ரக்ஷக் AI. உங்கள் பயிர் பற்றி கேளுங்கள்.','aiError':'AI பதில் கிடைக்கவில்லை. பின்தளத்தை சரிபார்க்கவும்.'},
  'te': {'crop':'పంట','severity':'తీవ్రత','farmerAction':'రైతు సూచన','governmentAlert':'ప్రభుత్వ హెచ్చరిక','offlineMode':'ఆఫ్‌లైన్ మోడ్','onlineAI':'ఆన్‌లైన్ AI','offlineAI':'ఆఫ్‌లైన్ AI','askAI':'కృషి రక్షక్ AIని అడగండి','currentDisease':'ప్రస్తుత వ్యాధి','askHint':'వ్యాధి, చికిత్స, ఎరువు లేదా పురుగుల గురించి అడగండి...','aiGreeting':'నమస్కారం! నేను కృషి రక్షక్ AI. మీ పంట గురించి ప్రశ్న అడగండి.','aiError':'AI సమాధానం రాలేదు. బ్యాకెండ్/ఇంటర్నెట్ తనిఖీ చేయండి.'},
  'kn': {'crop':'ಬೆಳೆ','severity':'ತೀವ್ರತೆ','farmerAction':'ರೈತ ಸಲಹೆ','governmentAlert':'ಸರ್ಕಾರಿ ಎಚ್ಚರಿಕೆ','offlineMode':'ಆಫ್‌ಲೈನ್ ಮೋಡ್','onlineAI':'ಆನ್‌ಲೈನ್ AI','offlineAI':'ಆಫ್‌ಲೈನ್ AI','askAI':'ಕೃಷಿ ರಕ್ಷಕ್ AIಗೆ ಕೇಳಿ','currentDisease':'ಪ್ರಸ್ತುತ ರೋಗ','askHint':'ರೋಗ, ಚಿಕಿತ್ಸೆ, ಗೊಬ್ಬರ ಅಥವಾ ಕೀಟಗಳ ಬಗ್ಗೆ ಕೇಳಿ...','aiGreeting':'ನಮಸ್ಕಾರ! ನಾನು ಕೃಷಿ ರಕ್ಷಕ್ AI. ನಿಮ್ಮ ಬೆಳೆಯ ಬಗ್ಗೆ ಪ್ರಶ್ನೆ ಕೇಳಿ.','aiError':'AI ಉತ್ತರ ಸಿಗಲಿಲ್ಲ. ಬ್ಯಾಕೆಂಡ್/ಇಂಟರ್ನೆಟ್ ಪರಿಶೀಲಿಸಿ.'},
  'ml': {'crop':'വിള','severity':'തീവ്രത','farmerAction':'കർഷകന്റെ ഉപദേശം','governmentAlert':'സർക്കാർ മുന്നറിയിപ്പ്','offlineMode':'ഓഫ്‌ലൈൻ മോഡ്','onlineAI':'ഓൺലൈൻ AI','offlineAI':'ഓഫ്‌ലൈൻ AI','askAI':'കൃഷി രക്ഷക് AIയോട് ചോദിക്കുക','currentDisease':'നിലവിലെ രോഗം','askHint':'രോഗം, ചികിത്സ, വളം അല്ലെങ്കിൽ കീടങ്ങളെക്കുറിച്ച് ചോദിക്കുക...','aiGreeting':'നമസ്കാരം! ഞാൻ കൃഷി രക്ഷക് AI ആണ്. നിങ്ങളുടെ വിളയെക്കുറിച്ച് ചോദിക്കൂ.','aiError':'AI മറുപടി ലഭിച്ചില്ല. ബാക്കെൻഡ്/ഇന്റർനെറ്റ് പരിശോധിക്കുക.'},
};

String tr(BuildContext c,String k){final l=LanguageScope.of(c).value;return extraT[l]?[k]??T[l]?[k]??extraT['en']?[k]??T['en']![k]??k;}

const cropNames = {
'en': {'Apple':'Apple','Blueberry':'Blueberry','Cherry':'Cherry','Corn':'Corn','Grape':'Grape','Orange':'Orange','Peach':'Peach','Bell Pepper':'Bell Pepper','Potato':'Potato','Raspberry':'Raspberry','Soybean':'Soybean','Squash':'Squash','Strawberry':'Strawberry','Tomato':'Tomato'},
'hi': {'Apple':'सेब','Blueberry':'ब्लूबेरी','Cherry':'चेरी','Corn':'मक्का','Grape':'अंगूर','Orange':'संतरा','Peach':'आड़ू','Bell Pepper':'शिमला मिर्च','Potato':'आलू','Raspberry':'रास्पबेरी','Soybean':'सोयाबीन','Squash':'स्क्वैश','Strawberry':'स्ट्रॉबेरी','Tomato':'टमाटर'},
'pa': {'Apple':'ਸੇਬ','Blueberry':'ਬਲੂਬੈਰੀ','Cherry':'ਚੈਰੀ','Corn':'ਮੱਕੀ','Grape':'ਅੰਗੂਰ','Orange':'ਸੰਤਰਾ','Peach':'ਆੜੂ','Bell Pepper':'ਸ਼ਿਮਲਾ ਮਿਰਚ','Potato':'ਆਲੂ','Raspberry':'ਰੈਸਪਬੈਰੀ','Soybean':'ਸੋਇਆਬੀਨ','Squash':'ਸਕੁਐਸ਼','Strawberry':'ਸਟ੍ਰਾਬੈਰੀ','Tomato':'ਟਮਾਟਰ'},
'mr': {'Apple':'सफरचंद','Blueberry':'ब्लूबेरी','Cherry':'चेरी','Corn':'मका','Grape':'द्राक्ष','Orange':'संत्रे','Peach':'पीच','Bell Pepper':'ढोबळी मिरची','Potato':'बटाटा','Raspberry':'रास्पबेरी','Soybean':'सोयाबीन','Squash':'स्क्वॅश','Strawberry':'स्ट्रॉबेरी','Tomato':'टोमॅटो'},
'bn': {'Apple':'আপেল','Blueberry':'ব্লুবেরি','Cherry':'চেরি','Corn':'ভুট্টা','Grape':'আঙুর','Orange':'কমলা','Peach':'পীচ','Bell Pepper':'ক্যাপসিকাম','Potato':'আলু','Raspberry':'রাস্পবেরি','Soybean':'সয়াবিন','Squash':'স্কোয়াশ','Strawberry':'স্ট্রবেরি','Tomato':'টমেটো'},
};

const diseaseNames = {
'Apple Scab':'Apple Scab','Black Rot':'Black Rot','Cedar Apple Rust':'Cedar Apple Rust','Healthy':'Healthy','Powdery Mildew':'Powdery Mildew','Cercospora Leaf Spot / Gray Leaf Spot':'Cercospora Leaf Spot / Gray Leaf Spot','Common Rust':'Common Rust','Northern Leaf Blight':'Northern Leaf Blight','Esca (Black Measles)':'Esca (Black Measles)','Leaf Blight (Isariopsis Leaf Spot)':'Leaf Blight (Isariopsis Leaf Spot)','Huanglongbing (Citrus Greening)':'Huanglongbing (Citrus Greening)','Bacterial Spot':'Bacterial Spot','Early Blight':'Early Blight','Late Blight':'Late Blight','Leaf Mold':'Leaf Mold','Septoria Leaf Spot':'Septoria Leaf Spot','Spider Mites':'Spider Mites','Leaf Scorch':'Leaf Scorch','Target Spot':'Target Spot','Yellow Leaf Curl Virus':'Yellow Leaf Curl Virus','Mosaic Virus':'Mosaic Virus'
};

const diseaseTranslations = {
'hi': {'Apple Scab':'एप्पल स्कैब','Black Rot':'ब्लैक रॉट','Cedar Apple Rust':'सीडर एप्पल रस्ट','Healthy':'स्वस्थ','Powdery Mildew':'पाउडरी मिल्ड्यू','Cercospora Leaf Spot / Gray Leaf Spot':'सर्कोस्पोरा लीफ स्पॉट / ग्रे लीफ स्पॉट','Common Rust':'कॉमन रस्ट','Northern Leaf Blight':'नॉर्दर्न लीफ ब्लाइट','Esca (Black Measles)':'एस्का (ब्लैक मीजल्स)','Leaf Blight (Isariopsis Leaf Spot)':'लीफ ब्लाइट','Huanglongbing (Citrus Greening)':'हुआंगलोंगबिंग (सिट्रस ग्रीनिंग)','Bacterial Spot':'बैक्टीरियल स्पॉट','Early Blight':'अगेती झुलसा','Late Blight':'पछेती झुलसा','Leaf Mold':'लीफ मोल्ड','Septoria Leaf Spot':'सेप्टोरिया लीफ स्पॉट','Spider Mites':'स्पाइडर माइट्स','Leaf Scorch':'लीफ स्कॉर्च','Target Spot':'टार्गेट स्पॉट','Yellow Leaf Curl Virus':'येलो लीफ कर्ल वायरस','Mosaic Virus':'मोज़ेक वायरस'},
'pa': {'Healthy':'ਸਿਹਤਮੰਦ','Early Blight':'ਅਗੇਤੀ ਝੁਲਸ','Late Blight':'ਪਿਛੇਤੀ ਝੁਲਸ','Bacterial Spot':'ਬੈਕਟੀਰੀਅਲ ਸਪਾਟ','Powdery Mildew':'ਪਾਊਡਰੀ ਮਿਲਡਿਊ','Black Rot':'ਬਲੈਕ ਰੌਟ','Common Rust':'ਕਾਮਨ ਰਸਟ','Northern Leaf Blight':'ਨੌਦਰਨ ਲੀਫ ਬਲਾਈਟ','Spider Mites':'ਸਪਾਈਡਰ ਮਾਈਟਸ','Mosaic Virus':'ਮੋਜ਼ੇਕ ਵਾਇਰਸ','Yellow Leaf Curl Virus':'ਯੈਲੋ ਲੀਫ ਕਰਲ ਵਾਇਰਸ','Target Spot':'ਟਾਰਗੇਟ ਸਪਾਟ','Leaf Mold':'ਲੀਫ ਮੋਲਡ','Leaf Scorch':'ਲੀਫ ਸਕਾਰਚ','Septoria Leaf Spot':'ਸੈਪਟੋਰੀਆ ਲੀਫ ਸਪਾਟ'},
'mr': {'Healthy':'निरोगी','Early Blight':'लवकर येणारा करपा','Late Blight':'उशिरा येणारा करपा','Bacterial Spot':'बॅक्टेरियल स्पॉट','Powdery Mildew':'पावडरी मिल्ड्यू','Black Rot':'ब्लॅक रॉट','Common Rust':'कॉमन रस्ट','Northern Leaf Blight':'नॉर्दर्न लीफ ब्लाइट','Spider Mites':'स्पायडर माइट्स','Mosaic Virus':'मोझॅक व्हायरस','Yellow Leaf Curl Virus':'यलो लीफ कर्ल व्हायरस','Target Spot':'टार्गेट स्पॉट','Leaf Mold':'लीफ मोल्ड','Leaf Scorch':'लीफ स्कॉर्च','Septoria Leaf Spot':'सेप्टोरिया लीफ स्पॉट'},
'bn': {'Healthy':'সুস্থ','Early Blight':'আর্লি ব্লাইট','Late Blight':'লেট ব্লাইট','Bacterial Spot':'ব্যাকটেরিয়াল স্পট','Powdery Mildew':'পাউডারি মিলডিউ','Black Rot':'ব্ল্যাক রট','Common Rust':'কমন রাস্ট','Northern Leaf Blight':'নর্দার্ন লিফ ব্লাইট','Spider Mites':'স্পাইডার মাইট','Mosaic Virus':'মোজাইক ভাইরাস','Yellow Leaf Curl Virus':'ইয়েলো লিফ কার্ল ভাইরাস','Target Spot':'টার্গেট স্পট','Leaf Mold':'লিফ মোল্ড','Leaf Scorch':'লিফ স্কর্চ','Septoria Leaf Spot':'সেপ্টোরিয়া লিফ স্পট'},
};

String diseaseLabel(String raw,String lang){
  final parts=raw.split(' - ');
  if(parts.length<2)return raw;
  final crop=cropNames[lang]?[parts[0]]??parts[0];
  final d=diseaseTranslations[lang]?[parts.sublist(1).join(' - ')]??parts.sublist(1).join(' - ');
  return '$crop - $d';
}
