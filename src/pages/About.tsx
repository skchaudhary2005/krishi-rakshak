import { motion } from 'framer-motion';
import {
  Sparkles,
  CheckCircle,
  AlertTriangle,
  ShieldCheck,
  BrainCircuit,
  Camera,
  Stethoscope,
  Languages,
  Leaf,
  Sprout,
  ArrowRight,
} from 'lucide-react';
import { useLanguage } from '../context/LanguageContext';
import Navbar from '../components/Navbar';

const About = () => {
  const { t } = useLanguage();

  const floatingLeaves = [
    { left: '5%', top: '18%', size: 30, delay: 0 },
    { left: '88%', top: '22%', size: 26, delay: 1.2 },
    { left: '12%', top: '55%', size: 22, delay: 2 },
    { left: '92%', top: '60%', size: 34, delay: 0.7 },
    { left: '18%', top: '82%', size: 28, delay: 1.8 },
    { left: '82%', top: '84%', size: 24, delay: 2.5 },
  ];

  const features = [
    {
      icon: BrainCircuit,
      title: 'AI Disease Detection',
      description:
        'Advanced MobileNetV2 model analyzes crop images and identifies possible diseases.',
    },
    {
      icon: Camera,
      title: 'Easy Image Analysis',
      description:
        'Upload or capture a clear crop leaf image for quick AI-powered analysis.',
    },
    {
      icon: Stethoscope,
      title: 'Treatment Guidance',
      description:
        'Get useful treatment and prevention suggestions after disease detection.',
    },
    {
      icon: ShieldCheck,
      title: 'Crop Protection',
      description:
        'Early identification helps farmers take action before crop problems spread.',
    },
    {
      icon: Languages,
      title: 'Multiple Languages',
      description:
        'Use Krishi Rakshak in English, Hindi and Telugu.',
    },
    {
      icon: Sprout,
      title: 'Farmer Focused',
      description:
        'Designed to make modern AI technology simple and useful for farmers.',
    },
  ];

  return (
    <div className="min-h-screen overflow-hidden bg-gradient-to-b from-green-50 via-white to-emerald-50">
      <Navbar />

      {/* =========================================================
          ANIMATED BACKGROUND
      ========================================================= */}
      <div className="fixed inset-0 pointer-events-none overflow-hidden -z-0">
        {/* Soft glowing circles */}
        <motion.div
          className="absolute -top-32 -left-32 h-96 w-96 rounded-full bg-green-200/30 blur-3xl"
          animate={{
            scale: [1, 1.15, 1],
            x: [0, 30, 0],
            y: [0, 20, 0],
          }}
          transition={{
            duration: 8,
            repeat: Infinity,
            ease: 'easeInOut',
          }}
        />

        <motion.div
          className="absolute top-1/3 -right-32 h-96 w-96 rounded-full bg-emerald-200/30 blur-3xl"
          animate={{
            scale: [1, 1.2, 1],
            x: [0, -25, 0],
            y: [0, 30, 0],
          }}
          transition={{
            duration: 10,
            repeat: Infinity,
            ease: 'easeInOut',
          }}
        />

        {/* Floating leaves */}
        {floatingLeaves.map((leaf, index) => (
          <motion.div
            key={index}
            className="absolute text-green-300/40"
            style={{
              left: leaf.left,
              top: leaf.top,
            }}
            animate={{
              y: [0, -22, 0, 18, 0],
              x: [0, 12, -8, 10, 0],
              rotate: [0, 12, -10, 8, 0],
              opacity: [0.25, 0.55, 0.3, 0.5, 0.25],
            }}
            transition={{
              duration: 6 + index,
              delay: leaf.delay,
              repeat: Infinity,
              ease: 'easeInOut',
            }}
          >
            <Leaf size={leaf.size} strokeWidth={1.5} />
          </motion.div>
        ))}

        {/* Animated botanical stems */}
        <motion.div
          className="absolute bottom-0 left-0 text-green-200/40"
          animate={{
            rotate: [-2, 2, -2],
          }}
          transition={{
            duration: 5,
            repeat: Infinity,
            ease: 'easeInOut',
          }}
        >
          <svg width="220" height="300" viewBox="0 0 220 300">
            <path
              d="M30 300 C45 240 65 190 95 135 C120 90 150 55 185 20"
              fill="none"
              stroke="currentColor"
              strokeWidth="5"
              strokeLinecap="round"
            />
            <ellipse
              cx="72"
              cy="190"
              rx="42"
              ry="18"
              transform="rotate(-35 72 190)"
              fill="currentColor"
            />
            <ellipse
              cx="105"
              cy="132"
              rx="45"
              ry="18"
              transform="rotate(35 105 132)"
              fill="currentColor"
            />
            <ellipse
              cx="143"
              cy="82"
              rx="40"
              ry="17"
              transform="rotate(-35 143 82)"
              fill="currentColor"
            />
            <ellipse
              cx="177"
              cy="38"
              rx="35"
              ry="15"
              transform="rotate(30 177 38)"
              fill="currentColor"
            />
          </svg>
        </motion.div>

        <motion.div
          className="absolute bottom-0 right-0 text-emerald-200/40"
          animate={{
            rotate: [2, -2, 2],
          }}
          transition={{
            duration: 6,
            repeat: Infinity,
            ease: 'easeInOut',
          }}
        >
          <svg width="220" height="300" viewBox="0 0 220 300">
            <path
              d="M190 300 C175 240 155 190 125 135 C100 90 70 55 35 20"
              fill="none"
              stroke="currentColor"
              strokeWidth="5"
              strokeLinecap="round"
            />
            <ellipse
              cx="148"
              cy="190"
              rx="42"
              ry="18"
              transform="rotate(35 148 190)"
              fill="currentColor"
            />
            <ellipse
              cx="115"
              cy="132"
              rx="45"
              ry="18"
              transform="rotate(-35 115 132)"
              fill="currentColor"
            />
            <ellipse
              cx="77"
              cy="82"
              rx="40"
              ry="17"
              transform="rotate(35 77 82)"
              fill="currentColor"
            />
            <ellipse
              cx="43"
              cy="38"
              rx="35"
              ry="15"
              transform="rotate(-30 43 38)"
              fill="currentColor"
            />
          </svg>
        </motion.div>
      </div>

      {/* =========================================================
          MAIN CONTENT
      ========================================================= */}
      <main className="relative z-10 container mx-auto max-w-6xl px-4 py-10 md:py-14">

        {/* HERO */}
        <motion.section
          initial={{ opacity: 0, y: 35 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.7 }}
          className="relative mb-10 overflow-hidden rounded-[2rem] border border-green-100 bg-white/80 p-7 shadow-xl backdrop-blur-md md:p-12"
        >
          {/* Decorative leaves */}
          <motion.div
            className="absolute -right-8 -top-8 text-green-100"
            animate={{
              rotate: [0, 8, -5, 0],
              scale: [1, 1.08, 1],
            }}
            transition={{
              duration: 7,
              repeat: Infinity,
            }}
          >
            <Leaf size={170} strokeWidth={1} />
          </motion.div>

          <div className="relative grid items-center gap-10 md:grid-cols-[1.4fr_0.6fr]">
            <div>
              <motion.div
                initial={{ opacity: 0, x: -20 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ delay: 0.2 }}
                className="mb-4 inline-flex items-center gap-2 rounded-full bg-green-100 px-4 py-2 text-sm font-semibold text-green-700"
              >
                <Sparkles size={17} />
                AI Powered Agriculture
              </motion.div>

              <h1 className="mb-5 text-4xl font-black tracking-tight text-gray-900 md:text-6xl">
                Meet{' '}
                <span className="bg-gradient-to-r from-green-600 to-emerald-500 bg-clip-text text-transparent">
                  Krishi Rakshak
                </span>{' '}
                🌾
              </h1>

              <p className="max-w-2xl text-lg leading-8 text-gray-600 md:text-xl">
                Your intelligent farming companion for crop disease detection,
                treatment guidance and smarter agricultural decisions.
              </p>

              <div className="mt-7 flex flex-wrap gap-3">
                <div className="flex items-center gap-2 rounded-full bg-green-50 px-4 py-2 text-sm font-semibold text-green-700">
                  <CheckCircle size={18} />
                  95.14% Validation Accuracy
                </div>

                <div className="flex items-center gap-2 rounded-full bg-emerald-50 px-4 py-2 text-sm font-semibold text-emerald-700">
                  <ShieldCheck size={18} />
                  38 Crop Classes
                </div>
              </div>
            </div>

            {/* Animated plant */}
            <div className="relative flex justify-center">
              <motion.div
                animate={{
                  y: [0, -10, 0],
                  rotate: [-2, 2, -2],
                }}
                transition={{
                  duration: 5,
                  repeat: Infinity,
                  ease: 'easeInOut',
                }}
                className="relative flex h-52 w-52 items-center justify-center rounded-full bg-gradient-to-br from-green-100 to-emerald-100 shadow-inner"
              >
                <div className="absolute inset-5 rounded-full border border-green-200" />

                <motion.div
                  animate={{
                    rotate: [-3, 3, -3],
                  }}
                  transition={{
                    duration: 4,
                    repeat: Infinity,
                    ease: 'easeInOut',
                  }}
                >
                  <Sprout
                    size={105}
                    strokeWidth={1.5}
                    className="text-green-600"
                  />
                </motion.div>

                <motion.div
                  className="absolute -right-2 top-5"
                  animate={{
                    y: [0, -7, 0],
                    rotate: [0, 12, 0],
                  }}
                  transition={{
                    duration: 3,
                    repeat: Infinity,
                  }}
                >
                  <Sparkles className="text-yellow-400" size={28} />
                </motion.div>
              </motion.div>
            </div>
          </div>
        </motion.section>

        {/* ABOUT */}
        <motion.section
          initial={{ opacity: 0, y: 25 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          className="mb-10 rounded-3xl border border-green-100 bg-white/85 p-7 shadow-lg backdrop-blur-md md:p-10"
        >
          <div className="mb-5 flex items-center gap-3">
            <div className="rounded-2xl bg-green-100 p-3">
              <Leaf className="text-green-600" size={28} />
            </div>

            <div>
              <p className="text-sm font-semibold uppercase tracking-wider text-green-600">
                About the platform
              </p>
              <h2 className="text-2xl font-bold text-gray-900 md:text-3xl">
                {t('aboutApp')}
              </h2>
            </div>
          </div>

          <p className="max-w-4xl text-base leading-8 text-gray-600 md:text-lg">
            {t('aboutText')}
          </p>
        </motion.section>

        {/* STATS */}
        <section className="mb-10 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {[
            ['95.14%', 'Validation Accuracy'],
            ['38', 'Disease Classes'],
            ['224×224', 'Image Input'],
            ['AI', 'Smart Analysis'],
          ].map(([value, label], index) => (
            <motion.div
              key={label}
              initial={{ opacity: 0, y: 25 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ delay: index * 0.08 }}
              whileHover={{ y: -6 }}
              className="rounded-2xl border border-green-100 bg-white/90 p-6 text-center shadow-md transition-shadow hover:shadow-xl"
            >
              <div className="text-3xl font-black text-green-600">
                {value}
              </div>
              <div className="mt-1 text-sm font-medium text-gray-500">
                {label}
              </div>
            </motion.div>
          ))}
        </section>

        {/* HOW IT WORKS */}
        <motion.section
          initial={{ opacity: 0, y: 25 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          className="mb-10 rounded-3xl border border-green-100 bg-white/85 p-7 shadow-lg backdrop-blur-md md:p-10"
        >
          <div className="mb-8">
            <p className="text-sm font-semibold uppercase tracking-wider text-green-600">
              Simple process
            </p>

            <h2 className="mt-1 text-3xl font-bold text-gray-900">
              {t('howItWorks')}
            </h2>
          </div>

          <div className="grid gap-5 md:grid-cols-4">
            {[
              {
                number: '01',
                icon: Camera,
                title: 'Capture',
                text: 'Take or upload a clear crop leaf image.',
              },
              {
                number: '02',
                icon: BrainCircuit,
                title: 'Analyze',
                text: 'AI analyzes the image using the trained model.',
              },
              {
                number: '03',
                icon: CheckCircle,
                title: 'Detect',
                text: 'Receive the most likely disease prediction.',
              },
              {
                number: '04',
                icon: ShieldCheck,
                title: 'Protect',
                text: 'Use treatment and prevention guidance.',
              },
            ].map((step, index) => {
              const Icon = step.icon;

              return (
                <motion.div
                  key={step.number}
                  initial={{ opacity: 0, y: 20 }}
                  whileInView={{ opacity: 1, y: 0 }}
                  viewport={{ once: true }}
                  transition={{ delay: index * 0.12 }}
                  whileHover={{ scale: 1.03 }}
                  className="relative rounded-2xl bg-green-50 p-6"
                >
                  <span className="absolute right-4 top-3 text-4xl font-black text-green-100">
                    {step.number}
                  </span>

                  <div className="mb-4 flex h-12 w-12 items-center justify-center rounded-xl bg-white shadow-sm">
                    <Icon className="text-green-600" size={25} />
                  </div>

                  <h3 className="mb-2 text-lg font-bold text-gray-900">
                    {step.title}
                  </h3>

                  <p className="text-sm leading-6 text-gray-600">
                    {step.text}
                  </p>
                </motion.div>
              );
            })}
          </div>
        </motion.section>

        {/* FEATURES */}
        <section className="mb-10">
          <div className="mb-7 text-center">
            <p className="text-sm font-semibold uppercase tracking-wider text-green-600">
              What you get
            </p>

            <h2 className="mt-1 text-3xl font-bold text-gray-900 md:text-4xl">
              Smart Features for Farmers
            </h2>
          </div>

          <div className="grid gap-5 md:grid-cols-2 lg:grid-cols-3">
            {features.map((feature, index) => {
              const Icon = feature.icon;

              return (
                <motion.div
                  key={feature.title}
                  initial={{ opacity: 0, y: 25 }}
                  whileInView={{ opacity: 1, y: 0 }}
                  viewport={{ once: true }}
                  transition={{ delay: index * 0.08 }}
                  whileHover={{ y: -7 }}
                  className="group rounded-3xl border border-green-100 bg-white/90 p-6 shadow-md transition-all hover:shadow-xl"
                >
                  <div className="mb-5 flex h-14 w-14 items-center justify-center rounded-2xl bg-gradient-to-br from-green-100 to-emerald-100 transition-transform group-hover:scale-110">
                    <Icon className="text-green-600" size={28} />
                  </div>

                  <h3 className="mb-2 text-xl font-bold text-gray-900">
                    {feature.title}
                  </h3>

                  <p className="text-sm leading-7 text-gray-600">
                    {feature.description}
                  </p>
                </motion.div>
              );
            })}
          </div>
        </section>

        {/* DISCLAIMER */}
        <motion.section
          initial={{ opacity: 0, y: 25 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          className="mb-10 rounded-3xl border border-orange-200 bg-orange-50/90 p-7 shadow-md md:p-9"
        >
          <div className="flex items-start gap-4">
            <div className="rounded-2xl bg-orange-100 p-3">
              <AlertTriangle className="text-orange-600" size={28} />
            </div>

            <div>
              <h2 className="mb-2 text-2xl font-bold text-orange-800">
                {t('disclaimer')}
              </h2>

              <p className="leading-7 text-gray-700">
                {t('disclaimerText')}
              </p>
            </div>
          </div>
        </motion.section>

        {/* FINAL CTA */}
        <motion.section
          initial={{ opacity: 0, scale: 0.97 }}
          whileInView={{ opacity: 1, scale: 1 }}
          viewport={{ once: true }}
          className="relative overflow-hidden rounded-[2rem] bg-gradient-to-r from-green-600 via-emerald-600 to-green-700 p-8 text-white shadow-2xl md:p-12"
        >
          <motion.div
            className="absolute -right-16 -top-16 opacity-10"
            animate={{
              rotate: [0, 15, -10, 0],
            }}
            transition={{
              duration: 8,
              repeat: Infinity,
            }}
          >
            <Leaf size={220} />
          </motion.div>

          <div className="relative">
            <div className="mb-3 flex items-center gap-2">
              <ShieldCheck size={24} />
              <span className="font-semibold">Krishi Rakshak</span>
            </div>

            <h2 className="max-w-2xl text-3xl font-black md:text-4xl">
              Protect your crops with intelligent AI.
            </h2>

            <p className="mt-3 max-w-2xl text-green-50">
              Detect crop problems early and make smarter farming decisions.
            </p>

            <div className="mt-7 inline-flex items-center gap-2 rounded-full bg-white px-5 py-3 font-bold text-green-700 shadow-lg">
              Smart Farming Starts Here
              <ArrowRight size={20} />
            </div>
          </div>
        </motion.section>

        {/* FOOTER */}
        <div className="py-10 text-center text-gray-500">
          <motion.div
            animate={{
              y: [0, -4, 0],
            }}
            transition={{
              duration: 3,
              repeat: Infinity,
            }}
            className="mb-3 flex justify-center"
          >
            <Sprout className="text-green-500" size={30} />
          </motion.div>

          <p className="font-semibold text-gray-700">
            Made with ❤️ for Farmers
          </p>

          <p className="mt-1 text-sm">
            Krishi Rakshak • AI-Powered Crop Protection
          </p>
        </div>
      </main>
    </div>
  );
};

export default About;