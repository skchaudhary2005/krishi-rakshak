import { motion } from 'framer-motion';
import { useNavigate } from 'react-router-dom';
import { Sprout, Sparkles } from 'lucide-react';
import { useLanguage } from '../context/LanguageContext';

const Splash = () => {
  const navigate = useNavigate();
  const { t } = useLanguage();

  return (
    <div className="min-h-screen flex flex-col items-center justify-center p-6 bg-gradient-to-br from-primary-500 via-primary-600 to-earth-600">
      <motion.div
        initial={{ scale: 0.5, opacity: 0 }}
        animate={{ scale: 1, opacity: 1 }}
        transition={{ duration: 0.6 }}
        className="text-center"
      >
        <motion.div
          animate={{ rotate: [0, 10, -10, 0] }}
          transition={{ duration: 2, repeat: Infinity, repeatDelay: 3 }}
          className="inline-block mb-6"
        >
          <div className="bg-white rounded-full p-8 shadow-2xl">
            <Sprout size={80} className="text-primary-600" />
          </div>
        </motion.div>

        <motion.h1
          initial={{ y: 20, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          transition={{ delay: 0.3 }}
          className="text-5xl font-bold text-white mb-4 flex items-center justify-center gap-2"
        >
          {t('appName')}
          <Sparkles className="text-accent-300" size={32} />
        </motion.h1>

        <motion.p
          initial={{ y: 20, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          transition={{ delay: 0.5 }}
          className="text-xl text-primary-50 mb-12 max-w-md"
        >
          {t('tagline')}
        </motion.p>

        <motion.button
          initial={{ y: 20, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          transition={{ delay: 0.7 }}
          whileHover={{ scale: 1.05 }}
          whileTap={{ scale: 0.95 }}
          onClick={() => navigate('/home')}
          className="bg-white text-primary-700 font-bold py-4 px-12 rounded-full shadow-2xl hover:shadow-xl transition-all text-lg"
        >
          {t('getStarted')} →
        </motion.button>
      </motion.div>

      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 1 }}
        className="absolute bottom-8 text-primary-100 text-sm"
      >
        Powered by AI • Made with ❤️ for Farmers
      </motion.div>
    </div>
  );
};

export default Splash;