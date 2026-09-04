export interface OfflineDiagnosis {
  disease: string;
  crop: string;
  confidence: number;
  symptoms: string[];
  treatment: string[];
  prevention: string[];
  isHealthy: boolean;
  offline: true;
}

interface CropRule {
  crop: string;
  keywords: string[];
  disease: string;
  symptoms: string[];
  treatment: string[];
  prevention: string[];
}

const RULES: CropRule[] = [
  {
    crop: "Tomato",
    keywords: [
      "brown spots",
      "black spots",
      "leaf spots",
      "leaf blight",
      "blight",
      "dark spots",
      "dry leaves",
    ],
    disease: "Tomato Leaf Blight",
    symptoms: [
      "Brown or dark spots may appear on leaves.",
      "Affected leaves can dry and fall.",
      "Disease can spread quickly in humid conditions.",
    ],
    treatment: [
      "Remove badly infected leaves and keep them away from healthy plants.",
      "Avoid overhead irrigation and keep foliage dry.",
      "Improve air circulation by maintaining proper plant spacing.",
      "For fungicide use, follow the product label and local agricultural recommendations.",
    ],
    prevention: [
      "Avoid excessive moisture around the foliage.",
      "Remove infected plant material regularly.",
      "Use healthy planting material.",
      "Monitor the crop after rain and during humid weather.",
    ],
  },

  {
    crop: "Potato",
    keywords: [
      "brown leaf",
      "dark leaf",
      "leaf spots",
      "late blight",
      "potato blight",
      "black spots",
    ],
    disease: "Potato Blight",
    symptoms: [
      "Dark or brown lesions may appear on leaves.",
      "Leaves may become weak and dry.",
      "Disease risk increases during cool, wet and humid weather.",
    ],
    treatment: [
      "Remove severely affected foliage when practical.",
      "Avoid unnecessary overhead irrigation.",
      "Maintain good field drainage.",
      "For fungicides, use only locally approved products according to the label.",
    ],
    prevention: [
      "Use healthy seed tubers.",
      "Maintain proper spacing.",
      "Avoid waterlogging.",
      "Inspect plants frequently after rainy periods.",
    ],
  },

  {
    crop: "Rice",
    keywords: [
      "rice blast",
      "blast",
      "diamond spots",
      "gray spots",
      "rice leaf",
    ],
    disease: "Rice Blast",
    symptoms: [
      "Spindle or diamond-shaped lesions may develop on leaves.",
      "Lesions can have gray centers and darker margins.",
      "Severe infection can reduce plant growth and yield.",
    ],
    treatment: [
      "Remove heavily infected plant material where practical.",
      "Avoid excessive nitrogen application.",
      "Maintain suitable field water management.",
      "Use locally recommended disease-control products according to the label.",
    ],
    prevention: [
      "Use resistant varieties when available.",
      "Avoid excessive nitrogen.",
      "Maintain balanced crop nutrition.",
      "Monitor the crop regularly during humid conditions.",
    ],
  },

  {
    crop: "Wheat",
    keywords: [
      "rust",
      "orange spots",
      "yellow rust",
      "brown rust",
      "wheat rust",
    ],
    disease: "Wheat Rust",
    symptoms: [
      "Yellow, orange or brown rust-like spots may appear.",
      "Rust can spread rapidly under favorable weather conditions.",
      "Leaves may lose their green color when infection becomes severe.",
    ],
    treatment: [
      "Inspect nearby plants because rust can spread through the crop.",
      "Avoid unnecessary nitrogen excess.",
      "Use locally recommended fungicides only when required.",
      "Follow the product label and agricultural extension advice.",
    ],
    prevention: [
      "Use rust-resistant varieties where available.",
      "Monitor the crop regularly.",
      "Maintain balanced fertilization.",
      "Take action early when symptoms first appear.",
    ],
  },

  {
    crop: "Cotton",
    keywords: [
      "cotton leaf curl",
      "leaf curl",
      "curling leaves",
      "cotton whitefly",
      "yellow leaves",
    ],
    disease: "Possible Cotton Leaf Curl / Vector Damage",
    symptoms: [
      "Leaves may curl or become distorted.",
      "Yellowing can occur.",
      "Whiteflies may be associated with leaf-curl problems.",
    ],
    treatment: [
      "Inspect the underside of leaves for whiteflies.",
      "Remove severely affected plant material when appropriate.",
      "Control vectors only using locally approved products and label directions.",
      "Avoid unnecessary pesticide applications.",
    ],
    prevention: [
      "Monitor whitefly populations regularly.",
      "Remove heavily affected plants when recommended locally.",
      "Maintain field hygiene.",
      "Use resistant or tolerant varieties where available.",
    ],
  },

  {
    crop: "General",
    keywords: [
      "yellow leaves",
      "yellow leaf",
      "yellowing",
      "pale leaves",
    ],
    disease: "Possible Nutrient Stress",
    symptoms: [
      "Leaves may become pale or yellow.",
      "Older or younger leaves may be affected differently depending on the nutrient.",
      "Waterlogging, drought and disease can also cause yellowing.",
    ],
    treatment: [
      "Check soil moisture before applying fertilizer.",
      "Inspect roots and leaves for signs of disease or pests.",
      "Avoid blindly applying high doses of fertilizer.",
      "Use soil testing where possible before correcting nutrient deficiencies.",
    ],
    prevention: [
      "Maintain balanced nutrition.",
      "Avoid over-irrigation.",
      "Maintain proper drainage.",
      "Monitor new and older leaves regularly.",
    ],
  },

  {
    crop: "General",
    keywords: [
      "white powder",
      "powder on leaf",
      "powdery",
      "white coating",
    ],
    disease: "Possible Powdery Mildew",
    symptoms: [
      "White powder-like growth may appear on leaf surfaces.",
      "Leaves can become weak or distorted.",
      "The disease can spread under favorable conditions.",
    ],
    treatment: [
      "Remove severely affected leaves where practical.",
      "Improve air circulation around plants.",
      "Avoid excessive humidity around foliage.",
      "Use an approved fungicide according to the product label if required.",
    ],
    prevention: [
      "Maintain suitable plant spacing.",
      "Avoid excessive nitrogen.",
      "Keep the crop well ventilated.",
      "Inspect plants regularly.",
    ],
  },
];

const normalize = (value: string) =>
  value
    .toLowerCase()
    .replace(/[^\w\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim();

export function diagnoseOffline(
  text: string,
  cropHint = ""
): OfflineDiagnosis {
  const query = normalize(`${cropHint} ${text}`);

  let bestRule: CropRule | null = null;
  let bestScore = 0;

  for (const rule of RULES) {
    let score = 0;

    for (const keyword of rule.keywords) {
      if (query.includes(normalize(keyword))) {
        score += keyword.split(" ").length;
      }
    }

    if (
      cropHint &&
      normalize(cropHint).includes(normalize(rule.crop))
    ) {
      score += 2;
    }

    if (score > bestScore) {
      bestScore = score;
      bestRule = rule;
    }
  }

  if (!bestRule) {
    return {
      disease: "Problem Not Clearly Identified",
      crop: cropHint || "Unknown crop",
      confidence: 0.35,
      symptoms: [
        "Offline mode cannot confidently identify this problem.",
        "Check the leaf for spots, discoloration, curling, insects or fungal growth.",
      ],
      treatment: [
        "Do not apply a strong pesticide only from this offline result.",
        "Remove severely damaged plant material when appropriate.",
        "Check irrigation, drainage and soil condition.",
        "When internet becomes available, run the image through the AI/ML analysis.",
      ],
      prevention: [
        "Inspect the crop regularly.",
        "Maintain proper irrigation and drainage.",
        "Keep the field clean.",
      ],
      isHealthy: false,
      offline: true,
    };
  }

  const confidence = Math.min(
    0.9,
    0.5 + bestScore * 0.08
  );

  return {
    disease: bestRule.disease,
    crop:
      bestRule.crop === "General"
        ? cropHint || "Unknown crop"
        : bestRule.crop,
    confidence,
    symptoms: bestRule.symptoms,
    treatment: bestRule.treatment,
    prevention: bestRule.prevention,
    isHealthy: false,
    offline: true,
  };
}


/* =========================================================
   OFFLINE CHAT
   ========================================================= */

export function offlineFarmChat(
  message: string
): string {
  const q = normalize(message);

  if (
    q.includes("fertilizer") ||
    q.includes("fertiliser") ||
    q.includes("khad")
  ) {
    return `Offline Farming Advice 🌱

Fertilizer kab dena hai:
• Soil condition aur crop growth stage ko dhyan me rakhein.
• Excess fertilizer na use karein.
• Possible ho to soil test ke basis par fertilizer quantity decide karein.
• Rain ke just pehle unnecessary fertilizer application avoid karein.
• Crop-specific recommendation ke liye internet available hone par AI/local agricultural guidance check karein.`;
  }

  if (
    q.includes("water") ||
    q.includes("irrigation") ||
    q.includes("pani")
  ) {
    return `Offline Irrigation Advice 💧

• Soil moisture check karke irrigation karein.
• Waterlogging avoid karein.
• Bahut dry soil me ekdum excessive water dene ke bajay suitable irrigation karein.
• Leaves ko unnecessary wet karne se fungal disease ka risk badh sakta hai.
• Crop aur soil type ke according irrigation schedule rakhein.`;
  }

  if (
    q.includes("pest") ||
    q.includes("insect") ||
    q.includes("keeda") ||
    q.includes("insect")
  ) {
    return `Offline Pest Advice 🐛

• Leaves ke upper aur underside dono inspect karein.
• Pest ki quantity aur affected area note karein.
• Heavily damaged leaves ko appropriate situation me remove karein.
• Beneficial insects ko unnecessary pesticide se protect karein.
• Chemical pesticide use karne se pehle product label aur local agricultural guidance follow karein.`;
  }

  if (
    q.includes("yellow") ||
    q.includes("yellowing") ||
    q.includes("peela")
  ) {
    return `Possible Yellowing Problem 🌿

Yellow leaves ka reason nutrient deficiency, excess water, insufficient water, root problem ya disease ho sakta hai.

Abhi:
• Soil moisture check karein.
• Roots aur leaves inspect karein.
• Pests ke liye underside of leaves check karein.
• Bina diagnosis ke heavy fertilizer/pesticide dose na dein.

Internet available hone par detailed AI/ML analysis karein.`;
  }

  if (
    q.includes("disease") ||
    q.includes("problem") ||
    q.includes("dikkat") ||
    q.includes("bimari")
  ) {
    return `Offline Crop Help 🌱

Photo ya symptoms ke basis par offline mode basic agricultural guidance de sakta hai.

Check karein:
• Leaf spots
• Yellowing
• Curling
• White powder
• Insects
• Wilting
• Stem/root damage

Agar crop ka naam aur symptoms likhen, offline knowledge engine likely problem suggest kar sakta hai.`;
  }

  return `Krishi Rakshak Offline Mode 🌾

Internet available nahi hai, isliye live Gemini AI response available nahi hai.

Aap:
• Crop disease symptoms check kar sakte hain
• Basic treatment/prevention guidance le sakte hain
• Previous saved scans dekh sakte hain
• Crop safety steps follow kar sakte hain

Important: unknown disease ke case me bina proper diagnosis ke strong chemical treatment start na karein. Internet aane par AI/ML analysis se result verify karein.`;
}