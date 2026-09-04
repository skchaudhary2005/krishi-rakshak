import { GoogleGenAI, ThinkingLevel } from '@google/genai';

const API_KEY = import.meta.env.VITE_GEMINI_API_KEY;

if (!API_KEY) {
  console.error(
    'Gemini API key missing. Add VITE_GEMINI_API_KEY to your .env file.'
  );
}

const genAI = new GoogleGenAI({
  apiKey: API_KEY,
});

const MODEL = 'gemini-3.6-flash';

export interface ChatMessage {
  role: 'user' | 'assistant';
  content: string;
  timestamp: Date;
}


/* =========================================================
   CHAT WITH GEMINI
   FAST + STREAMING + LANGUAGE AWARE
   ========================================================= */

export const chatWithAI = async (
  message: string,
  history: ChatMessage[] = [],
  onChunk?: (text: string) => void
): Promise<string> => {
  if (!API_KEY) {
    throw new Error(
      'Gemini API key is missing. Check your .env file.'
    );
  }

  try {
    /*
     * Keep only recent messages.
     * This reduces request size and improves response time.
     */
    const recentHistory = history.slice(-4);

    const conversation = recentHistory
      .map((msg) => {
        const role =
          msg.role === 'user'
            ? 'Farmer'
            : 'Krishi Rakshak';

        return `${role}: ${msg.content}`;
      })
      .join('\n');

    /*
     * Complex agricultural questions get LOW thinking.
     * Simple questions get MINIMAL thinking for faster response.
     */
    const complexQuestion =
      /disease|diseases|रोग|बीमारी|बीमार|treatment|उपचार|इलाज|pesticide|pesticides|कीटनाशक|fungicide|fungicides|दवा|दवाई|symptom|symptoms|लक्षण|infection|संक्रमण|कीट|pest|blight|rust|virus|bacteria/i.test(
        message
      );

    const thinkingLevel = complexQuestion
      ? ThinkingLevel.LOW
      : ThinkingLevel.MINIMAL;

    /*
     * Detect user's language.
     *
     * Hindi Devanagari -> Hindi
     * English -> English
     * Roman Hindi/Hinglish -> Hinglish
     */
    const hasHindiScript =
      /[\u0900-\u097F]/.test(message);

    const hasRomanHindiWords =
      /\b(kya|kaise|kab|kyun|kyu|hai|hain|mein|me|mera|meri|mere|ko|ke|ki|ka|se|par|liye|batao|bataye|chahiye|karna|karo|krna|kr|fasal|kheti|kisan|paani|pani|mitti|rog|dawai|dawa|khad|beej|paudha|paudhe|patte|patta)\b/i.test(
        message
      );

    let languageInstruction = '';

    if (hasHindiScript) {
      languageInstruction = `
LANGUAGE:
The farmer is using Hindi.
Reply completely in Hindi using Devanagari script.
Do NOT convert Hindi into Hinglish.
Do NOT use unnecessary English words.
`;
    } else if (hasRomanHindiWords) {
      languageInstruction = `
LANGUAGE:
The farmer is using Hinglish/Roman Hindi.
Reply in natural Hinglish using Roman Hindi.
Do NOT convert it into Devanagari Hindi.
`;
    } else {
      languageInstruction = `
LANGUAGE:
The farmer is using English.
Reply completely in English.
Do NOT use Hindi or Hinglish.
`;
    }

    const prompt = `
You are "Krishi Rakshak", an expert agricultural AI assistant
designed specifically for Indian farmers.

${languageInstruction}

YOUR ROLE:
Provide accurate, practical and actionable agricultural guidance.

You can help with:
- Crop diseases
- Crop health
- Fertilizers
- Irrigation
- Pest control
- Soil management
- Organic farming
- Weather-related crop protection
- Sowing
- Harvesting
- Crop nutrition
- Farming techniques

IMPORTANT RULES:

1. Answer the farmer's exact question first.

2. Give practical steps that a farmer can actually follow.

3. Do not give vague or generic answers.

4. If the question is about a crop disease:
   - Identify likely disease if enough information exists.
   - Explain important symptoms.
   - Explain likely causes.
   - Give practical treatment.
   - Give prevention measures.

5. If recommending pesticides, fungicides or fertilizers:
   - Never pretend there is one universal dosage.
   - Mention that the farmer must follow the product label.
   - Consider crop, disease, growth stage and local agricultural recommendations.

6. Do not pretend you can see field conditions that the farmer has not provided.

7. If important information is missing, give useful general guidance first,
   then ask ONE short follow-up question.

8. Prefer Indian agricultural context.

9. Avoid unnecessary long explanations.

10. For simple questions, answer in approximately 3-6 useful points.

11. For complex disease questions, provide enough detail to be genuinely useful.

12. Never say only "consult an expert" without providing useful information.

13. If the farmer asks a normal farming question, do not add unnecessary disclaimers.

14. Keep the answer easy for a farmer to understand.

PREVIOUS CONVERSATION:
${conversation || 'No previous conversation.'}

CURRENT FARMER QUESTION:
${message}

Answer now.
`;

    console.log(
      '📤 Sending request to Gemini...'
    );

    console.log(
      '🧠 Thinking level:',
      complexQuestion
        ? 'LOW'
        : 'MINIMAL'
    );

    /*
     * STREAMING RESPONSE
     *
     * The UI receives text as soon as Gemini generates it.
     */
    const stream =
      await genAI.models.generateContentStream({
        model: MODEL,
        contents: prompt,

        config: {
          thinkingConfig: {
            thinkingLevel,
          },
        },
      });

    let fullResponse = '';

    for await (const chunk of stream) {
      const text = chunk.text || '';

      if (!text) {
        continue;
      }

      fullResponse += text;

      /*
       * Send every chunk immediately to AIChat.tsx
       */
      if (onChunk) {
        onChunk(text);
      }
    }

    const finalResponse =
      fullResponse.trim();

    if (!finalResponse) {
      throw new Error(
        'Gemini returned an empty response.'
      );
    }

    console.log(
      '✅ Gemini response completed.'
    );

    return finalResponse;

  } catch (error) {
    console.error(
      '❌ Gemini Chat Error:',
      error
    );

    throw error;
  }
};


/* =========================================================
   CROP IMAGE ANALYSIS
   ========================================================= */

export const analyzeCropImage = async (
  imageBase64: string,
  mlPrediction?: {
    disease: string;
    crop: string;
    confidence: number;
    isHealthy: boolean;
  }
): Promise<{
  disease: string;
  confidence: number;
  treatment: string[];
  prevention: string[];
  aiInsights: string;
}> => {

  try {

    if (!API_KEY) {
      throw new Error(
        'Gemini API key is missing.'
      );
    }

    const mlContext = mlPrediction
      ? `
Machine learning prediction:

Crop: ${mlPrediction.crop}
Disease: ${mlPrediction.disease}
Confidence: ${(mlPrediction.confidence * 100).toFixed(1)}%
Status: ${
          mlPrediction.isHealthy
            ? 'Healthy'
            : 'Diseased'
        }

Use this prediction as supporting information,
but independently analyze the image.
`
      : '';

    const prompt = `
You are an expert plant pathologist and agricultural advisor.

Analyze the uploaded crop leaf image.

${mlContext}

Return ONLY valid JSON.

Required structure:

{
  "disease": "Disease name or Healthy Leaf",
  "confidence": 0,
  "treatment": [
    "Treatment recommendation 1",
    "Treatment recommendation 2",
    "Treatment recommendation 3"
  ],
  "prevention": [
    "Prevention recommendation 1",
    "Prevention recommendation 2",
    "Prevention recommendation 3"
  ],
  "insights": "Additional crop health insights"
}

Rules:

- confidence must be between 0 and 100.
- Return valid JSON only.
- Do not use markdown.
- Do not use code fences.
- Give practical agricultural advice.
- Do not invent certainty when image quality is poor.
- For chemical products, advise following the product label
  and local agricultural recommendations.
`;

    /*
     * Extract MIME type and base64 data.
     */
    const matches =
      imageBase64.match(
        /^data:(image\/[^;]+);base64,(.+)$/
      );

    if (!matches) {
      throw new Error(
        'Invalid image data format.'
      );
    }

    const mimeType = matches[1];
    const base64Data = matches[2];

    const result =
      await genAI.models.generateContent({
        model: MODEL,

        contents: [
          {
            role: 'user',

            parts: [
              {
                text: prompt,
              },

              {
                inlineData: {
                  mimeType,
                  data: base64Data,
                },
              },
            ],
          },
        ],

        config: {
          thinkingConfig: {
            thinkingLevel:
              ThinkingLevel.LOW,
          },
        },
      });

    const text =
      result.text?.trim();

    if (!text) {
      throw new Error(
        'Empty image analysis response.'
      );
    }

    /*
     * Remove markdown fences if Gemini adds them.
     */
    const cleanedText =
      text
        .replace(/^```json\s*/i, '')
        .replace(/^```\s*/i, '')
        .replace(/\s*```$/i, '')
        .trim();

    const parsed =
      JSON.parse(cleanedText);

    return {
      disease:
        parsed.disease ||
        'Unknown',

      confidence:
        Number(
          parsed.confidence || 0
        ) / 100,

      treatment:
        Array.isArray(
          parsed.treatment
        )
          ? parsed.treatment
          : [],

      prevention:
        Array.isArray(
          parsed.prevention
        )
          ? parsed.prevention
          : [],

      aiInsights:
        parsed.insights || '',
    };

  } catch (error) {

    console.error(
      '❌ Gemini Vision Error:',
      error
    );

    return {
      disease:
        'Analysis Pending',

      confidence: 0,

      treatment: [
        'AI image analysis is temporarily unavailable.',
        'Please try uploading the image again.',
        'Make sure the crop leaf image is clear and well lit.',
      ],

      prevention: [
        'Regularly inspect your crops.',
        'Maintain proper irrigation.',
        'Remove severely infected plant material when appropriate.',
      ],

      aiInsights:
        'AI image analysis is temporarily unavailable. Please try again.',
    };
  }
};


/* =========================================================
   FARMING RECOMMENDATIONS
   ========================================================= */

export const getFarmingRecommendations =
  async (
    crop: string,
    location: string,
    season: string
  ): Promise<string> => {

    try {

      if (!API_KEY) {
        throw new Error(
          'Gemini API key is missing.'
        );
      }

      const prompt = `
You are Krishi Rakshak,
an agricultural advisor for Indian farmers.

Crop: ${crop}
Location: ${location}
Season: ${season}

Provide practical and concise advice about:

1. Best farming practices
2. Common diseases and pests
3. Fertilizer management
4. Irrigation
5. Crop protection
6. Harvest timing

Use simple language.

If the farmer's location is important,
consider local Indian agricultural conditions.
`;

      const result =
        await genAI.models.generateContent({
          model: MODEL,
          contents: prompt,

          config: {
            thinkingConfig: {
              thinkingLevel:
                ThinkingLevel.LOW,
            },
          },
        });

      return (
        result.text?.trim() ||
        'Unable to generate recommendations.'
      );

    } catch (error) {

      console.error(
        '❌ Farming Recommendation Error:',
        error
      );

      return (
        'Unable to generate recommendations at this time.'
      );
    }
  };


/* =========================================================
   WEATHER ADVICE
   ========================================================= */

export const getWeatherAdvice =
  async (
    weatherCondition: string,
    crop: string
  ): Promise<string> => {

    try {

      if (!API_KEY) {
        throw new Error(
          'Gemini API key is missing.'
        );
      }

      const prompt = `
You are Krishi Rakshak,
an agricultural advisor for Indian farmers.

Crop:
${crop}

Current weather:
${weatherCondition}

Explain:

1. How this weather can affect the crop.
2. What immediate steps the farmer should take.
3. What precautions should be taken next.

Keep the answer practical,
concise and easy to understand.
`;

      const result =
        await genAI.models.generateContent({
          model: MODEL,
          contents: prompt,

          config: {
            thinkingConfig: {
              thinkingLevel:
                ThinkingLevel.LOW,
            },
          },
        });

      return (
        result.text?.trim() ||
        'Unable to provide weather advice.'
      );

    } catch (error) {

      console.error(
        '❌ Weather Advice Error:',
        error
      );

      return (
        'Unable to provide weather advice at this time.'
      );
    }
  };