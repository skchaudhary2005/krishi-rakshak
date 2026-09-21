import { analyzeCropImage } from './geminiService';
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

    // Convert image to base64 for Gemini
    const reader = new FileReader();
    const base64Promise = new Promise<string>((resolve) => {
      reader.onloadend = () => resolve(reader.result as string);
      reader.readAsDataURL(image);
    });
    
    const imageBase64 = await base64Promise;
    
    // Step 3: Detailed Gemini AI Analysis (Medicine & Treatment)
    console.log('🤖 Running Gemini AI analysis for detailed recommendations...');
    const geminiResult = await analyzeCropImage(imageBase64, {
      disease: mlResult.disease,
      confidence: mlResult.confidence,
      crop: mlResult.crop,
      isHealthy: mlResult.isHealthy
    });
    
    const processingTime = Date.now() - startTime;
    
    // Combine both results
    return {
      disease: mlResult.disease,
      confidence: mlResult.confidence,
      treatment: geminiResult.treatment,
      prevention: geminiResult.prevention,
      aiInsights: geminiResult.aiInsights,
      mlPrediction: {
        disease: mlResult.disease,
        confidence: mlResult.confidence,
        crop: mlResult.crop,
        topPredictions: mlResult.topPredictions
      },
      detectionMethod: 'REAL-ML+AI',
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