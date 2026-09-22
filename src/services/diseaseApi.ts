import { realModelService } from './realModelService';

export interface DiseaseResult {
  disease: string;
  confidence: number;
  treatment: string[];
  prevention: string[];
  aiInsights?: string;
  diagnosisStatus?: 'confirmed' | 'review' | 'uncertain';
  diagnosisMessage?: string;
  mlPrediction?: {
    disease: string;
    confidence: number;
    crop: string;
    topPredictions?: Array<{
      disease: string;
      confidence: number;
    }>;
  };
  detectionMethod?: 'REAL-ML+AI' | 'REAL-ML-Only' | 'AI-Only' | 'Fallback';
  processingTime?: number;
}

const ML_REVIEW_THRESHOLD = 0.60;
const ML_CONFIRM_THRESHOLD = 0.80;
const ML_MIN_MARGIN = 0.10;
const VISION_CONFIRM_THRESHOLD = 70;

const normalizeLabel = (value: string) =>
  String(value || '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();

const visionAgrees = (vision: any, mlResult: any) => {
  if (!vision) return false;
  if (vision.agreement !== 'agree') return false;
  if (Number(vision.confidence) < VISION_CONFIRM_THRESHOLD) return false;

  const mlDisease = normalizeLabel(mlResult.disease);
  const visualDisease = normalizeLabel(vision.disease);
  const mlCrop = normalizeLabel(mlResult.crop);
  const visualCrop = normalizeLabel(vision.crop);

  const diseaseMatch =
    visualDisease === mlDisease ||
    visualDisease.includes(mlDisease) ||
    mlDisease.includes(visualDisease);

  const cropMatch =
    !mlCrop ||
    !visualCrop ||
    visualCrop === mlCrop ||
    visualCrop.includes(mlCrop) ||
    mlCrop.includes(visualCrop);

  return diseaseMatch && cropMatch;
};

const buildSafeAdvice = (status: 'confirmed' | 'review' | 'uncertain') => {
  if (status === 'confirmed') {
    return {
      treatment: ['Use only a locally registered treatment confirmed for this crop and disease. Follow the product label and local agricultural guidance exactly.'],
      prevention: ['Continue field sanitation, appropriate spacing/airflow, careful irrigation, and regular monitoring.'],
      aiInsights: 'The diagnosis passed the application safety gate using strong ML evidence plus independent visual agreement.'
    };
  }

  return {
    treatment: [
      'Do NOT apply disease-specific fungicide, pesticide, or other chemical treatment from this scan alone.',
      'Confirm the diagnosis with a clear leaf-level image and a qualified local agriculture expert/KVK before spraying.'
    ],
    prevention: [
      'Inspect several affected and unaffected plants, isolate severely affected material where appropriate, and avoid unnecessary chemical application until the diagnosis is confirmed.',
      'Capture a clear, well-lit close-up of the affected leaf, including both sides if possible.'
    ],
    aiInsights:
      status === 'uncertain'
        ? 'The system could not obtain reliable evidence for a disease diagnosis. This result is intentionally withheld to prevent an incorrect treatment recommendation.'
        : 'The scan needs expert/visual confirmation before any disease-specific treatment is recommended.'
  };
};

export const detectDisease = async (image: File): Promise<DiseaseResult> => {
  const startTime = Date.now();

  try {
    if (!realModelService.isLoaded()) {
      await realModelService.loadModel();
    }

    const mlResult = await realModelService.predict(image);
    console.log('✅ REAL ML Detection:', mlResult);

    const apiBase =
      import.meta.env.VITE_API_BASE_URL ||
      import.meta.env.VITE_API_URL ||
      'https://krishi-rakshak-api.onrender.com';

    let visionAnalysis: any = null;

    try {
      const visionForm = new FormData();
      visionForm.append('image', image);
      visionForm.append('ml_disease', mlResult.disease);
      visionForm.append('ml_crop', mlResult.crop);
      visionForm.append('ml_confidence', String(Number((mlResult.confidence * 100).toFixed(2))));
      visionForm.append('language', 'en');

      const visionResponse = await fetch(apiBase + '/api/ai-vision', {
        method: 'POST',
        body: visionForm
      });

      if (visionResponse.ok) {
        const visionData = await visionResponse.json();
        if (visionData?.success && visionData?.vision) {
          visionAnalysis = visionData.vision;
          console.log('👁️ GEMINI VISION:', visionAnalysis);
        }
      }
    } catch (visionError) {
      console.warn('⚠️ Gemini Vision unavailable:', visionError);
    }

    const topPredictions = mlResult.topPredictions || [];
    const secondConfidence = topPredictions[1]?.confidence ?? 0;
    const margin = Math.max(0, mlResult.confidence - secondConfidence);
    const mlStrongEnough =
      mlResult.confidence >= ML_CONFIRM_THRESHOLD &&
      margin >= ML_MIN_MARGIN;

    let diagnosisStatus: 'confirmed' | 'review' | 'uncertain';
    let diagnosisMessage: string;

    if (mlResult.confidence < ML_REVIEW_THRESHOLD || margin < 0.05) {
      diagnosisStatus = 'uncertain';
      diagnosisMessage = 'Insufficient model evidence. The disease prediction is withheld.';
    } else if (visionAnalysis && (visionAnalysis.agreement === 'disagree' || visionAnalysis.agreement === 'uncertain')) {
      diagnosisStatus = 'review';
      diagnosisMessage = 'ML and independent visual analysis do not provide sufficient agreement.';
    } else if (mlStrongEnough && visionAgrees(visionAnalysis, mlResult)) {
      diagnosisStatus = 'confirmed';
      diagnosisMessage = 'Strong ML evidence and independent visual agreement were obtained.';
    } else {
      diagnosisStatus = 'review';
      diagnosisMessage = visionAnalysis
        ? 'The result needs visual/expert confirmation before disease-specific treatment.'
        : 'Independent visual verification was unavailable; disease-specific treatment is withheld.';
    }

    const safeAdvice = buildSafeAdvice(diagnosisStatus);

    let advice = safeAdvice;
    let aiSource = 'safety_gate';

    if (diagnosisStatus === 'confirmed') {
      try {
        const adviceResponse = await fetch(apiBase + '/api/advice', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            disease: mlResult.disease,
            crop: mlResult.crop,
            confidence: Number((mlResult.confidence * 100).toFixed(2)),
            diagnosis_status: diagnosisStatus,
            vision_agreement: visionAnalysis?.agreement || 'unknown',
            language: 'en'
          })
        });

        const adviceData = await adviceResponse.json();
        if (adviceResponse.ok && adviceData?.success && adviceData?.advice) {
          const a = adviceData.advice;
          advice = {
            treatment: a.treatment ? [a.treatment] : safeAdvice.treatment,
            prevention: a.prevention ? [a.prevention] : safeAdvice.prevention,
            aiInsights: [
              a.description || a.summary,
              a.farmer_action
            ].filter(Boolean).join(' ') || safeAdvice.aiInsights
          };
          aiSource = adviceData.source || 'gemini_ai_advice';
        }
      } catch (adviceError) {
        console.warn('⚠️ Secure AI advice unavailable:', adviceError);
      }
    }

    const processingTime = Date.now() - startTime;
    const displayedDisease = diagnosisStatus === 'confirmed'
      ? mlResult.disease
      : 'Diagnosis uncertain — rescan required';

    const visionText = visionAnalysis
      ? `Gemini Vision: ${visionAnalysis.disease} (${Number(visionAnalysis.confidence).toFixed(1)}%). ${visionAnalysis.observations} Agreement with ML: ${visionAnalysis.agreement}.`
      : 'Independent visual verification was unavailable for this scan.';

    return {
      disease: displayedDisease,
      confidence: mlResult.confidence,
      treatment: advice.treatment,
      prevention: advice.prevention,
      aiInsights: [
        advice.aiInsights,
        diagnosisMessage,
        visionText,
        diagnosisStatus !== 'confirmed'
          ? 'No disease-specific chemical treatment should be applied from this scan alone.'
          : ''
      ].filter(Boolean).join(' '),
      diagnosisStatus,
      diagnosisMessage,
      mlPrediction: {
        disease: mlResult.disease,
        confidence: mlResult.confidence,
        crop: mlResult.crop,
        topPredictions: mlResult.topPredictions
      },
      detectionMethod: (aiSource === 'gemini_ai_advice' || visionAnalysis) ? 'REAL-ML+AI' : 'REAL-ML-Only',
      processingTime
    };
  } catch (error) {
    console.error('Disease detection error:', error);

    try {
      if (realModelService.isLoaded()) {
        const mlResult = await realModelService.predict(image);
        const processingTime = Date.now() - startTime;

        return {
          disease: 'Diagnosis uncertain — rescan required',
          confidence: mlResult.confidence,
          treatment: [
            'Do NOT apply disease-specific treatment from this scan.',
            'Capture a clear leaf-level image and confirm the diagnosis with a qualified agricultural expert/KVK.'
          ],
          prevention: [
            'Inspect several plants and avoid unnecessary chemical treatment until the diagnosis is confirmed.',
            'Use a clear, well-lit close-up image for the next scan.'
          ],
          aiInsights: `The safety gate blocked a disease-specific recommendation because independent verification was unavailable. The raw ML candidate was ${mlResult.disease} at ${(mlResult.confidence * 100).toFixed(1)}% confidence.`,
          diagnosisStatus: 'uncertain',
          diagnosisMessage: 'Independent verification was unavailable; disease-specific treatment is withheld.',
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

    const processingTime = Date.now() - startTime;
    return {
      disease: 'Analysis unavailable',
      confidence: 0,
      treatment: [
        'The crop disease model is currently unavailable.',
        'For an important crop decision, confirm the diagnosis with a qualified agricultural expert.'
      ],
      prevention: [
        'Do not apply disease-specific treatment from an unverified result.',
        'Capture a clear, well-lit image and rescan.'
      ],
      diagnosisStatus: 'uncertain',
      diagnosisMessage: 'No reliable diagnosis is available.',
      detectionMethod: 'Fallback',
      processingTime
    };
  }
};
