import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { LanguageProvider } from './context/LanguageContext';

import Splash from './pages/Splash';
import Home from './pages/Home';
import Dashboard from './pages/Dashboard';
import AIChat from './pages/AIChat';
import Result from './pages/Result';
import Experts from './pages/Experts';
import About from './pages/About';

import './App.css';


// ============================================================
// 🌿 ANIMATED KRISHI RAKSHAK FARM BACKGROUND
// ============================================================

const AnimatedBackground = () => {
  return (
    <div className="farm-background" aria-hidden="true">

      {/* Sun light */}
      <div className="sun-glow" />

      {/* Soft background glow */}
      <div className="farm-blur farm-blur-1" />
      <div className="farm-blur farm-blur-2" />


      {/* ======================================================
          LEFT LARGE PLANT
      ====================================================== */}

      <div className="plant plant-left">
        <div className="stem" />

        <div className="leaf leaf-1" />
        <div className="leaf leaf-2" />
        <div className="leaf leaf-3" />
        <div className="leaf leaf-4" />
        <div className="leaf leaf-5" />
        <div className="leaf leaf-6" />
        <div className="leaf leaf-7" />
      </div>


      {/* ======================================================
          LEFT FRONT PLANT
      ====================================================== */}

      <div className="plant plant-left-front">
        <div className="stem" />

        <div className="leaf leaf-1" />
        <div className="leaf leaf-2" />
        <div className="leaf leaf-3" />
        <div className="leaf leaf-4" />
        <div className="leaf leaf-5" />
      </div>


      {/* ======================================================
          RIGHT LARGE PLANT
      ====================================================== */}

      <div className="plant plant-right">
        <div className="stem" />

        <div className="leaf leaf-1" />
        <div className="leaf leaf-2" />
        <div className="leaf leaf-3" />
        <div className="leaf leaf-4" />
        <div className="leaf leaf-5" />
        <div className="leaf leaf-6" />
        <div className="leaf leaf-7" />
      </div>


      {/* ======================================================
          RIGHT FRONT PLANT
      ====================================================== */}

      <div className="plant plant-right-front">
        <div className="stem" />

        <div className="leaf leaf-1" />
        <div className="leaf leaf-2" />
        <div className="leaf leaf-3" />
        <div className="leaf leaf-4" />
        <div className="leaf leaf-5" />
        <div className="leaf leaf-6" />
      </div>


      {/* ======================================================
          SMALL BACKGROUND PLANT 1
      ====================================================== */}

      <div className="small-plant small-plant-1">
        <div className="small-stem" />

        <div className="small-leaf l1" />
        <div className="small-leaf l2" />
        <div className="small-leaf l3" />
      </div>


      {/* ======================================================
          SMALL BACKGROUND PLANT 2
      ====================================================== */}

      <div className="small-plant small-plant-2">
        <div className="small-stem" />

        <div className="small-leaf l1" />
        <div className="small-leaf l2" />
        <div className="small-leaf l3" />
      </div>

    </div>
  );
};


// ============================================================
// 🌾 MAIN APP
// ============================================================

function App() {
  return (
    <LanguageProvider>
      <Router>

        {/* 🌿 Background behind complete website */}
        <AnimatedBackground />

        {/* Website content */}
        <div className="app-content">

          <Routes>

            <Route
              path="/"
              element={<Splash />}
            />

            <Route
              path="/home"
              element={<Home />}
            />

            <Route
              path="/dashboard"
              element={<Dashboard />}
            />

            <Route
              path="/ai-chat"
              element={<AIChat />}
            />

            <Route
              path="/result"
              element={<Result />}
            />

            <Route
              path="/experts"
              element={<Experts />}
            />

            <Route
              path="/about"
              element={<About />}
            />

            {/* Unknown URL → Home */}
            <Route
              path="*"
              element={<Navigate to="/home" replace />}
            />

          </Routes>

        </div>

      </Router>
    </LanguageProvider>
  );
}

export default App;