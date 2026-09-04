import { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import {
  Cloud,
  Droplets,
  Wind,
  Sun,
  TrendingUp,
  Calendar,
  Leaf,
  MapPin,
  Loader,
  Eye,
  Gauge,
  RefreshCw,
  ShieldCheck,
  Activity,
  AlertTriangle,
  CheckCircle2,
  Sparkles,
} from 'lucide-react';

import { useLanguage } from '../context/LanguageContext';

import {
  getCurrentWeather,
  getUserLocation,
} from '../services/weatherService';

import type { WeatherData } from '../services/weatherService';

import Navbar from '../components/Navbar';

const Dashboard = () => {
  const { t } = useLanguage();

  const [weather, setWeather] =
    useState<WeatherData | null>(null);

  const [loading, setLoading] =
    useState(true);

  const [lastUpdated, setLastUpdated] =
    useState<Date>(new Date());

  const [cropStats, setCropStats] = useState({
    totalScans: 0,
    healthyCount: 0,
    needsAttention: 0,
  });

  /* =========================================================
     RECENT SCANS
     ========================================================= */

  const recentScans = [
    {
      id: 1,
      crop: 'Tomato',
      disease: 'Leaf Blight',
      date: '2 days ago',
      confidence: 87,
      isHealthy: false,
    },
    {
      id: 2,
      crop: 'Rice',
      disease: 'Healthy Leaf',
      date: '5 days ago',
      confidence: 95,
      isHealthy: true,
    },
    {
      id: 3,
      crop: 'Cotton',
      disease: 'Bacterial Spot',
      date: '1 week ago',
      confidence: 79,
      isHealthy: false,
    },
    {
      id: 4,
      crop: 'Wheat',
      disease: 'Healthy Leaf',
      date: '3 days ago',
      confidence: 92,
      isHealthy: true,
    },
    {
      id: 5,
      crop: 'Corn',
      disease: 'Healthy Leaf',
      date: '1 day ago',
      confidence: 88,
      isHealthy: true,
    },
  ];

  /* =========================================================
     CROP STATS
     ========================================================= */

  useEffect(() => {
    const total = recentScans.length;

    const healthy =
      recentScans.filter(
        (scan) => scan.isHealthy
      ).length;

    setCropStats({
      totalScans: total,
      healthyCount: healthy,
      needsAttention: total - healthy,
    });
  }, []);

  /* =========================================================
     WEATHER
     ========================================================= */

  const fetchWeather = async () => {
    try {
      setLoading(true);

      const coords =
        await getUserLocation();

      const weatherData =
        await getCurrentWeather(coords);

      setWeather(weatherData);

      setLastUpdated(new Date());

      setLoading(false);

    } catch (error) {
      console.error(
        'Failed to fetch weather:',
        error
      );

      setLoading(false);
    }
  };

  useEffect(() => {
    fetchWeather();
  }, []);

  useEffect(() => {
    const interval = setInterval(() => {
      fetchWeather();
    }, 90000);

    return () =>
      clearInterval(interval);
  }, []);

  /* =========================================================
     WEATHER ADVICE
     ========================================================= */

  const weatherAdvice = weather
    ? [
        weather.humidity > 70
          ? 'High humidity detected. Monitor crops for fungal diseases.'
          : 'Humidity conditions are suitable for crop growth.',

        weather.temp > 35
          ? 'High temperature detected. Increase irrigation carefully.'
          : weather.temp < 15
          ? 'Low temperature detected. Protect sensitive crops.'
          : 'Temperature conditions are suitable for crop growth.',

        weather.windSpeed > 25
          ? 'Strong winds detected. Protect young plants.'
          : 'Wind conditions are currently stable.',
      ]
    : [];

  /* =========================================================
     PERCENTAGES
     ========================================================= */

  const healthyPercentage =
    cropStats.totalScans > 0
      ? Math.round(
          (cropStats.healthyCount /
            cropStats.totalScans) *
            100
        )
      : 0;

  const attentionPercentage =
    cropStats.totalScans > 0
      ? Math.round(
          (cropStats.needsAttention /
            cropStats.totalScans) *
            100
        )
      : 0;

  /* =========================================================
     RECOMMENDATIONS
     ========================================================= */

  const recommendations = [
    {
      title: 'Weather Advisory',
      message:
        weatherAdvice[0] ||
        'Checking weather conditions...',
      icon: Cloud,
      iconBg: 'bg-blue-100',
      iconColor: 'text-blue-600',
      border: 'border-blue-200',
    },

    {
      title: 'Irrigation Alert',
      message:
        weather &&
        weather.humidity > 70
          ? `High humidity (${weather.humidity}%). Reduce watering frequency.`
          : weather
          ? `Humidity at ${weather.humidity}%. Soil moisture conditions look good.`
          : 'Checking irrigation requirements...',
      icon: Droplets,
      iconBg: 'bg-cyan-100',
      iconColor: 'text-cyan-600',
      border: 'border-cyan-200',
    },

    {
      title: 'Temperature Status',
      message:
        weather && weather.temp > 35
          ? `Very hot (${weather.temp}°C). Ensure extra irrigation.`
          : weather && weather.temp < 15
          ? `Cold weather (${weather.temp}°C). Protect sensitive crops.`
          : weather
          ? `Optimal temperature (${weather.temp}°C) for crop growth.`
          : 'Checking temperature...',
      icon: Leaf,
      iconBg: 'bg-green-100',
      iconColor: 'text-green-600',
      border: 'border-green-200',
    },
  ];

  return (
    <div className="dashboard-page min-h-screen">

      <Navbar />

      {/* =====================================================
          GARDEN BACKGROUND
          ===================================================== */}
      <div className="garden-background" aria-hidden="true">
        <div className="garden-sun" />

        <div className="garden-hill garden-hill-back" />
        <div className="garden-hill garden-hill-front" />

        <div className="garden-tree tree-left">
          <div className="tree-trunk" />
          <div className="tree-crown crown-one" />
          <div className="tree-crown crown-two" />
          <div className="tree-crown crown-three" />
        </div>

        <div className="garden-tree tree-right">
          <div className="tree-trunk" />
          <div className="tree-crown crown-one" />
          <div className="tree-crown crown-two" />
          <div className="tree-crown crown-three" />
        </div>

        <div className="garden-bush bush-one" />
        <div className="garden-bush bush-two" />
        <div className="garden-bush bush-three" />
        <div className="garden-bush bush-four" />

        <div className="garden-ground">
          <div className="garden-path" />

          <div className="flower-group flowers-left">
            <span className="flower flower-yellow" />
            <span className="flower flower-white" />
            <span className="flower flower-pink" />
            <span className="flower flower-yellow" />
          </div>

          <div className="flower-group flowers-right">
            <span className="flower flower-white" />
            <span className="flower flower-yellow" />
            <span className="flower flower-pink" />
            <span className="flower flower-white" />
          </div>

          <div className="grass grass-one" />
          <div className="grass grass-two" />
          <div className="grass grass-three" />
          <div className="grass grass-four" />
        </div>

        <span className="garden-particle particle-one" />
        <span className="garden-particle particle-two" />
        <span className="garden-particle particle-three" />
        <span className="garden-particle particle-four" />
        <span className="garden-particle particle-five" />
      </div>

      {/* =====================================================
          MAIN CONTENT
          ===================================================== */}

      <main className="dashboard-content container mx-auto max-w-7xl px-4 py-8">

        {/* HERO */}

        <motion.section
          initial={{
            opacity: 0,
            y: 20,
          }}
          animate={{
            opacity: 1,
            y: 0,
          }}
          transition={{
            duration: 0.5,
          }}
          className="relative overflow-hidden rounded-3xl bg-gradient-to-r from-green-800 via-emerald-700 to-green-600 p-6 md:p-8 text-white shadow-xl mb-8"
        >

          <div className="absolute -right-16 -top-16 h-48 w-48 rounded-full bg-white/10 animate-pulse" />

          <div className="absolute -bottom-20 right-20 h-56 w-56 rounded-full bg-white/5" />

          <div className="relative flex flex-col md:flex-row md:items-center md:justify-between gap-6">

            <div>

              <div className="flex items-center gap-2 mb-3">

                <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-white/15 backdrop-blur">
                  <ShieldCheck size={24} />
                </div>

                <span className="text-sm font-semibold tracking-wide text-green-100">
                  KRISHI RAKSHAK
                </span>

              </div>

              <h1 className="text-3xl md:text-4xl font-extrabold mb-2">
                Smart Farming Dashboard
              </h1>

              <p className="max-w-2xl text-green-50">
                Monitor your crops, weather conditions
                and AI-powered farming recommendations
                from one place.
              </p>

            </div>

            <motion.div
              whileHover={{
                scale: 1.03,
              }}
              className="flex items-center gap-3 rounded-2xl bg-white/10 backdrop-blur-md px-5 py-4 border border-white/20"
            >

              <div className="flex h-12 w-12 items-center justify-center rounded-full bg-white text-green-700">
                <Sparkles size={24} />
              </div>

              <div>

                <p className="text-xs text-green-100">
                  AI MODEL ACCURACY
                </p>

                <p className="text-2xl font-extrabold">
                  95.14%
                </p>

              </div>

            </motion.div>

          </div>

        </motion.section>


        {/* =====================================================
            STAT CARDS
            ===================================================== */}

        <section className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5 mb-8">

          <motion.div
            whileHover={{
              y: -6,
              scale: 1.01,
            }}
            className="dashboard-card"
          >

            <div className="flex items-center justify-between mb-4">

              <div className="h-11 w-11 rounded-xl bg-green-100 flex items-center justify-center">
                <Activity
                  className="text-green-600"
                  size={23}
                />
              </div>

              <span className="text-xs font-semibold text-green-600 bg-green-50 px-2 py-1 rounded-full">
                LIVE
              </span>

            </div>

            <p className="text-gray-500 text-sm">
              Total Scans
            </p>

            <p className="text-3xl font-extrabold text-gray-900 mt-1">
              {cropStats.totalScans}
            </p>

          </motion.div>


          <motion.div
            whileHover={{
              y: -6,
              scale: 1.01,
            }}
            className="dashboard-card"
          >

            <div className="h-11 w-11 rounded-xl bg-emerald-100 flex items-center justify-center mb-4">
              <CheckCircle2
                className="text-emerald-600"
                size={23}
              />
            </div>

            <p className="text-gray-500 text-sm">
              Healthy Crops
            </p>

            <div className="flex items-end gap-2">

              <p className="text-3xl font-extrabold text-gray-900 mt-1">
                {cropStats.healthyCount}
              </p>

              <span className="text-sm font-semibold text-emerald-600 mb-1">
                {healthyPercentage}%
              </span>

            </div>

          </motion.div>


          <motion.div
            whileHover={{
              y: -6,
              scale: 1.01,
            }}
            className="dashboard-card"
          >

            <div className="h-11 w-11 rounded-xl bg-orange-100 flex items-center justify-center mb-4">
              <AlertTriangle
                className="text-orange-600"
                size={23}
              />
            </div>

            <p className="text-gray-500 text-sm">
              Needs Attention
            </p>

            <div className="flex items-end gap-2">

              <p className="text-3xl font-extrabold text-gray-900 mt-1">
                {cropStats.needsAttention}
              </p>

              <span className="text-sm font-semibold text-orange-600 mb-1">
                {attentionPercentage}%
              </span>

            </div>

          </motion.div>


          <motion.div
            whileHover={{
              y: -6,
              scale: 1.01,
            }}
            className="dashboard-card"
          >

            <div className="h-11 w-11 rounded-xl bg-purple-100 flex items-center justify-center mb-4">
              <ShieldCheck
                className="text-purple-600"
                size={23}
              />
            </div>

            <p className="text-gray-500 text-sm">
              AI Accuracy
            </p>

            <p className="text-3xl font-extrabold text-gray-900 mt-1">
              95.14%
            </p>

          </motion.div>

        </section>


        {/* =====================================================
            WEATHER + AI MODEL
            ===================================================== */}

        <section className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-8">

          {/* WEATHER */}

          <div className="lg:col-span-2 overflow-hidden rounded-3xl bg-gradient-to-br from-blue-600 to-indigo-700 text-white shadow-xl">

            <div className="p-6 md:p-7">

              <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 mb-6">

                <div>

                  <div className="flex items-center gap-2">

                    <Cloud size={25} />

                    <h2 className="text-xl font-bold">
                      {t('weather')}
                    </h2>

                    <span className="rounded-full bg-white/15 px-2 py-1 text-[10px] font-bold">
                      LIVE
                    </span>

                  </div>

                  {weather && (
                    <div className="flex items-center gap-1 mt-2 text-sm text-blue-100">

                      <MapPin size={14} />

                      {weather.location},{' '}
                      {weather.country}

                    </div>
                  )}

                </div>

                <button
                  onClick={fetchWeather}
                  disabled={loading}
                  className="flex items-center justify-center gap-2 rounded-xl bg-white/15 hover:bg-white/25 border border-white/20 px-4 py-2 text-sm font-semibold transition-all disabled:opacity-50"
                >

                  <RefreshCw
                    size={16}
                    className={
                      loading
                        ? 'animate-spin'
                        : ''
                    }
                  />

                  Refresh

                </button>

              </div>


              {loading && !weather ? (

                <div className="text-center py-12">

                  <Loader
                    className="animate-spin mx-auto mb-3"
                    size={42}
                  />

                  <p className="text-blue-100">
                    Loading weather data...
                  </p>

                </div>

              ) : weather ? (

                <>

                  <div className="grid grid-cols-2 md:grid-cols-4 gap-4">

                    <div className="weather-box">

                      <Sun
                        className="mx-auto mb-2"
                        size={30}
                      />

                      <p className="text-3xl font-extrabold">
                        {weather.temp}°C
                      </p>

                      <p className="text-sm text-blue-100 capitalize">
                        {weather.description}
                      </p>

                      <p className="text-xs text-blue-200 mt-1">
                        Feels {weather.feelsLike}°C
                      </p>

                    </div>


                    <div className="weather-box">

                      <Droplets
                        className="mx-auto mb-2"
                        size={30}
                      />

                      <p className="text-2xl font-extrabold">
                        {weather.humidity}%
                      </p>

                      <p className="text-sm text-blue-100">
                        Humidity
                      </p>

                    </div>


                    <div className="weather-box">

                      <Wind
                        className="mx-auto mb-2"
                        size={30}
                      />

                      <p className="text-2xl font-extrabold">
                        {weather.windSpeed}
                      </p>

                      <p className="text-sm text-blue-100">
                        km/h Wind
                      </p>

                    </div>


                    <div className="weather-box">

                      <Cloud
                        className="mx-auto mb-2"
                        size={30}
                      />

                      <p className="text-2xl font-extrabold">
                        {weather.clouds}%
                      </p>

                      <p className="text-sm text-blue-100">
                        Clouds
                      </p>

                    </div>

                  </div>


                  <div className="grid grid-cols-3 gap-3 mt-4">

                    <div className="weather-small-box">

                      <Eye
                        size={18}
                        className="mx-auto mb-1"
                      />

                      <p className="text-sm font-semibold">
                        {weather.visibility} km
                      </p>

                      <p className="text-xs text-blue-200">
                        Visibility
                      </p>

                    </div>


                    <div className="weather-small-box">

                      <Gauge
                        size={18}
                        className="mx-auto mb-1"
                      />

                      <p className="text-sm font-semibold">
                        {weather.pressure} hPa
                      </p>

                      <p className="text-xs text-blue-200">
                        Pressure
                      </p>

                    </div>


                    <div className="weather-small-box">

                      <Droplets
                        size={18}
                        className="mx-auto mb-1"
                      />

                      <p className="text-sm font-semibold">
                        {weather.rainfall} mm
                      </p>

                      <p className="text-xs text-blue-200">
                        Rain
                      </p>

                    </div>

                  </div>


                  <div className="mt-4 text-xs text-blue-200 text-right">
                    Updated{' '}
                    {lastUpdated.toLocaleTimeString()}
                  </div>

                </>

              ) : (

                <div className="text-center py-12">

                  <p>
                    Unable to load weather data
                  </p>

                  <button
                    onClick={fetchWeather}
                    className="mt-4 rounded-xl bg-white px-5 py-2 text-blue-700 font-semibold hover:bg-blue-50"
                  >
                    Retry
                  </button>

                </div>

              )}

            </div>

          </div>


          {/* AI MODEL */}

          <motion.div
            whileHover={{
              y: -4,
            }}
            className="dashboard-card p-7"
          >

            <div className="flex items-center justify-between mb-6">

              <div className="h-12 w-12 rounded-2xl bg-green-100 flex items-center justify-center">

                <ShieldCheck
                  className="text-green-600"
                  size={27}
                />

              </div>

              <span className="rounded-full bg-green-50 text-green-700 px-3 py-1 text-xs font-bold">
                READY
              </span>

            </div>

            <h2 className="text-xl font-bold text-gray-900">
              Krishi Rakshak AI
            </h2>

            <p className="text-sm text-gray-500 mt-1">
              Crop disease detection model
            </p>


            <div className="mt-7 text-center rounded-2xl bg-gradient-to-br from-green-50 to-emerald-50 p-6">

              <p className="text-sm text-gray-500">
                Validation Accuracy
              </p>

              <p className="text-5xl font-extrabold text-green-600 mt-2">
                95.14%
              </p>

              <div className="mt-4 h-2 rounded-full bg-green-100 overflow-hidden">

                <motion.div
                  initial={{
                    width: 0,
                  }}
                  animate={{
                    width: '95.14%',
                  }}
                  transition={{
                    duration: 1.2,
                    ease: 'easeOut',
                  }}
                  className="h-full rounded-full bg-green-500"
                />

              </div>

            </div>


            <div className="grid grid-cols-2 gap-3 mt-4">

              <div className="rounded-xl bg-gray-50 p-4 text-center">

                <p className="text-2xl font-bold text-gray-900">
                  38
                </p>

                <p className="text-xs text-gray-500">
                  Disease Classes
                </p>

              </div>


              <div className="rounded-xl bg-gray-50 p-4 text-center">

                <p className="text-2xl font-bold text-gray-900">
                  224
                </p>

                <p className="text-xs text-gray-500">
                  Image Size
                </p>

              </div>

            </div>


            <div className="mt-5 flex items-center gap-2 text-sm text-green-700">

              <CheckCircle2 size={17} />

              Model is ready for prediction

            </div>

          </motion.div>

        </section>


        {/* =====================================================
            AI RECOMMENDATIONS
            ===================================================== */}

        <section className="mb-8">

          <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2 mb-5">

            <div>

              <div className="flex items-center gap-2">

                <Sparkles
                  className="text-green-600"
                  size={23}
                />

                <h2 className="text-2xl font-bold text-gray-900">
                  {t('recommendations')}
                </h2>

              </div>

              <p className="text-sm text-gray-500 mt-1">
                Smart recommendations based on
                current conditions
              </p>

            </div>

            {weather && (

              <span className="flex items-center gap-2 text-xs font-semibold text-green-700 bg-green-50 px-3 py-2 rounded-full">

                <span className="h-2 w-2 rounded-full bg-green-500 animate-pulse" />

                Auto-updating

              </span>

            )}

          </div>


          <div className="grid grid-cols-1 md:grid-cols-3 gap-5">

            {recommendations.map(
              (rec, index) => {

                const Icon = rec.icon;

                return (
                  <motion.div
                    key={index}
                    initial={{
                      opacity: 0,
                      y: 20,
                    }}
                    animate={{
                      opacity: 1,
                      y: 0,
                    }}
                    transition={{
                      delay:
                        index * 0.1,
                    }}
                    whileHover={{
                      y: -6,
                      scale: 1.01,
                    }}
                    className={`rounded-2xl bg-white/85 backdrop-blur-md border ${rec.border} shadow-md hover:shadow-xl p-5 transition-all duration-300`}
                  >

                    <div className="flex items-start gap-4">

                      <div
                        className={`h-12 w-12 shrink-0 rounded-xl ${rec.iconBg} flex items-center justify-center`}
                      >

                        <Icon
                          className={
                            rec.iconColor
                          }
                          size={24}
                        />

                      </div>

                      <div>

                        <h3 className="font-bold text-gray-900">
                          {rec.title}
                        </h3>

                        <p className="text-sm text-gray-600 mt-2 leading-relaxed">
                          {rec.message}
                        </p>

                      </div>

                    </div>

                  </motion.div>
                );
              }
            )}

          </div>

        </section>


        {/* =====================================================
            RECENT SCANS
            ===================================================== */}

        <section>

          <div className="flex items-center justify-between mb-5">

            <div>

              <div className="flex items-center gap-2">

                <Calendar
                  className="text-green-600"
                  size={23}
                />

                <h2 className="text-2xl font-bold text-gray-900">
                  {t('cropHistory')}
                </h2>

              </div>

              <p className="text-sm text-gray-500 mt-1">
                Recent crop health analysis
              </p>

            </div>

            <span className="hidden sm:flex items-center gap-1 text-xs text-gray-500">

              <TrendingUp size={15} />

              Recent Activity

            </span>

          </div>


          <div className="rounded-3xl bg-white/85 backdrop-blur-md border border-gray-100 shadow-lg overflow-hidden">

            <div className="divide-y divide-gray-100">

              {recentScans.map(
                (scan, index) => (

                  <motion.div
                    key={scan.id}
                    initial={{
                      opacity: 0,
                      x: -15,
                    }}
                    animate={{
                      opacity: 1,
                      x: 0,
                    }}
                    transition={{
                      delay:
                        index * 0.08,
                    }}
                    whileHover={{
                      x: 4,
                    }}
                    className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 p-5 hover:bg-green-50/50 transition-all"
                  >

                    <div className="flex items-center gap-4">

                      <div
                        className={`h-12 w-12 rounded-2xl flex items-center justify-center ${
                          scan.isHealthy
                            ? 'bg-green-100'
                            : 'bg-orange-100'
                        }`}
                      >

                        {scan.isHealthy ? (

                          <CheckCircle2
                            className="text-green-600"
                            size={24}
                          />

                        ) : (

                          <AlertTriangle
                            className="text-orange-600"
                            size={24}
                          />

                        )}

                      </div>


                      <div>

                        <p className="font-bold text-gray-900">
                          {scan.crop}
                        </p>

                        <p className="text-sm text-gray-500">
                          {scan.disease}
                        </p>

                        <p className="text-xs text-gray-400 mt-1">
                          {scan.date}
                        </p>

                      </div>

                    </div>


                    <div className="sm:text-right">

                      <div
                        className={`inline-flex items-center gap-1 px-3 py-1 rounded-full text-xs font-bold ${
                          scan.isHealthy
                            ? 'bg-green-100 text-green-700'
                            : 'bg-orange-100 text-orange-700'
                        }`}
                      >

                        {scan.isHealthy ? (

                          <CheckCircle2
                            size={13}
                          />

                        ) : (

                          <AlertTriangle
                            size={13}
                          />

                        )}

                        {scan.isHealthy
                          ? 'Healthy'
                          : 'Needs Attention'}

                      </div>

                      <p className="text-sm font-bold text-gray-700 mt-2">
                        {scan.confidence}%
                        confidence
                      </p>

                    </div>

                  </motion.div>

                )
              )}

            </div>

          </div>

        </section>


        {/* =====================================================
            FOOTER
            ===================================================== */}

        <div className="mt-8 flex flex-col sm:flex-row items-center justify-between gap-3 text-xs text-gray-500">

          <div className="flex items-center gap-2">

            <Leaf
              size={15}
              className="text-green-600"
            />

            <span>
              Krishi Rakshak • Smart Agriculture Assistant
            </span>

          </div>

          <span>
            AI-powered crop health monitoring
          </span>

        </div>

      </main>

    </div>
  );
};

export default Dashboard;