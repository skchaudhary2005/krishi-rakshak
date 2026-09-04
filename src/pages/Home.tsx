import { useState } from 'react';
import { motion } from 'framer-motion';
import { useNavigate } from 'react-router-dom';
import { Camera, Upload, Loader } from 'lucide-react';
import { useLanguage } from '../context/LanguageContext';
import { detectDisease } from '../services/diseaseApi';
import type { DiseaseResult } from '../services/diseaseApi';
import Navbar from '../components/Navbar';

const Home = () => {
  const navigate = useNavigate();
  const { t } = useLanguage();
  const [image, setImage] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const handleImageUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      const reader = new FileReader();
      reader.onloadend = () => {
        setImage(reader.result as string);
      };
      reader.readAsDataURL(file);
    }
  };

  const handleDetect = async () => {
    if (!image) return;
    
    setLoading(true);
    try {
      const blob = await fetch(image).then(r => r.blob());
      const file = new File([blob], 'crop.jpg', { type: 'image/jpeg' });
      const result: DiseaseResult = await detectDisease(file);
      navigate('/result', { state: { result, image } });
    } catch (error) {
      console.error('Detection failed:', error);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen">
      <Navbar />
      
      <div className="container mx-auto px-4 py-8 max-w-2xl">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="card mt-4"
        >
          <h2 className="text-2xl font-bold text-primary-800 mb-6 text-center">
            Upload Crop Image
          </h2>

          {image ? (
            <motion.div
              initial={{ scale: 0.9 }}
              animate={{ scale: 1 }}
              className="mb-6"
            >
              <img
                src={image}
                alt="Uploaded crop"
                className="w-full h-64 object-cover rounded-xl border-4 border-primary-200"
              />
              <button
                onClick={() => setImage(null)}
                className="mt-4 text-primary-600 hover:text-primary-800 font-semibold"
              >
                ✕ Remove Image
              </button>
            </motion.div>
          ) : (
            <div className="border-4 border-dashed border-primary-300 rounded-xl p-12 mb-6 bg-primary-50">
              <div className="text-center text-primary-600">
                <Camera size={48} className="mx-auto mb-4" />
                <p className="text-lg">No image selected</p>
              </div>
            </div>
          )}

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
            <label className="cursor-pointer">
              <input
                type="file"
                accept="image/*"
                capture="environment"
                onChange={handleImageUpload}
                className="hidden"
              />
              <div className="btn-secondary flex items-center justify-center gap-2">
                <Camera size={20} />
                {t('captureImage')}
              </div>
            </label>

            <label className="cursor-pointer">
              <input
                type="file"
                accept="image/*"
                onChange={handleImageUpload}
                className="hidden"
              />
              <div className="btn-secondary flex items-center justify-center gap-2">
                <Upload size={20} />
                {t('uploadImage')}
              </div>
            </label>
          </div>

          <button
            onClick={handleDetect}
            disabled={!image || loading}
            className={`btn-primary w-full flex items-center justify-center gap-2 ${
              !image || loading ? 'opacity-50 cursor-not-allowed' : ''
            }`}
          >
            {loading ? (
              <>
                <Loader className="animate-spin" size={20} />
                {t('processing')}
              </>
            ) : (
              t('detectDisease')
            )}
          </button>
        </motion.div>

        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.3 }}
          className="mt-8 p-6 bg-white rounded-xl shadow-md"
        >
          <h3 className="font-semibold text-primary-800 mb-3">💡 Tips for Best Results:</h3>
          <ul className="text-sm text-gray-700 space-y-2">
            <li>• Take photos in good natural lighting</li>
            <li>• Focus on the affected leaf area</li>
            <li>• Avoid blurry or dark images</li>
            <li>• Capture clear symptoms of the disease</li>
          </ul>
        </motion.div>
      </div>
    </div>
  );
};

export default Home;