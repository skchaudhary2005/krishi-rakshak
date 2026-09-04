import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.tsx'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/sw.js")
      .then(() => {
        console.log("✅ Krishi Rakshak offline mode ready");
      })
      .catch((error) => {
        console.error(
          "❌ Offline mode registration failed:",
          error
        );
      });
  });
}