import { motion } from 'framer-motion';
import { useLocation, useNavigate } from 'react-router-dom';
import { CheckCircle, AlertCircle, ArrowLeft, Phone, Zap, Sparkles, Clock } from 'lucide-react';
import { useLanguage } from '../context/LanguageContext';
import type { DiseaseResult } from '../services/diseaseApi';
import Navbar from '../components/Navbar';

const Result = () => {
  const location = useLocation();
  const navigate = useNavigate();
  const { t } = useLanguage();
  const { result, image } = location.state as { result: DiseaseResult; image: string };

  if (!result) {
    navigate('/home');
    return null;
  }

  const isHealthy = result.disease.toLowerCase().includes('healthy');

  return (
    <div className="min-h-screen">
      <Navbar />
      
      <div className="container mx-auto px-4 py-8 max-w-3xl">
        <button
          onClick={() => navigate('/home')}
          className="flex items-center gap-2 text-primary-700 hover:text-primary-900 mb-6 font-semibold"
        >
          <ArrowLeft size={20} />
          Back to Home
        </button>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="card"
        >
          <div className="mb-6">
            <img
              src={image}
              alt="Analyzed crop"
              className="w-full h-56 object-cover rounded-xl"
            />
          </div>

          <div className={`flex items-center gap-3 mb-6 p-4 rounded-xl ${
            isHealthy ? 'bg-green-50' : 'bg-orange-50'
          }`}>
            {isHealthy ? (
              <CheckCircle className="text-green-600" size={40} />
            ) : (
              <AlertCircle className="text-orange-600" size={40} />
            )}
            <div className="flex-1">
              <h2 className="text-2xl font-bold text-gray-800">{result.disease}</h2>
              <p className="text-gray-600">
                {t('confidence')}: <span className="font-bold">{(result.confidence * 100).toFixed(0)}%</span>
              </p>
              {result.detectionMethod && (
                <div className="flex gap-2 mt-2 flex-wrap">
                  {result.detectionMethod.includes('REAL-ML') && (
                    <span className="inline-flex items-center gap-1 px-3 py-1 bg-gradient-to-r from-blue-500 to-blue-600 text-white text-xs font-semibold rounded-full">
                      <Zap size={12} />
                      90%+ Trained Model
                    </span>
                  )}
                  {result.detectionMethod.includes('ML') && !result.detectionMethod.includes('REAL-ML') && (
                    <span className="inline-flex items-center gap-1 px-2 py-1 bg-blue-100 text-blue-700 text-xs font-semibold rounded-full">
                      <Zap size={12} />
                      ML Detected
                    </span>
                  )}
                  {result.detectionMethod.includes('AI') && (
                    <span className="inline-flex items-center gap-1 px-2 py-1 bg-purple-100 text-purple-700 text-xs font-semibold rounded-full">
                      <Sparkles size={12} />
                      AI Enhanced
                    </span>
                  )}
                  {result.mlPrediction && (
                    <span className="inline-flex items-center gap-1 px-2 py-1 bg-green-100 text-green-700 text-xs font-semibold rounded-full">
                      Real Data Trained
                    </span>
                  )}
                  {result.processingTime && (
                    <span className="inline-flex items-center gap-1 px-2 py-1 bg-gray-100 text-gray-700 text-xs font-semibold rounded-full">
                      <Clock size={12} />
                      {(result.processingTime / 1000).toFixed(1)}s
                    </span>
                  )}
                </div>
              )}
            </div>
          </div>

          {/* ML Model Detection Results */}
          {result.mlPrediction && (
            <motion.div
              initial={{ opacity: 0, y: -10 }}
              animate={{ opacity: 1, y: 0 }}
              className="mb-6 p-4 bg-gradient-to-r from-blue-50 to-purple-50 border-2 border-blue-200 rounded-xl"
            >
              <h3 className="font-bold text-blue-900 mb-3 flex items-center gap-2">
                <Zap className="text-blue-600" size={20} />
                🤖 ML Model Detection (Quick Scan)
              </h3>
              <div className="grid grid-cols-2 gap-3 text-sm">
                <div className="bg-white p-3 rounded-lg">
                  <p className="text-gray-600 font-semibold">Crop Identified</p>
                  <p className="text-blue-900 font-bold text-lg">{result.mlPrediction.crop}</p>
                </div>
                <div className="bg-white p-3 rounded-lg">
                  <p className="text-gray-600 font-semibold">Disease Detected</p>
                  <p className="text-blue-900 font-bold text-lg">{result.mlPrediction.disease}</p>
                </div>
                <div className="bg-white p-3 rounded-lg">
                  <p className="text-gray-600 font-semibold">ML Confidence</p>
                  <p className="text-blue-900 font-bold text-lg">{(result.mlPrediction.confidence * 100).toFixed(1)}%</p>
                </div>
                <div className="bg-white p-3 rounded-lg">
                  <p className="text-gray-600 font-semibold">Health Status</p>
                  <p className={`font-bold text-lg ${result.mlPrediction.isHealthy ? 'text-green-600' : 'text-orange-600'}`}>
                    {result.mlPrediction.isHealthy ? '✅ Healthy' : '⚠️ Diseased'}
                  </p>
                </div>
              </div>
            </motion.div>
          )}

          {/* AI Medical Treatment Section */}
          <div className="mb-4 p-3 bg-gradient-to-r from-purple-50 to-pink-50 border-2 border-purple-200 rounded-xl">
            <h3 className="font-bold text-purple-900 flex items-center gap-2">
              <Sparkles className="text-purple-600" size={20} />
              🏥 AI Medical Analysis & Treatment Plan
            </h3>
            <p className="text-xs text-purple-700 mt-1">Detailed recommendations powered by Gemini AI</p>
          </div>

          <div className="space-y-6">
            <div>
              <h3 className="text-xl font-bold text-primary-800 mb-3 flex items-center gap-2">
                💊 {t('treatment')}
              </h3>
              <ul className="space-y-2">
                {result.treatment.map((item, index) => (
                  <motion.li
                    key={index}
                    initial={{ opacity: 0, x: -20 }}
                    animate={{ opacity: 1, x: 0 }}
                    transition={{ delay: index * 0.1 }}
                    className="flex items-start gap-2 text-gray-700"
                  >
                    <span className="text-primary-600 font-bold">•</span>
                    <span>{item}</span>
                  </motion.li>
                ))}
              </ul>
            </div>

            <div>
              <h3 className="text-xl font-bold text-primary-800 mb-3 flex items-center gap-2">
                🛡️ {t('prevention')}
              </h3>
              <ul className="space-y-2">
                {result.prevention.map((item, index) => (
                  <motion.li
                    key={index}
                    initial={{ opacity: 0, x: -20 }}
                    animate={{ opacity: 1, x: 0 }}
                    transition={{ delay: 0.5 + index * 0.1 }}
                    className="flex items-start gap-2 text-gray-700"
                  >
                    <span className="text-primary-600 font-bold">•</span>
                    <span>{item}</span>
                  </motion.li>
                ))}
              </ul>
            </div>
          </div>

          <motion.button
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 1 }}
            onClick={() => navigate('/experts')}
            className="btn-primary w-full mt-8 flex items-center justify-center gap-2"
          >
            <Phone size={20} />
            {t('findHelp')}
          </motion.button>

          {result.aiInsights && (
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 1.2 }}
              className="mt-6 p-4 bg-blue-50 border-l-4 border-blue-500 rounded-lg"
            >
              <h3 className="font-bold text-blue-800 mb-2 flex items-center gap-2">
                🤖 AI Insights
              </h3>
              <p className="text-gray-700 text-sm">{result.aiInsights}</p>
            </motion.div>
          )}
        </motion.div>
      </div>
    </div>
  );
};

export default Result;