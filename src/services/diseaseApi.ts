import { realModelService } from './realModelService';

export interface DiseaseResult {
  disease: string;
  confidence: number;
  treatment: string[];
  prevention: string[];
  aiInsights?: string;
  // ML Model Results
  mlPrediction?: {
    disease: string;
    confidence: number;
    crop: string;
    topPredictions?: Array<{
      disease: string;
      confidence: number;
    }>;
  };
  // Dual Detection Metadata
  detectionMethod?: 'REAL-ML+AI' | 'REAL-ML-Only' | 'AI-Only' | 'Fallback';
  processingTime?: number;
}


export const detectDisease = async (image: File): Promise<DiseaseResult> => {
  const startTime = Date.now();
  
  try {
    // Step 1: Load Real Trained Model (if not already loaded)
    if (!realModelService.isLoaded()) {
      console.log('🤖 Loading REAL trained model...');
      await realModelService.loadModel();
    }

    // Step 2: Run the deployed disease model
    console.log('🔬 Running REAL ML disease detection...');
    const mlResult = await realModelService.predict(image);
    
    console.log('✅ REAL ML Detection:', mlResult);
    console.log(`   Disease: ${mlResult.disease}`);
    console.log(`   Confidence: ${(mlResult.confidence * 100).toFixed(1)}%`);
    console.log(`   Crop: ${mlResult.crop}`);

    // Step 3: Get treatment/prevention/insights from the secure backend.
    // Gemini credentials stay server-side on Render; never expose them in Vercel.
    console.log('🤖 Requesting secure AI crop advice...');
    const apiBase =
      import.meta.env.VITE_API_BASE_URL ||
      import.meta.env.VITE_API_URL ||
      'http://127.0.0.1:5000';

    let advice = {
      treatment: ['Confirm the diagnosis before applying disease-specific treatment.'],
      prevention: ['Monitor the crop regularly and remove severely affected material when appropriate.'],
      aiInsights: 'Local agricultural guidance is available because live Gemini advice is temporarily unavailable.'
    };
    let aiSource = 'local_ai_advice';

    try {
      const adviceResponse = await fetch(apiBase + '/api/advice', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          disease: mlResult.disease,
          crop: mlResult.crop,
          confidence: Number((mlResult.confidence * 100).toFixed(2)),
          language: 'en'
        })
      });

      const adviceData = await adviceResponse.json();
      if (adviceResponse.ok && adviceData?.success && adviceData?.advice) {
        const a = adviceData.advice;
        advice = {
          treatment: a.treatment ? [a.treatment] : advice.treatment,
          prevention: a.prevention ? [a.prevention] : advice.prevention,
          aiInsights: [
            a.description || a.summary,
            a.farmer_action,
            adviceData.source === 'local_ai_advice'
              ? 'Live Gemini advice is temporarily unavailable; this is the built-in agricultural fallback.'
              : ''
          ].filter(Boolean).join(' ') || advice.aiInsights
        };
        aiSource = adviceData.source || 'local_ai_advice';
      }
    } catch (adviceError) {
      console.warn('⚠️ Secure AI advice unavailable:', adviceError);
    }

    const processingTime = Date.now() - startTime;
    
    // Combine both results
    return {
      disease: mlResult.disease,
      confidence: mlResult.confidence,
      treatment: advice.treatment,
      prevention: advice.prevention,
      aiInsights: advice.aiInsights,
      mlPrediction: {
        disease: mlResult.disease,
        confidence: mlResult.confidence,
        crop: mlResult.crop,
        topPredictions: mlResult.topPredictions
      },
      detectionMethod: aiSource === 'gemini_ai_advice' ? 'REAL-ML+AI' : 'REAL-ML-Only',
      processingTime
    };
  } catch (error) {
    console.error('Disease detection error:', error);
    
    // Try REAL ML-only if Gemini fails
    try {
      if (realModelService.isLoaded()) {
        console.log('⚠️ Gemini failed, using REAL ML-only detection...');
        const mlResult = await realModelService.predict(image);
        
        const processingTime = Date.now() - startTime;
        
        return {
          disease: `${mlResult.crop} - ${mlResult.disease}`,
          confidence: mlResult.confidence,
          treatment: [
            "🌾 Use the model prediction as decision-support evidence and confirm uncertain cases with an agricultural expert.",
            "Remove affected plant parts if disease is spreading",
            "Apply appropriate organic or chemical treatment for " + mlResult.disease,
            "Monitor plant health daily",
            "Consult local agricultural expert for specific treatment protocol"
          ],
          prevention: [
            "Use disease-resistant varieties",
            "Practice crop rotation to prevent " + mlResult.disease,
            "Maintain proper plant spacing and ventilation",
            "Regular monitoring for early detection",
            "Apply preventive treatments during high-risk seasons"
          ],
          mlPrediction: {
            disease: mlResult.disease,
            confidence: mlResult.confidence,
            crop: mlResult.crop,
            topPredictions: mlResult.topPredictions
          },
          detectionMethod: 'REAL-ML-Only',
          processingTime
        };
      }
    } catch (mlError) {
      console.error('REAL ML detection also failed:', mlError);
    }
    
    // Never fabricate a disease when the real model is unavailable.
    const processingTime = Date.now() - startTime;
    return {
      disease: 'Analysis unavailable',
      confidence: 0,
      treatment: [
        'The crop disease model is currently unavailable.',
        'Start the Flask backend and retry the scan.',
        'For an important crop decision, confirm the diagnosis with a qualified agricultural expert.'
      ],
      prevention: [
        'Do not apply disease-specific treatment from an unverified result.',
        'Capture a clear, well-lit image and rescan.'
      ],
      detectionMethod: 'Fallback',
      processingTime
    };
  }
};