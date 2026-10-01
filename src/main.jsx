import React, { useEffect, useMemo, useRef, useState } from 'react';
import { createRoot } from 'react-dom/client';
import {
  Activity, AlertTriangle, ArrowRight, Bot, CalendarDays, CheckCircle2,
  CloudRain, CloudSnow, CloudSun, Cpu, Droplets, ExternalLink, FileImage,
  History as HistoryIcon, Leaf, LocateFixed, Mail, MapPin, Menu,
  MessageCircle, RefreshCw, ScanLine, Search, Send, Settings2,
  ShieldCheck, Sparkles, Sun, Trash2, Upload, UserRound, UsersRound,
  Wind, X, Zap
} from 'lucide-react';
import './styles.css';

const API = 'https://krishi-rakshak-api.onrender.com';
const SPLINE_SCENE = 'https://prod.spline.design/3Bkv7n76s1c763hb/scene.splinecode';
const HISTORY_KEY = 'krishi_rakshak_web_history_v4';
const WEATHER_CACHE_TTL = 10 * 60 * 1000;
const weatherCache = new Map();

function normalizePlace(value) {
  return String(value || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().replace(/[^\p{L}\p{N}]+/gu, ' ').trim();
}

function locationLine(place) {
  return [place.admin2, place.admin1, place.country].filter((value, index, values) => value && values.indexOf(value) === index).join(', ');
}

function rankedPlaces(results, query) {
  const q = normalizePlace(query);
  return [...results].sort((a, b) => {
    const aName = normalizePlace(a.name), bName = normalizePlace(b.name);
    const aExact = aName === q ? 1 : 0, bExact = bName === q ? 1 : 0;
    const aContained = q.includes(aName) ? 1 : 0, bContained = q.includes(bName) ? 1 : 0;
    const contextScore = (place) => [place.admin1, place.admin2, place.country, place.country_code].filter(Boolean)
      .reduce((score, value) => score + (q.includes(normalizePlace(value)) ? 1 : 0), 0);
    return bExact - aExact || contextScore(b) - contextScore(a) || bContained - aContained || (Number(b.population) || 0) - (Number(a.population) || 0);
  });
}

function forecastUrl(latitude, longitude) {
  const params = new URLSearchParams({
    latitude: String(latitude), longitude: String(longitude),
    current: 'temperature_2m,apparent_temperature,relative_humidity_2m,precipitation,rain,weather_code,cloud_cover,wind_speed_10m,wind_direction_10m',
    daily: 'weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,precipitation_sum,wind_speed_10m_max,sunrise,sunset',
    forecast_days: '7', timezone: 'auto', temperature_unit: 'celsius', wind_speed_unit: 'kmh', precipitation_unit: 'mm'
  });
  return `https://api.open-meteo.com/v1/forecast?${params}`;
}

async function readApiJson(url, failureMessage) {
  const response = await fetch(url);
  let data;
  try { data = await response.json(); } catch { throw new Error(failureMessage); }
  if (!response.ok || data?.error) throw new Error(failureMessage);
  return data;
}

const LANGS = [
  ["en", "English"], ["hi", "हिंदी"], ["pa", "ਪੰਜਾਬੀ"], ["mr", "मराठी"], ["bn", "বাংলা"],
  ["gu", "ગુજરાતી"], ["ta", "தமிழ்"], ["te", "తెలుగు"], ["kn", "ಕನ್ನಡ"], ["ml", "മലയാളം"]
];

const T = {
  en: {
    home: 'Home', scanner: 'Scanner', weather: 'Weather', history: 'History', experts: 'Experts',
    chat: 'Krishi AI', settings: 'Settings', heroEyebrow: 'FIELD-READY AI FOR AGRICULTURE',
    heroTitle1: 'See the crop.', heroTitle2: 'Understand the risk.',
    heroText: 'Turn a simple crop-leaf image into disease intelligence, confidence, severity, alerts and practical next steps.',
    scan: 'Scan a crop', talk: 'Talk to Krishi AI', online: 'Online AI', offline: 'Offline-ready',
    languages: '10 languages', classes: 'crop classes', vision: 'vision input', field: 'field access',
    diagnostics: 'CROP DIAGNOSTICS', fromImage: 'From image to', fieldAction: 'field action.', imageInput: 'IMAGE INPUT',
    drop: 'Drop a crop image here', uploadHint: 'JPG or PNG Â· clear leaf photo works best', analyze: 'Analyse with AI',
    analyzing: 'Analysingâ€¦', offlineNote: 'Offline safety net. Your mobile TFLite flow remains untouched.',
    output: 'DIAGNOSTIC OUTPUT', ready: 'Ready when you are', readyText: 'Upload a crop image to reveal the diagnosis, confidence and action plan.',
    diagnosis: 'AI DIAGNOSIS', confidence: 'CONFIDENCE', status: 'STATUS', alert: 'GOVERNMENT ALERT',
    description: 'DESCRIPTION', treatment: 'TREATMENT', prevention: 'PREVENTION', farmerAction: 'FARMER ACTION',
    weatherTitle: 'Weather forecast', weatherSub: '7-day forecast with field-focused weather context.', searchCity: 'Search any city or place worldwide',
    useLocation: 'Use my location', forecast: '7-DAY FORECAST', agriSummary: 'AGRICULTURE SUMMARY',
    historyTitle: 'Saved diagnosis history', historySub: 'Your previous AI prediction results saved in this browser.',
    clear: 'Clear history', noHistory: 'No saved predictions yet', expertTitle: 'Expert agriculture information',
    expertSub: 'Practical guidance for crop planning, soil, irrigation, pests, disease, weather and post-harvest management.',
    consultants: 'Expert consultant referrals', searchTopics: 'Search agriculture topics', open: 'Open', close: 'Close',
    settingsTitle: 'Website settings', api: 'API endpoint', spline: 'Spline scene', readyApi: 'Ready', ask: 'Ask Krishi AI',
    askHint: 'Ask about crops, disease, irrigation, soil or farm managementâ€¦', send: 'Send', scanAgain: 'Scan another crop',
    language: 'Language', unknown: 'Unknown', weatherNoMatch: 'No matching location found.', weatherResolveError: 'Could not resolve this location.', weatherForecastError: 'Weather data could not be loaded.', weatherNetworkError: 'Network connection unavailable.', weatherResolving: 'Resolving locationâ€¦', weatherLoading: 'Loading weatherâ€¦', chooseLocation: 'Choose the matching location',
    locationPermissionDenied: 'Location permission denied.', locationUnavailable: 'Location unavailable. Check device location services and try again.', locationTimeout: 'Location request timed out. Please try again.', locationLoading: 'Loading weather for your locationâ€¦', useSearch: 'Use search above to load weather.', humidity: 'Humidity',
    rain: 'Rain', cloud: 'Cloud', wind: 'Wind'
  },
  hi: {
    home: 'à¤¹à¥‹à¤®', scanner: 'à¤¸à¥à¤•à¥ˆà¤¨à¤°', weather: 'à¤®à¥Œà¤¸à¤®', history: 'à¤‡à¤¤à¤¿à¤¹à¤¾à¤¸', experts: 'à¤•à¥ƒà¤·à¤¿ à¤µà¤¿à¤¶à¥‡à¤·à¤œà¥à¤ž', chat: 'à¤•à¥ƒà¤·à¤¿ AI',
    settings: 'à¤¸à¥‡à¤Ÿà¤¿à¤‚à¤—à¥à¤¸', heroEyebrow: 'à¤•à¥ƒà¤·à¤¿ à¤•à¥‡ à¤²à¤¿à¤ à¤®à¥ˆà¤¦à¤¾à¤¨à¥€ AI', heroTitle1: 'à¤«à¤¸à¤² à¤¦à¥‡à¤–à¥‡à¤‚à¥¤', heroTitle2: 'à¤œà¥‹à¤–à¤¿à¤® à¤¸à¤®à¤à¥‡à¤‚à¥¤',
    heroText: 'à¤ªà¤¤à¥à¤¤à¥‡ à¤•à¥€ à¤¤à¤¸à¥à¤µà¥€à¤° à¤¸à¥‡ à¤°à¥‹à¤— à¤•à¥€ à¤ªà¤¹à¤šà¤¾à¤¨, à¤µà¤¿à¤¶à¥à¤µà¤¸à¤¨à¥€à¤¯à¤¤à¤¾, à¤—à¤‚à¤­à¥€à¤°à¤¤à¤¾, à¤…à¤²à¤°à¥à¤Ÿ à¤”à¤° à¤µà¥à¤¯à¤¾à¤µà¤¹à¤¾à¤°à¤¿à¤• à¤¸à¤²à¤¾à¤¹ à¤ªà¥à¤°à¤¾à¤ªà¥à¤¤ à¤•à¤°à¥‡à¤‚à¥¤',
    scan: 'à¤«à¤¸à¤² à¤¸à¥à¤•à¥ˆà¤¨ à¤•à¤°à¥‡à¤‚', talk: 'à¤•à¥ƒà¤·à¤¿ AI à¤¸à¥‡ à¤ªà¥‚à¤›à¥‡à¤‚', online: 'à¤‘à¤¨à¤²à¤¾à¤‡à¤¨ AI', offline: 'à¤‘à¤«à¤²à¤¾à¤‡à¤¨ à¤¤à¥ˆà¤¯à¤¾à¤°', languages: '10 à¤­à¤¾à¤·à¤¾à¤à¤',
    classes: 'à¤«à¤¸à¤² à¤µà¤°à¥à¤—', vision: 'à¤µà¤¿à¤œà¤¼à¤¨ à¤‡à¤¨à¤ªà¥à¤Ÿ', field: 'à¤®à¥ˆà¤¦à¤¾à¤¨à¥€ à¤‰à¤ªà¤¯à¥‹à¤—', diagnostics: 'à¤«à¤¸à¤² à¤¨à¤¿à¤¦à¤¾à¤¨', fromImage: 'à¤¤à¤¸à¥à¤µà¥€à¤° à¤¸à¥‡',
    fieldAction: 'à¤–à¥‡à¤¤ à¤•à¥€ à¤•à¤¾à¤°à¥à¤°à¤µà¤¾à¤ˆ à¤¤à¤•', imageInput: 'à¤¤à¤¸à¥à¤µà¥€à¤° à¤‡à¤¨à¤ªà¥à¤Ÿ', drop: 'à¤«à¤¸à¤² à¤•à¥€ à¤¤à¤¸à¥à¤µà¥€à¤° à¤¯à¤¹à¤¾à¤ à¤¡à¤¾à¤²à¥‡à¤‚',
    uploadHint: 'JPG à¤¯à¤¾ PNG Â· à¤¸à¤¾à¤« à¤ªà¤¤à¥à¤¤à¥‡ à¤•à¥€ à¤¤à¤¸à¥à¤µà¥€à¤° à¤¬à¥‡à¤¹à¤¤à¤° à¤¹à¥ˆ', analyze: 'AI à¤¸à¥‡ à¤µà¤¿à¤¶à¥à¤²à¥‡à¤·à¤£ à¤•à¤°à¥‡à¤‚', analyzing: 'à¤µà¤¿à¤¶à¥à¤²à¥‡à¤·à¤£ à¤¹à¥‹ à¤°à¤¹à¤¾ à¤¹à¥ˆâ€¦',
    offlineNote: 'à¤‘à¤«à¤²à¤¾à¤‡à¤¨ à¤¸à¥à¤°à¤•à¥à¤·à¤¾à¥¤ à¤®à¥‹à¤¬à¤¾à¤‡à¤² TFLite à¤«à¥à¤²à¥‹ à¤¯à¤¥à¤¾à¤µà¤¤ à¤¹à¥ˆà¥¤', output: 'à¤¨à¤¿à¤¦à¤¾à¤¨ à¤ªà¤°à¤¿à¤£à¤¾à¤®', ready: 'à¤¤à¥ˆà¤¯à¤¾à¤° à¤¹à¥ˆ',
    readyText: 'à¤«à¤¸à¤² à¤•à¥€ à¤¤à¤¸à¥à¤µà¥€à¤° à¤…à¤ªà¤²à¥‹à¤¡ à¤•à¤°à¥‡à¤‚ à¤”à¤° à¤¨à¤¿à¤¦à¤¾à¤¨, à¤µà¤¿à¤¶à¥à¤µà¤¸à¤¨à¥€à¤¯à¤¤à¤¾ à¤µ à¤•à¤¾à¤°à¥à¤¯ à¤¯à¥‹à¤œà¤¨à¤¾ à¤¦à¥‡à¤–à¥‡à¤‚à¥¤', diagnosis: 'AI à¤¨à¤¿à¤¦à¤¾à¤¨', confidence: 'à¤µà¤¿à¤¶à¥à¤µà¤¸à¤¨à¥€à¤¯à¤¤à¤¾',
    status: 'à¤¸à¥à¤¥à¤¿à¤¤à¤¿', alert: 'à¤¸à¤°à¤•à¤¾à¤°à¥€ à¤…à¤²à¤°à¥à¤Ÿ', description: 'à¤µà¤¿à¤µà¤°à¤£', treatment: 'à¤‰à¤ªà¤šà¤¾à¤°', prevention: 'à¤°à¥‹à¤•à¤¥à¤¾à¤®', farmerAction: 'à¤•à¤¿à¤¸à¤¾à¤¨ à¤•à¤¾à¤°à¥à¤°à¤µà¤¾à¤ˆ',
    weatherTitle: 'à¤®à¥Œà¤¸à¤® à¤ªà¥‚à¤°à¥à¤µà¤¾à¤¨à¥à¤®à¤¾à¤¨', weatherSub: 'à¤–à¥‡à¤¤ à¤•à¥‡ à¤²à¤¿à¤ 7-à¤¦à¤¿à¤¨ à¤•à¤¾ à¤®à¥Œà¤¸à¤® à¤”à¤° à¤‰à¤ªà¤¯à¥‹à¤—à¥€ à¤¸à¤‚à¤¦à¤°à¥à¤­à¥¤', searchCity: 'à¤¶à¤¹à¤° à¤–à¥‹à¤œà¥‡à¤‚',
    useLocation: 'à¤®à¥‡à¤°à¥€ à¤²à¥‹à¤•à¥‡à¤¶à¤¨', forecast: '7-à¤¦à¤¿à¤¨ à¤•à¤¾ à¤ªà¥‚à¤°à¥à¤µà¤¾à¤¨à¥à¤®à¤¾à¤¨', agriSummary: 'à¤•à¥ƒà¤·à¤¿ à¤¸à¤¾à¤°à¤¾à¤‚à¤¶', historyTitle: 'à¤¸à¤¹à¥‡à¤œà¤¾ à¤—à¤¯à¤¾ à¤¨à¤¿à¤¦à¤¾à¤¨ à¤‡à¤¤à¤¿à¤¹à¤¾à¤¸',
    historySub: 'à¤‡à¤¸ à¤¬à¥à¤°à¤¾à¤‰à¤œà¤¼à¤° à¤®à¥‡à¤‚ à¤¸à¥à¤°à¤•à¥à¤·à¤¿à¤¤ à¤ªà¤¿à¤›à¤²à¥‡ AI à¤ªà¤°à¤¿à¤£à¤¾à¤®à¥¤', clear: 'à¤‡à¤¤à¤¿à¤¹à¤¾à¤¸ à¤¸à¤¾à¤« à¤•à¤°à¥‡à¤‚', noHistory: 'à¤…à¤­à¥€ à¤•à¥‹à¤ˆ à¤ªà¤°à¤¿à¤£à¤¾à¤® à¤¸à¤¹à¥‡à¤œà¤¾ à¤¨à¤¹à¥€à¤‚ à¤—à¤¯à¤¾',
    expertTitle: 'à¤•à¥ƒà¤·à¤¿ à¤µà¤¿à¤¶à¥‡à¤·à¤œà¥à¤ž à¤œà¤¾à¤¨à¤•à¤¾à¤°à¥€', expertSub: 'à¤«à¤¸à¤², à¤®à¤¿à¤Ÿà¥à¤Ÿà¥€, à¤¸à¤¿à¤‚à¤šà¤¾à¤ˆ, à¤•à¥€à¤Ÿ, à¤°à¥‹à¤—, à¤®à¥Œà¤¸à¤® à¤”à¤° à¤­à¤‚à¤¡à¤¾à¤°à¤£ à¤ªà¤° à¤µà¥à¤¯à¤¾à¤µà¤¹à¤¾à¤°à¤¿à¤• à¤®à¤¾à¤°à¥à¤—à¤¦à¤°à¥à¤¶à¤¨à¥¤',
    consultants: 'à¤µà¤¿à¤¶à¥‡à¤·à¤œà¥à¤ž à¤¸à¤‚à¤ªà¤°à¥à¤•', searchTopics: 'à¤•à¥ƒà¤·à¤¿ à¤µà¤¿à¤·à¤¯ à¤–à¥‹à¤œà¥‡à¤‚', open: 'à¤–à¥‹à¤²à¥‡à¤‚', close: 'à¤¬à¤‚à¤¦ à¤•à¤°à¥‡à¤‚', settingsTitle: 'à¤µà¥‡à¤¬à¤¸à¤¾à¤‡à¤Ÿ à¤¸à¥‡à¤Ÿà¤¿à¤‚à¤—à¥à¤¸',
    api: 'API à¤ªà¤¤à¤¾', spline: 'Spline à¤¦à¥ƒà¤¶à¥à¤¯', readyApi: 'à¤¤à¥ˆà¤¯à¤¾à¤°', ask: 'à¤•à¥ƒà¤·à¤¿ AI à¤¸à¥‡ à¤ªà¥‚à¤›à¥‡à¤‚', askHint: 'à¤«à¤¸à¤², à¤°à¥‹à¤—, à¤¸à¤¿à¤‚à¤šà¤¾à¤ˆ, à¤®à¤¿à¤Ÿà¥à¤Ÿà¥€ à¤¯à¤¾ à¤–à¥‡à¤¤à¥€ à¤•à¥‡ à¤¬à¤¾à¤°à¥‡ à¤®à¥‡à¤‚ à¤ªà¥‚à¤›à¥‡à¤‚â€¦',
    send: 'à¤­à¥‡à¤œà¥‡à¤‚', scanAgain: 'à¤¦à¥‚à¤¸à¤°à¥€ à¤«à¤¸à¤² à¤¸à¥à¤•à¥ˆà¤¨ à¤•à¤°à¥‡à¤‚', language: 'à¤­à¤¾à¤·à¤¾', unknown: 'à¤…à¤œà¥à¤žà¤¾à¤¤', weatherNoMatch: 'à¤•à¥‹à¤ˆ à¤®à¤¿à¤²à¤¤à¤¾-à¤œà¥à¤²à¤¤à¤¾ à¤¸à¥à¤¥à¤¾à¤¨ à¤¨à¤¹à¥€à¤‚ à¤®à¤¿à¤²à¤¾à¥¤', weatherResolveError: 'à¤‡à¤¸ à¤¸à¥à¤¥à¤¾à¤¨ à¤•à¤¾ à¤ªà¤¤à¤¾ à¤¨à¤¹à¥€à¤‚ à¤šà¤² à¤¸à¤•à¤¾à¥¤', weatherForecastError: 'à¤®à¥Œà¤¸à¤® à¤¡à¥‡à¤Ÿà¤¾ à¤²à¥‹à¤¡ à¤¨à¤¹à¥€à¤‚ à¤¹à¥‹ à¤¸à¤•à¤¾à¥¤', weatherNetworkError: 'à¤¨à¥‡à¤Ÿà¤µà¤°à¥à¤• à¤•à¤¨à¥‡à¤•à¥à¤¶à¤¨ à¤‰à¤ªà¤²à¤¬à¥à¤§ à¤¨à¤¹à¥€à¤‚ à¤¹à¥ˆà¥¤', weatherResolving: 'à¤¸à¥à¤¥à¤¾à¤¨ à¤–à¥‹à¤œà¤¾ à¤œà¤¾ à¤°à¤¹à¤¾ à¤¹à¥ˆâ€¦', weatherLoading: 'à¤®à¥Œà¤¸à¤® à¤²à¥‹à¤¡ à¤¹à¥‹ à¤°à¤¹à¤¾ à¤¹à¥ˆâ€¦', chooseLocation: 'à¤¸à¤¹à¥€ à¤¸à¥à¤¥à¤¾à¤¨ à¤šà¥à¤¨à¥‡à¤‚',
    locationPermissionDenied: 'à¤²à¥‹à¤•à¥‡à¤¶à¤¨ à¤•à¥€ à¤…à¤¨à¥à¤®à¤¤à¤¿ à¤¨à¤¹à¥€à¤‚ à¤®à¤¿à¤²à¥€à¥¤', locationUnavailable: 'à¤²à¥‹à¤•à¥‡à¤¶à¤¨ à¤‰à¤ªà¤²à¤¬à¥à¤§ à¤¨à¤¹à¥€à¤‚ à¤¹à¥ˆà¥¤ à¤¡à¤¿à¤µà¤¾à¤‡à¤¸ à¤•à¥€ à¤²à¥‹à¤•à¥‡à¤¶à¤¨ à¤¸à¥‡à¤µà¤¾ à¤œà¤¾à¤à¤šà¥‡à¤‚à¥¤', locationTimeout: 'à¤²à¥‹à¤•à¥‡à¤¶à¤¨ à¤…à¤¨à¥à¤°à¥‹à¤§ à¤•à¤¾ à¤¸à¤®à¤¯ à¤¸à¤®à¤¾à¤ªà¥à¤¤ à¤¹à¥‹ à¤—à¤¯à¤¾à¥¤ à¤«à¤¿à¤° à¤¸à¥‡ à¤ªà¥à¤°à¤¯à¤¾à¤¸ à¤•à¤°à¥‡à¤‚à¥¤', locationLoading: 'à¤†à¤ªà¤•à¥€ à¤²à¥‹à¤•à¥‡à¤¶à¤¨ à¤•à¤¾ à¤®à¥Œà¤¸à¤® à¤²à¥‹à¤¡ à¤¹à¥‹ à¤°à¤¹à¤¾ à¤¹à¥ˆâ€¦', useSearch: 'à¤®à¥Œà¤¸à¤® à¤¦à¥‡à¤–à¤¨à¥‡ à¤•à¥‡ à¤²à¤¿à¤ à¤Šà¤ªà¤° à¤–à¥‹à¤œà¥‡à¤‚à¥¤', humidity: 'à¤¨à¤®à¥€', rain: 'à¤¬à¤¾à¤°à¤¿à¤¶',
    cloud: 'à¤¬à¤¾à¤¦à¤²', wind: 'à¤¹à¤µà¤¾'
  },
  pa: {
    home: 'ਘਰ', scanner: 'ਸਕੈਨਰ', weather: 'ਮੌਸਮ', history: 'ਇਤਿਹਾਸ', experts: 'ਖੇਤੀ ਮਾਹਿਰ', chat: 'ਕ੍ਰਿਸ਼ੀ AI',
    settings: 'ਸੈਟਿੰਗਾਂ', heroEyebrow: 'ਖੇਤੀ ਲਈ ਮੈਦਾਨੀ AI', heroTitle1: 'ਫਸਲ ਵੇਖੋ।', heroTitle2: 'ਖਤਰੇ ਨੂੰ ਸਮਝੋ।',
    heroText: 'ਫਸਲ ਦੇ ਪੱਤੇ ਦੀ ਤਸਵੀਰ ਤੋਂ ਰੋਗ ਦੀ ਪਛਾਣ, ਭਰੋਸਾ, ਗੰਭੀਰਤਾ, ਚੇਤਾਵਨੀ ਅਤੇ ਅਗਲੇ ਕਦਮ ਜਾਣੋ।',
    scan: 'ਫਸਲ ਸਕੈਨ ਕਰੋ', talk: 'ਕ੍ਰਿਸ਼ੀ AI ਨਾਲ ਗੱਲ ਕਰੋ', online: 'ਆਨਲਾਈਨ AI', offline: 'ਆਫਲਾਈਨ ਤਿਆਰ', languages: '10 ਭਾਸ਼ਾਵਾਂ',
    classes: 'ਫਸਲ ਵਰਗ', vision: 'ਵਿਜ਼ਨ ਇਨਪੁਟ', field: 'ਖੇਤ ਪਹੁੰਚ', diagnostics: 'ਫਸਲ ਜਾਂਚ', fromImage: 'ਤਸਵੀਰ ਤੋਂ', fieldAction: 'ਖੇਤ ਦੀ ਕਾਰਵਾਈ ਤੱਕ',
    imageInput: 'ਤਸਵੀਰ ਇਨਪੁਟ', drop: 'ਫਸਲ ਦੀ ਤਸਵੀਰ ਇੱਥੇ ਪਾਓ', uploadHint: 'JPG ਜਾਂ PNG · ਸਾਫ਼ ਪੱਤੇ ਦੀ ਤਸਵੀਰ ਵਧੀਆ ਹੈ',
    analyze: 'AI ਨਾਲ ਵਿਸ਼ਲੇਸ਼ਣ ਕਰੋ', analyzing: 'ਵਿਸ਼ਲੇਸ਼ਣ ਹੋ ਰਿਹਾ ਹੈ…', offlineNote: 'ਆਫਲਾਈਨ ਸੁਰੱਖਿਆ। ਤੁਹਾਡਾ ਮੋਬਾਈਲ TFLite ਫਲੋ ਬਦਲਿਆ ਨਹੀਂ ਗਿਆ।',
    output: 'ਜਾਂਚ ਨਤੀਜਾ', ready: 'ਤਿਆਰ ਹੈ', readyText: 'ਫਸਲ ਦੀ ਤਸਵੀਰ ਅੱਪਲੋਡ ਕਰੋ ਅਤੇ ਨਿਦਾਨ, ਭਰੋਸਾ ਅਤੇ ਕਾਰਵਾਈ ਯੋਜਨਾ ਵੇਖੋ।',
    diagnosis: 'AI ਨਿਦਾਨ', confidence: 'ਭਰੋਸੇਯੋਗਤਾ', status: 'ਸਥਿਤੀ', alert: 'ਸਰਕਾਰੀ ਚੇਤਾਵਨੀ', description: 'ਵੇਰਵਾ',
    treatment: 'ਇਲਾਜ', prevention: 'ਰੋਕਥਾਮ', farmerAction: 'ਕਿਸਾਨ ਕਾਰਵਾਈ', weatherTitle: 'ਮੌਸਮ ਪੂਰਵ ਅਨੁਮਾਨ',
    weatherSub: 'ਖੇਤ ਲਈ 7 ਦਿਨਾਂ ਦਾ ਮੌਸਮ ਅਤੇ ਉਪਯੋਗੀ ਜਾਣਕਾਰੀ।', searchCity: 'ਦੁਨੀਆ ਭਰ ਵਿੱਚ ਸ਼ਹਿਰ ਜਾਂ ਸਥਾਨ ਖੋਜੋ',
    useLocation: 'ਮੇਰੀ ਸਥਿਤੀ ਵਰਤੋ', forecast: '7-ਦਿਨਾਂ ਦਾ ਪੂਰਵ ਅਨੁਮਾਨ', agriSummary: 'ਖੇਤੀ ਸਾਰ',
    historyTitle: 'ਸੰਭਾਲਿਆ ਨਿਦਾਨ ਇਤਿਹਾਸ', historySub: 'ਇਸ ਬ੍ਰਾਊਜ਼ਰ ਵਿੱਚ ਸੰਭਾਲੇ ਪਿਛਲੇ AI ਨਤੀਜੇ।',
    clear: 'ਇਤਿਹਾਸ ਸਾਫ਼ ਕਰੋ', noHistory: 'ਹਾਲੇ ਕੋਈ ਨਤੀਜਾ ਸੰਭਾਲਿਆ ਨਹੀਂ', expertTitle: 'ਖੇਤੀ ਮਾਹਿਰ ਜਾਣਕਾਰੀ',
    expertSub: 'ਫਸਲ ਯੋਜਨਾ, ਮਿੱਟੀ, ਸਿੰਚਾਈ, ਕੀੜੇ, ਰੋਗ, ਮੌਸਮ ਅਤੇ ਕਟਾਈ ਬਾਅਦ ਪ੍ਰਬੰਧਨ ਲਈ ਮਾਰਗਦਰਸ਼ਨ।',
    consultants: 'ਮਾਹਿਰ ਸਲਾਹਕਾਰ', searchTopics: 'ਖੇਤੀ ਵਿਸ਼ੇ ਖੋਜੋ', open: 'ਖੋਲ੍ਹੋ', close: 'ਬੰਦ ਕਰੋ',
    settingsTitle: 'ਵੈੱਬਸਾਈਟ ਸੈਟਿੰਗਾਂ', api: 'API ਪਤਾ', spline: 'Spline ਦ੍ਰਿਸ਼', readyApi: 'ਤਿਆਰ', ask: 'ਕ੍ਰਿਸ਼ੀ AI ਨੂੰ ਪੁੱਛੋ',
    askHint: 'ਫਸਲ, ਰੋਗ, ਸਿੰਚਾਈ, ਮਿੱਟੀ ਜਾਂ ਖੇਤੀ ਬਾਰੇ ਪੁੱਛੋ…', send: 'ਭੇਜੋ', scanAgain: 'ਹੋਰ ਫਸਲ ਸਕੈਨ ਕਰੋ',
    language: 'ਭਾਸ਼ਾ', unknown: 'ਅਣਜਾਣ', weatherNoMatch: 'ਕੋਈ ਮਿਲਦਾ ਸਥਾਨ ਨਹੀਂ ਮਿਲਿਆ।', weatherResolveError: 'ਇਸ ਸਥਾਨ ਦੀ ਪਛਾਣ ਨਹੀਂ ਹੋ ਸਕੀ।',
    weatherForecastError: 'ਮੌਸਮ ਡਾਟਾ ਲੋਡ ਨਹੀਂ ਹੋ ਸਕਿਆ।', weatherNetworkError: 'ਨੈੱਟਵਰਕ ਕਨੈਕਸ਼ਨ ਉਪਲਬਧ ਨਹੀਂ।', weatherResolving: 'ਸਥਾਨ ਲੱਭਿਆ ਜਾ ਰਿਹਾ ਹੈ…',
    weatherLoading: 'ਮੌਸਮ ਲੋਡ ਹੋ ਰਿਹਾ ਹੈ…', chooseLocation: 'ਮਿਲਦਾ ਸਥਾਨ ਚੁਣੋ', locationPermissionDenied: 'ਸਥਾਨ ਦੀ ਇਜਾਜ਼ਤ ਨਹੀਂ ਮਿਲੀ।',
    locationUnavailable: 'ਸਥਾਨ ਉਪਲਬਧ ਨਹੀਂ। ਡਿਵਾਈਸ ਦੀ ਸਥਾਨ ਸੇਵਾ ਜਾਂਚੋ ਅਤੇ ਦੁਬਾਰਾ ਕੋਸ਼ਿਸ਼ ਕਰੋ।', locationTimeout: 'ਸਥਾਨ ਬੇਨਤੀ ਦਾ ਸਮਾਂ ਖਤਮ ਹੋ ਗਿਆ।',
    locationLoading: 'ਤੁਹਾਡੇ ਸਥਾਨ ਦਾ ਮੌਸਮ ਲੋਡ ਹੋ ਰਿਹਾ ਹੈ…', useSearch: 'ਮੌਸਮ ਲੋਡ ਕਰਨ ਲਈ ਉੱਪਰ ਖੋਜ ਕਰੋ।', humidity: 'ਨਮੀ', rain: 'ਮੀਂਹ', cloud: 'ਬੱਦਲ', wind: 'ਹਵਾ'
  },
  mr: {
    home: 'मुख्यपृष्ठ', scanner: 'स्कॅनर', weather: 'हवामान', history: 'इतिहास', experts: 'कृषी तज्ज्ञ', chat: 'कृषी AI',
    settings: 'सेटिंग्ज', heroEyebrow: 'शेतीसाठी मैदानी AI', heroTitle1: 'पीक पहा.', heroTitle2: 'जोखीम समजा.',
    heroText: 'पिकाच्या पानाच्या प्रतिमेतून रोगाची माहिती, विश्वास, तीव्रता, सूचना आणि पुढील कृती जाणून घ्या.',
    scan: 'पीक स्कॅन करा', talk: 'कृषी AI शी बोला', online: 'ऑनलाइन AI', offline: 'ऑफलाइन तयार', languages: '10 भाषा',
    classes: 'पीक वर्ग', vision: 'व्हिजन इनपुट', field: 'शेतातील वापर', diagnostics: 'पीक निदान', fromImage: 'प्रतिमेतून', fieldAction: 'शेतातील कृतीपर्यंत',
    imageInput: 'प्रतिमा इनपुट', drop: 'पिकाची प्रतिमा येथे टाका', uploadHint: 'JPG किंवा PNG · स्वच्छ पानाची प्रतिमा उत्तम',
    analyze: 'AI ने विश्लेषण करा', analyzing: 'विश्लेषण सुरू आहे…', offlineNote: 'ऑफलाइन सुरक्षा. तुमचा मोबाइल TFLite प्रवाह तसाच आहे.',
    output: 'निदान परिणाम', ready: 'तयार आहे', readyText: 'पिकाची प्रतिमा अपलोड करा आणि निदान, विश्वास व कृती योजना पहा.',
    diagnosis: 'AI निदान', confidence: 'विश्वास', status: 'स्थिती', alert: 'सरकारी सूचना', description: 'वर्णन',
    treatment: 'उपचार', prevention: 'प्रतिबंध', farmerAction: 'शेतकरी कृती', weatherTitle: 'हवामान अंदाज',
    weatherSub: 'शेतासाठी 7 दिवसांचा हवामान अंदाज.', searchCity: 'जगभरातील शहर किंवा ठिकाण शोधा',
    useLocation: 'माझे स्थान वापरा', forecast: '7 दिवसांचा अंदाज', agriSummary: 'कृषी सारांश',
    historyTitle: 'जतन केलेला निदान इतिहास', historySub: 'या ब्राउझरमध्ये जतन केलेले मागील AI निकाल.',
    clear: 'इतिहास साफ करा', noHistory: 'अजून कोणतेही निकाल जतन केलेले नाहीत', expertTitle: 'कृषी तज्ज्ञ माहिती',
    expertSub: 'पीक नियोजन, माती, सिंचन, कीड, रोग, हवामान आणि काढणीनंतरच्या व्यवस्थापनासाठी मार्गदर्शन.',
    consultants: 'तज्ज्ञ सल्लागार', searchTopics: 'कृषी विषय शोधा', open: 'उघडा', close: 'बंद करा',
    settingsTitle: 'वेबसाइट सेटिंग्ज', api: 'API पत्ता', spline: 'Spline दृश्य', readyApi: 'तयार', ask: 'कृषी AI ला विचारा',
    askHint: 'पिके, रोग, सिंचन, माती किंवा शेतीबद्दल विचारा…', send: 'पाठवा', scanAgain: 'दुसरे पीक स्कॅन करा',
    language: 'भाषा', unknown: 'अज्ञात', weatherNoMatch: 'जुळणारे ठिकाण सापडले नाही.', weatherResolveError: 'हे ठिकाण शोधता आले नाही.',
    weatherForecastError: 'हवामान डेटा लोड करता आला नाही.', weatherNetworkError: 'नेटवर्क कनेक्शन उपलब्ध नाही.', weatherResolving: 'स्थान शोधत आहे…',
    weatherLoading: 'हवामान लोड होत आहे…', chooseLocation: 'जुळणारे स्थान निवडा', locationPermissionDenied: 'स्थानाची परवानगी नाकारली.',
    locationUnavailable: 'स्थान उपलब्ध नाही. डिव्हाइस स्थान सेवा तपासा आणि पुन्हा प्रयत्न करा.', locationTimeout: 'स्थान विनंतीची वेळ संपली.',
    locationLoading: 'तुमच्या स्थानाचे हवामान लोड होत आहे…', useSearch: 'हवामान लोड करण्यासाठी वर शोधा.', humidity: 'आर्द्रता', rain: 'पाऊस', cloud: 'ढग', wind: 'वारा'
  },
  bn: {
    home: 'হোম', scanner: 'স্ক্যানার', weather: 'আবহাওয়া', history: 'ইতিহাস', experts: 'কৃষি বিশেষজ্ঞ', chat: 'কৃষি AI',
    settings: 'সেটিংস', heroEyebrow: 'কৃষির জন্য মাঠ-প্রস্তুত AI', heroTitle1: 'ফসল দেখুন।', heroTitle2: 'ঝুঁকি বুঝুন।',
    heroText: 'ফসলের পাতার ছবি থেকে রোগের তথ্য, নির্ভরযোগ্যতা, তীব্রতা, সতর্কতা ও পরবর্তী করণীয় জানুন।',
    scan: 'ফসল স্ক্যান করুন', talk: 'কৃষি AI-এর সাথে কথা বলুন', online: 'অনলাইন AI', offline: 'অফলাইন প্রস্তুত', languages: '১০টি ভাষা',
    classes: 'ফসলের শ্রেণি', vision: 'ভিশন ইনপুট', field: 'মাঠে ব্যবহার', diagnostics: 'ফসল নির্ণয়', fromImage: 'ছবি থেকে', fieldAction: 'মাঠের করণীয় পর্যন্ত',
    imageInput: 'ছবির ইনপুট', drop: 'ফসলের ছবি এখানে দিন', uploadHint: 'JPG বা PNG · পরিষ্কার পাতার ছবি সবচেয়ে ভালো',
    analyze: 'AI দিয়ে বিশ্লেষণ করুন', analyzing: 'বিশ্লেষণ হচ্ছে…', offlineNote: 'অফলাইন সুরক্ষা। আপনার মোবাইল TFLite ফ্লো অপরিবর্তিত আছে।',
    output: 'নির্ণয়ের ফলাফল', ready: 'প্রস্তুত', readyText: 'ফসলের ছবি আপলোড করে রোগ নির্ণয়, নির্ভরযোগ্যতা ও করণীয় দেখুন।',
    diagnosis: 'AI নির্ণয়', confidence: 'নির্ভরযোগ্যতা', status: 'অবস্থা', alert: 'সরকারি সতর্কতা', description: 'বিবরণ',
    treatment: 'চিকিৎসা', prevention: 'প্রতিরোধ', farmerAction: 'কৃষকের করণীয়', weatherTitle: 'আবহাওয়ার পূর্বাভাস',
    weatherSub: 'কৃষিকাজের জন্য ৭ দিনের আবহাওয়ার তথ্য।', searchCity: 'বিশ্বের যেকোনো শহর বা স্থান খুঁজুন',
    useLocation: 'আমার অবস্থান ব্যবহার করুন', forecast: '৭ দিনের পূর্বাভাস', agriSummary: 'কৃষি সারাংশ',
    historyTitle: 'সংরক্ষিত রোগ নির্ণয়ের ইতিহাস', historySub: 'এই ব্রাউজারে সংরক্ষিত আগের AI ফলাফল।',
    clear: 'ইতিহাস মুছুন', noHistory: 'এখনও কোনো ফলাফল সংরক্ষিত নেই', expertTitle: 'কৃষি বিশেষজ্ঞ তথ্য',
    expertSub: 'ফসল পরিকল্পনা, মাটি, সেচ, পোকা, রোগ, আবহাওয়া ও ফসল কাটার পর ব্যবস্থাপনার ব্যবহারিক নির্দেশনা।',
    consultants: 'বিশেষজ্ঞ পরামর্শ', searchTopics: 'কৃষি বিষয় খুঁজুন', open: 'খুলুন', close: 'বন্ধ করুন',
    settingsTitle: 'ওয়েবসাইট সেটিংস', api: 'API ঠিকানা', spline: 'Spline দৃশ্য', readyApi: 'প্রস্তুত', ask: 'কৃষি AI-কে জিজ্ঞাসা করুন',
    askHint: 'ফসল, রোগ, সেচ, মাটি বা কৃষি ব্যবস্থাপনা সম্পর্কে জিজ্ঞাসা করুন…', send: 'পাঠান', scanAgain: 'আরেকটি ফসল স্ক্যান করুন',
    language: 'ভাষা', unknown: 'অজানা', weatherNoMatch: 'কোনো মিলযুক্ত স্থান পাওয়া যায়নি।', weatherResolveError: 'এই স্থানটি শনাক্ত করা যায়নি।',
    weatherForecastError: 'আবহাওয়ার তথ্য লোড করা যায়নি।', weatherNetworkError: 'নেটওয়ার্ক সংযোগ নেই।', weatherResolving: 'স্থান খোঁজা হচ্ছে…',
    weatherLoading: 'আবহাওয়া লোড হচ্ছে…', chooseLocation: 'মিলযুক্ত স্থান নির্বাচন করুন', locationPermissionDenied: 'অবস্থানের অনুমতি প্রত্যাখ্যান করা হয়েছে।',
    locationUnavailable: 'অবস্থান পাওয়া যাচ্ছে না। ডিভাইসের অবস্থান পরিষেবা পরীক্ষা করে আবার চেষ্টা করুন।', locationTimeout: 'অবস্থানের অনুরোধের সময় শেষ হয়েছে।',
    locationLoading: 'আপনার অবস্থানের আবহাওয়া লোড হচ্ছে…', useSearch: 'আবহাওয়া লোড করতে উপরে খুঁজুন।', humidity: 'আর্দ্রতা', rain: 'বৃষ্টি', cloud: 'মেঘ', wind: 'বাতাস'
  },
  gu: {
    home: 'હોમ', scanner: 'સ્કેનર', weather: 'હવામાન', history: 'ઇતિહાસ', experts: 'કૃષિ નિષ્ણાતો', chat: 'કૃષિ AI',
    settings: 'સેટિંગ્સ', heroEyebrow: 'ખેતી માટે મેદાન-તૈયાર AI', heroTitle1: 'પાક જુઓ.', heroTitle2: 'જોખમ સમજો.',
    heroText: 'પાકના પાનની તસવીરથી રોગની માહિતી, વિશ્વસનીયતા, ગંભીરતા, ચેતવણી અને આગળનાં પગલાં જાણો.',
    scan: 'પાક સ્કેન કરો', talk: 'કૃષિ AI સાથે વાત કરો', online: 'ઓનલાઇન AI', offline: 'ઓફલાઇન તૈયાર', languages: '10 ભાષાઓ',
    classes: 'પાક વર્ગો', vision: 'વિઝન ઇનપુટ', field: 'ખેતર ઉપયોગ', diagnostics: 'પાક નિદાન', fromImage: 'તસવીરથી', fieldAction: 'ખેતરની કાર્યવાહી સુધી',
    imageInput: 'તસવીર ઇનપુટ', drop: 'પાકની તસવીર અહીં મૂકો', uploadHint: 'JPG અથવા PNG · પાનની સ્પષ્ટ તસવીર શ્રેષ્ઠ',
    analyze: 'AIથી વિશ્લેષણ કરો', analyzing: 'વિશ્લેષણ થઈ રહ્યું છે…', offlineNote: 'ઓફલાઇન સુરક્ષા. તમારો મોબાઇલ TFLite ફ્લો યથાવત છે.',
    output: 'નિદાન પરિણામ', ready: 'તૈયાર છે', readyText: 'પાકની તસવીર અપલોડ કરો અને નિદાન, વિશ્વાસ તથા કાર્યવાહી યોજના જુઓ.',
    diagnosis: 'AI નિદાન', confidence: 'વિશ્વાસ', status: 'સ્થિતિ', alert: 'સરકારી ચેતવણી', description: 'વર્ણન',
    treatment: 'સારવાર', prevention: 'નિવારણ', farmerAction: 'ખેડૂત કાર્યવાહી', weatherTitle: 'હવામાન આગાહી',
    weatherSub: 'ખેતર માટે 7 દિવસની હવામાન માહિતી.', searchCity: 'વિશ્વભરમાં કોઈપણ શહેર અથવા સ્થળ શોધો',
    useLocation: 'મારું સ્થાન વાપરો', forecast: '7 દિવસની આગાહી', agriSummary: 'કૃષિ સારાંશ',
    historyTitle: 'સાચવેલો નિદાન ઇતિહાસ', historySub: 'આ બ્રાઉઝરમાં સાચવેલા અગાઉના AI પરિણામો.',
    clear: 'ઇતિહાસ સાફ કરો', noHistory: 'હજુ કોઈ પરિણામ સાચવાયું નથી', expertTitle: 'કૃષિ નિષ્ણાત માહિતી',
    expertSub: 'પાક આયોજન, જમીન, સિંચાઈ, જીવાત, રોગ, હવામાન અને લણણી પછીના વ્યવસ્થાપન માટે માર્ગદર્શન.',
    consultants: 'નિષ્ણાત સલાહકારો', searchTopics: 'કૃષિ વિષયો શોધો', open: 'ખોલો', close: 'બંધ કરો',
    settingsTitle: 'વેબસાઇટ સેટિંગ્સ', api: 'API સરનામું', spline: 'Spline દૃશ્ય', readyApi: 'તૈયાર', ask: 'કૃષિ AIને પૂછો',
    askHint: 'પાક, રોગ, સિંચાઈ, જમીન અથવા ખેતી વિશે પૂછો…', send: 'મોકલો', scanAgain: 'બીજો પાક સ્કેન કરો',
    language: 'ભાષા', unknown: 'અજ્ઞાત', weatherNoMatch: 'મેળ ખાતું સ્થળ મળ્યું નથી.', weatherResolveError: 'આ સ્થાન શોધી શકાયું નથી.',
    weatherForecastError: 'હવામાન ડેટા લોડ થઈ શક્યો નથી.', weatherNetworkError: 'નેટવર્ક કનેક્શન ઉપલબ્ધ નથી.', weatherResolving: 'સ્થાન શોધી રહ્યા છીએ…',
    weatherLoading: 'હવામાન લોડ થઈ રહ્યું છે…', chooseLocation: 'મેળ ખાતું સ્થાન પસંદ કરો', locationPermissionDenied: 'સ્થાનની પરવાનગી નકારી કાઢવામાં આવી.',
    locationUnavailable: 'સ્થાન ઉપલબ્ધ નથી. ડિવાઇસની સ્થાન સેવા તપાસો અને ફરી પ્રયાસ કરો.', locationTimeout: 'સ્થાન વિનંતીનો સમય સમાપ્ત થયો.',
    locationLoading: 'તમારા સ્થાનનું હવામાન લોડ થઈ રહ્યું છે…', useSearch: 'હવામાન લોડ કરવા ઉપર શોધો.', humidity: 'ભેજ', rain: 'વરસાદ', cloud: 'વાદળ', wind: 'પવન'
  },
  ta: {
    home: 'முகப்பு', scanner: 'ஸ்கேனர்', weather: 'வானிலை', history: 'வரலாறு', experts: 'வேளாண் நிபுணர்கள்', chat: 'கிருஷி AI',
    settings: 'அமைப்புகள்', heroEyebrow: 'விவசாயத்திற்கான களத் தயாரான AI', heroTitle1: 'பயிரைப் பாருங்கள்.', heroTitle2: 'ஆபத்தைப் புரிந்துகொள்ளுங்கள்.',
    heroText: 'பயிர் இலைப் படத்திலிருந்து நோய் தகவல், நம்பகத்தன்மை, தீவிரம், எச்சரிக்கைகள் மற்றும் அடுத்த நடவடிக்கைகளை அறியுங்கள்.',
    scan: 'பயிரை ஸ்கேன் செய்யுங்கள்', talk: 'கிருஷி AI-யுடன் பேசுங்கள்', online: 'ஆன்லைன் AI', offline: 'ஆஃப்லைன் தயார்', languages: '10 மொழிகள்',
    classes: 'பயிர் வகைகள்', vision: 'விஷன் உள்ளீடு', field: 'களப் பயன்பாடு', diagnostics: 'பயிர் கண்டறிதல்', fromImage: 'படத்திலிருந்து', fieldAction: 'கள நடவடிக்கை வரை',
    imageInput: 'பட உள்ளீடு', drop: 'பயிர் படத்தை இங்கே இடுங்கள்', uploadHint: 'JPG அல்லது PNG · தெளிவான இலைப் படம் சிறந்தது',
    analyze: 'AI மூலம் பகுப்பாய்வு செய்யுங்கள்', analyzing: 'பகுப்பாய்வு நடக்கிறது…', offlineNote: 'ஆஃப்லைன் பாதுகாப்பு. உங்கள் மொபைல் TFLite செயல்முறை மாற்றப்படவில்லை.',
    output: 'கண்டறிதல் முடிவு', ready: 'தயார்', readyText: 'பயிர் படத்தைப் பதிவேற்றி நோயறிதல், நம்பகத்தன்மை மற்றும் செயல்திட்டத்தைப் பாருங்கள்.',
    diagnosis: 'AI நோயறிதல்', confidence: 'நம்பகத்தன்மை', status: 'நிலை', alert: 'அரசு எச்சரிக்கை', description: 'விளக்கம்',
    treatment: 'சிகிச்சை', prevention: 'தடுப்பு', farmerAction: 'விவசாயி நடவடிக்கை', weatherTitle: 'வானிலை முன்னறிவிப்பு',
    weatherSub: 'வயலுக்கான 7 நாள் வானிலை தகவல்.', searchCity: 'உலகம் முழுவதும் நகரம் அல்லது இடத்தைத் தேடுங்கள்',
    useLocation: 'என் இருப்பிடத்தைப் பயன்படுத்து', forecast: '7 நாள் முன்னறிவிப்பு', agriSummary: 'வேளாண் சுருக்கம்',
    historyTitle: 'சேமிக்கப்பட்ட நோயறிதல் வரலாறு', historySub: 'இந்த உலாவியில் சேமிக்கப்பட்ட முந்தைய AI முடிவுகள்.',
    clear: 'வரலாற்றை அழிக்கவும்', noHistory: 'இதுவரை முடிவுகள் சேமிக்கப்படவில்லை', expertTitle: 'வேளாண் நிபுணர் தகவல்',
    expertSub: 'பயிர் திட்டமிடல், மண், பாசனம், பூச்சிகள், நோய், வானிலை மற்றும் அறுவடைக்குப் பிந்தைய மேலாண்மை வழிகாட்டுதல்.',
    consultants: 'நிபுணர் ஆலோசனைகள்', searchTopics: 'வேளாண் தலைப்புகளைத் தேடுங்கள்', open: 'திற', close: 'மூடு',
    settingsTitle: 'வலைத்தள அமைப்புகள்', api: 'API முகவரி', spline: 'Spline காட்சி', readyApi: 'தயார்', ask: 'கிருஷி AI-யிடம் கேளுங்கள்',
    askHint: 'பயிர்கள், நோய், பாசனம், மண் அல்லது விவசாய மேலாண்மை பற்றி கேளுங்கள்…', send: 'அனுப்பு', scanAgain: 'மற்றொரு பயிரை ஸ்கேன் செய்யுங்கள்',
    language: 'மொழி', unknown: 'தெரியாதது', weatherNoMatch: 'பொருந்தும் இடம் எதுவும் கிடைக்கவில்லை.', weatherResolveError: 'இந்த இடத்தை கண்டறிய முடியவில்லை.',
    weatherForecastError: 'வானிலை தரவை ஏற்ற முடியவில்லை.', weatherNetworkError: 'நெட்வொர்க் இணைப்பு இல்லை.', weatherResolving: 'இடம் கண்டறியப்படுகிறது…',
    weatherLoading: 'வானிலை ஏற்றப்படுகிறது…', chooseLocation: 'பொருந்தும் இடத்தைத் தேர்ந்தெடுக்கவும்', locationPermissionDenied: 'இருப்பிட அனுமதி மறுக்கப்பட்டது.',
    locationUnavailable: 'இருப்பிடம் கிடைக்கவில்லை. சாதன இருப்பிட சேவையைச் சரிபார்த்து மீண்டும் முயற்சிக்கவும்.', locationTimeout: 'இருப்பிட கோரிக்கை நேரம் முடிந்தது.',
    locationLoading: 'உங்கள் இருப்பிடத்திற்கான வானிலை ஏற்றப்படுகிறது…', useSearch: 'வானிலையை ஏற்ற மேலே தேடுங்கள்.', humidity: 'ஈரப்பதம்', rain: 'மழை', cloud: 'மேகம்', wind: 'காற்று'
  },
  te: {
    home: 'హోమ్', scanner: 'స్కానర్', weather: 'వాతావరణం', history: 'చరిత్ర', experts: 'వ్యవసాయ నిపుణులు', chat: 'కృషి AI',
    settings: 'సెట్టింగ్‌లు', heroEyebrow: 'వ్యవసాయం కోసం ఫీల్డ్-రెడీ AI', heroTitle1: 'పంటను చూడండి.', heroTitle2: 'ప్రమాదాన్ని అర్థం చేసుకోండి.',
    heroText: 'పంట ఆకు చిత్రంతో వ్యాధి సమాచారం, నమ్మక స్థాయి, తీవ్రత, హెచ్చరికలు మరియు తదుపరి చర్యలను తెలుసుకోండి.',
    scan: 'పంటను స్కాన్ చేయండి', talk: 'కృషి AIతో మాట్లాడండి', online: 'ఆన్‌లైన్ AI', offline: 'ఆఫ్‌లైన్ సిద్ధం', languages: '10 భాషలు',
    classes: 'పంట తరగతులు', vision: 'విజన్ ఇన్‌పుట్', field: 'పొల వినియోగం', diagnostics: 'పంట నిర్ధారణ', fromImage: 'చిత్రం నుండి', fieldAction: 'పొల చర్య వరకు',
    imageInput: 'చిత్ర ఇన్‌పుట్', drop: 'పంట చిత్రాన్ని ఇక్కడ వేయండి', uploadHint: 'JPG లేదా PNG · స్పష్టమైన ఆకు చిత్రం ఉత్తమం',
    analyze: 'AIతో విశ్లేషించండి', analyzing: 'విశ్లేషణ జరుగుతోంది…', offlineNote: 'ఆఫ్‌లైన్ భద్రత. మీ మొబైల్ TFLite ఫ్లో మార్చబడలేదు.',
    output: 'నిర్ధారణ ఫలితం', ready: 'సిద్ధంగా ఉంది', readyText: 'పంట చిత్రాన్ని అప్‌లోడ్ చేసి నిర్ధారణ, నమ్మక స్థాయి మరియు చర్య ప్రణాళికను చూడండి.',
    diagnosis: 'AI నిర్ధారణ', confidence: 'నమ్మక స్థాయి', status: 'స్థితి', alert: 'ప్రభుత్వ హెచ్చరిక', description: 'వివరణ',
    treatment: 'చికిత్స', prevention: 'నివారణ', farmerAction: 'రైతు చర్య', weatherTitle: 'వాతావరణ అంచనా',
    weatherSub: 'పొలానికి 7 రోజుల వాతావరణ సమాచారం.', searchCity: 'ప్రపంచంలో ఏ నగరం లేదా ప్రదేశాన్నైనా వెతకండి',
    useLocation: 'నా స్థానాన్ని ఉపయోగించండి', forecast: '7 రోజుల అంచనా', agriSummary: 'వ్యవసాయ సారాంశం',
    historyTitle: 'సేవ్ చేసిన నిర్ధారణ చరిత్ర', historySub: 'ఈ బ్రౌజర్‌లో సేవ్ చేసిన గత AI ఫలితాలు.',
    clear: 'చరిత్రను క్లియర్ చేయండి', noHistory: 'ఇంకా ఫలితాలు సేవ్ కాలేదు', expertTitle: 'వ్యవసాయ నిపుణుల సమాచారం',
    expertSub: 'పంట ప్రణాళిక, నేల, నీటిపారుదల, పురుగులు, వ్యాధి, వాతావరణం మరియు పంట అనంతర నిర్వహణకు మార్గదర్శకత్వం.',
    consultants: 'నిపుణుల సలహాలు', searchTopics: 'వ్యవసాయ అంశాలను వెతకండి', open: 'తెరవండి', close: 'మూసివేయండి',
    settingsTitle: 'వెబ్‌సైట్ సెట్టింగ్‌లు', api: 'API చిరునామా', spline: 'Spline దృశ్యం', readyApi: 'సిద్ధం', ask: 'కృషి AIని అడగండి',
    askHint: 'పంటలు, వ్యాధి, నీటిపారుదల, నేల లేదా వ్యవసాయ నిర్వహణ గురించి అడగండి…', send: 'పంపండి', scanAgain: 'మరొక పంటను స్కాన్ చేయండి',
    language: 'భాష', unknown: 'తెలియదు', weatherNoMatch: 'సరిపోలే ప్రదేశం కనబడలేదు.', weatherResolveError: 'ఈ ప్రదేశాన్ని గుర్తించలేకపోయాము.',
    weatherForecastError: 'వాతావరణ డేటాను లోడ్ చేయలేకపోయాము.', weatherNetworkError: 'నెట్‌వర్క్ కనెక్షన్ అందుబాటులో లేదు.', weatherResolving: 'ప్రదేశాన్ని కనుగొంటోంది…',
    weatherLoading: 'వాతావరణం లోడ్ అవుతోంది…', chooseLocation: 'సరిపోలే ప్రదేశాన్ని ఎంచుకోండి', locationPermissionDenied: 'స్థాన అనుమతి నిరాకరించబడింది.',
    locationUnavailable: 'స్థానం అందుబాటులో లేదు. పరికర స్థాన సేవలను తనిఖీ చేసి మళ్లీ ప్రయత్నించండి.', locationTimeout: 'స్థాన అభ్యర్థన సమయం ముగిసింది.',
    locationLoading: 'మీ స్థానానికి వాతావరణం లోడ్ అవుతోంది…', useSearch: 'వాతావరణం లోడ్ చేయడానికి పైన వెతకండి.', humidity: 'తేమ', rain: 'వర్షం', cloud: 'మేఘం', wind: 'గాలి'
  },
  kn: {
    home: 'ಮುಖಪುಟ', scanner: 'ಸ್ಕ್ಯಾನರ್', weather: 'ಹವಾಮಾನ', history: 'ಇತಿಹಾಸ', experts: 'ಕೃಷಿ ತಜ್ಞರು', chat: 'ಕೃಷಿ AI',
    settings: 'ಸೆಟ್ಟಿಂಗ್‌ಗಳು', heroEyebrow: 'ಕೃಷಿಗಾಗಿ ಕ್ಷೇತ್ರ-ಸಿದ್ಧ AI', heroTitle1: 'ಬೆಳೆಯನ್ನು ನೋಡಿ.', heroTitle2: 'ಅಪಾಯವನ್ನು ಅರ್ಥಮಾಡಿಕೊಳ್ಳಿ.',
    heroText: 'ಬೆಳೆ ಎಲೆಯ ಚಿತ್ರದಿಂದ ರೋಗದ ಮಾಹಿತಿ, ವಿಶ್ವಾಸ, ತೀವ್ರತೆ, ಎಚ್ಚರಿಕೆ ಮತ್ತು ಮುಂದಿನ ಕ್ರಮಗಳನ್ನು ತಿಳಿಯಿರಿ.',
    scan: 'ಬೆಳೆಯನ್ನು ಸ್ಕ್ಯಾನ್ ಮಾಡಿ', talk: 'ಕೃಷಿ AI ಜೊತೆ ಮಾತನಾಡಿ', online: 'ಆನ್‌ಲೈನ್ AI', offline: 'ಆಫ್‌ಲೈನ್ ಸಿದ್ಧ', languages: '10 ಭಾಷೆಗಳು',
    classes: 'ಬೆಳೆ ವರ್ಗಗಳು', vision: 'ವಿಷನ್ ಇನ್‌ಪುಟ್', field: 'ಕ್ಷೇತ್ರ ಬಳಕೆ', diagnostics: 'ಬೆಳೆ ನಿರ್ಣಯ', fromImage: 'ಚಿತ್ರದಿಂದ', fieldAction: 'ಕ್ಷೇತ್ರ ಕ್ರಮದವರೆಗೆ',
    imageInput: 'ಚಿತ್ರ ಇನ್‌ಪುಟ್', drop: 'ಬೆಳೆಯ ಚಿತ್ರವನ್ನು ಇಲ್ಲಿ ಹಾಕಿ', uploadHint: 'JPG ಅಥವಾ PNG · ಸ್ಪಷ್ಟ ಎಲೆಯ ಚಿತ್ರ ಉತ್ತಮ',
    analyze: 'AI ಮೂಲಕ ವಿಶ್ಲೇಷಿಸಿ', analyzing: 'ವಿಶ್ಲೇಷಿಸಲಾಗುತ್ತಿದೆ…', offlineNote: 'ಆಫ್‌ಲೈನ್ ಸುರಕ್ಷತೆ. ನಿಮ್ಮ ಮೊಬೈಲ್ TFLite ಫ್ಲೋ ಬದಲಾಗಿಲ್ಲ.',
    output: 'ನಿರ್ಣಯ ಫಲಿತಾಂಶ', ready: 'ಸಿದ್ಧವಾಗಿದೆ', readyText: 'ಬೆಳೆಯ ಚಿತ್ರವನ್ನು ಅಪ್‌ಲೋಡ್ ಮಾಡಿ ಮತ್ತು ನಿರ್ಣಯ, ವಿಶ್ವಾಸ ಹಾಗೂ ಕ್ರಮ ಯೋಜನೆಯನ್ನು ನೋಡಿ.',
    diagnosis: 'AI ನಿರ್ಣಯ', confidence: 'ವಿಶ್ವಾಸ', status: 'ಸ್ಥಿತಿ', alert: 'ಸರ್ಕಾರಿ ಎಚ್ಚರಿಕೆ', description: 'ವಿವರಣೆ',
    treatment: 'ಚಿಕಿತ್ಸೆ', prevention: 'ತಡೆಗಟ್ಟುವಿಕೆ', farmerAction: 'ರೈತರ ಕ್ರಮ', weatherTitle: 'ಹವಾಮಾನ ಮುನ್ಸೂಚನೆ',
    weatherSub: 'ಕ್ಷೇತ್ರಕ್ಕಾಗಿ 7 ದಿನಗಳ ಹವಾಮಾನ ಮಾಹಿತಿ.', searchCity: 'ವಿಶ್ವದ ಯಾವುದೇ ನಗರ ಅಥವಾ ಸ್ಥಳವನ್ನು ಹುಡುಕಿ',
    useLocation: 'ನನ್ನ ಸ್ಥಳ ಬಳಸಿ', forecast: '7 ದಿನಗಳ ಮುನ್ಸೂಚನೆ', agriSummary: 'ಕೃಷಿ ಸಾರಾಂಶ',
    historyTitle: 'ಉಳಿಸಿದ ನಿರ್ಣಯ ಇತಿಹಾಸ', historySub: 'ಈ ಬ್ರೌಸರ್‌ನಲ್ಲಿ ಉಳಿಸಿದ ಹಿಂದಿನ AI ಫಲಿತಾಂಶಗಳು.',
    clear: 'ಇತಿಹಾಸ ತೆರವುಗೊಳಿಸಿ', noHistory: 'ಇನ್ನೂ ಯಾವುದೇ ಫಲಿತಾಂಶ ಉಳಿಸಲಾಗಿಲ್ಲ', expertTitle: 'ಕೃಷಿ ತಜ್ಞರ ಮಾಹಿತಿ',
    expertSub: 'ಬೆಳೆ ಯೋಜನೆ, ಮಣ್ಣು, ನೀರಾವರಿ, ಕೀಟ, ರೋಗ, ಹವಾಮಾನ ಮತ್ತು ಕೊಯ್ಲಿನ ನಂತರದ ನಿರ್ವಹಣೆಗೆ ಮಾರ್ಗದರ್ಶನ.',
    consultants: 'ತಜ್ಞ ಸಲಹೆಗಾರರು', searchTopics: 'ಕೃಷಿ ವಿಷಯಗಳನ್ನು ಹುಡುಕಿ', open: 'ತೆರೆಯಿರಿ', close: 'ಮುಚ್ಚಿ',
    settingsTitle: 'ವೆಬ್‌ಸೈಟ್ ಸೆಟ್ಟಿಂಗ್‌ಗಳು', api: 'API ವಿಳಾಸ', spline: 'Spline ದೃಶ್ಯ', readyApi: 'ಸಿದ್ಧ', ask: 'ಕೃಷಿ AIಗೆ ಕೇಳಿ',
    askHint: 'ಬೆಳೆಗಳು, ರೋಗ, ನೀರಾವರಿ, ಮಣ್ಣು ಅಥವಾ ಕೃಷಿ ನಿರ್ವಹಣೆ ಬಗ್ಗೆ ಕೇಳಿ…', send: 'ಕಳುಹಿಸಿ', scanAgain: 'ಮತ್ತೊಂದು ಬೆಳೆಯನ್ನು ಸ್ಕ್ಯಾನ್ ಮಾಡಿ',
    language: 'ಭಾಷೆ', unknown: 'ಅಜ್ಞಾತ', weatherNoMatch: 'ಹೊಂದಾಣಿಕೆಯ ಸ್ಥಳ ಕಂಡುಬಂದಿಲ್ಲ.', weatherResolveError: 'ಈ ಸ್ಥಳವನ್ನು ಗುರುತಿಸಲಾಗಲಿಲ್ಲ.',
    weatherForecastError: 'ಹವಾಮಾನ ಡೇಟಾವನ್ನು ಲೋಡ್ ಮಾಡಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ.', weatherNetworkError: 'ನೆಟ್‌ವರ್ಕ್ ಸಂಪರ್ಕ ಲಭ್ಯವಿಲ್ಲ.', weatherResolving: 'ಸ್ಥಳ ಹುಡುಕಲಾಗುತ್ತಿದೆ…',
    weatherLoading: 'ಹವಾಮಾನ ಲೋಡ್ ಆಗುತ್ತಿದೆ…', chooseLocation: 'ಹೊಂದಾಣಿಕೆಯ ಸ್ಥಳವನ್ನು ಆಯ್ಕೆಮಾಡಿ', locationPermissionDenied: 'ಸ್ಥಳ ಅನುಮತಿ ನಿರಾಕರಿಸಲಾಗಿದೆ.',
    locationUnavailable: 'ಸ್ಥಳ ಲಭ್ಯವಿಲ್ಲ. ಸಾಧನದ ಸ್ಥಳ ಸೇವೆಗಳನ್ನು ಪರಿಶೀಲಿಸಿ ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.', locationTimeout: 'ಸ್ಥಳ ವಿನಂತಿಯ ಸಮಯ ಮುಗಿದಿದೆ.',
    locationLoading: 'ನಿಮ್ಮ ಸ್ಥಳದ ಹವಾಮಾನ ಲೋಡ್ ಆಗುತ್ತಿದೆ…', useSearch: 'ಹವಾಮಾನ ಲೋಡ್ ಮಾಡಲು ಮೇಲೆ ಹುಡುಕಿ.', humidity: 'ತೇವಾಂಶ', rain: 'ಮಳೆ', cloud: 'ಮೋಡ', wind: 'ಗಾಳಿ'
  },
  ml: {
    home: 'ഹോം', scanner: 'സ്കാനർ', weather: 'കാലാവസ്ഥ', history: 'ചരിത്രം', experts: 'കൃഷി വിദഗ്ധർ', chat: 'കൃഷി AI',
    settings: 'ക്രമീകരണങ്ങൾ', heroEyebrow: 'കൃഷിക്കായുള്ള ഫീൽഡ്-റെഡി AI', heroTitle1: 'വിള കാണുക.', heroTitle2: 'അപകടസാധ്യത മനസ്സിലാക്കുക.',
    heroText: 'വിളയുടെ ഇലയുടെ ചിത്രത്തിൽ നിന്ന് രോഗവിവരം, വിശ്വാസ്യത, തീവ്രത, മുന്നറിയിപ്പുകൾ, അടുത്ത നടപടികൾ എന്നിവ അറിയുക.',
    scan: 'വിള സ്കാൻ ചെയ്യുക', talk: 'കൃഷി AIയോട് സംസാരിക്കുക', online: 'ഓൺലൈൻ AI', offline: 'ഓഫ്‌ലൈൻ തയ്യാറാണ്', languages: '10 ഭാഷകൾ',
    classes: 'വിള വിഭാഗങ്ങൾ', vision: 'വിഷൻ ഇൻപുട്ട്', field: 'കൃഷിയിട ഉപയോഗം', diagnostics: 'വിള രോഗനിർണയം', fromImage: 'ചിത്രത്തിൽ നിന്ന്', fieldAction: 'കൃഷിയിട നടപടിയിലേക്ക്',
    imageInput: 'ചിത്ര ഇൻപുട്ട്', drop: 'വിളയുടെ ചിത്രം ഇവിടെ ഇടുക', uploadHint: 'JPG അല്ലെങ്കിൽ PNG · വ്യക്തമായ ഇലയുടെ ചിത്രം മികച്ചത്',
    analyze: 'AI ഉപയോഗിച്ച് വിശകലനം ചെയ്യുക', analyzing: 'വിശകലനം നടക്കുന്നു…', offlineNote: 'ഓഫ്‌ലൈൻ സുരക്ഷ. നിങ്ങളുടെ മൊബൈൽ TFLite ഫ്ലോ മാറ്റമില്ലാതെ തുടരുന്നു.',
    output: 'രോഗനിർണയ ഫലം', ready: 'തയ്യാറാണ്', readyText: 'വിളയുടെ ചിത്രം അപ്‌ലോഡ് ചെയ്ത് രോഗനിർണയം, വിശ്വാസ്യത, പ്രവർത്തന പദ്ധതി എന്നിവ കാണുക.',
    diagnosis: 'AI രോഗനിർണയം', confidence: 'വിശ്വാസ്യത', status: 'നില', alert: 'സർക്കാർ മുന്നറിയിപ്പ്', description: 'വിവരണം',
    treatment: 'ചികിത്സ', prevention: 'പ്രതിരോധം', farmerAction: 'കർഷക നടപടി', weatherTitle: 'കാലാവസ്ഥാ പ്രവചനം',
    weatherSub: 'കൃഷിയിടത്തിനായുള്ള 7 ദിവസത്തെ കാലാവസ്ഥാ വിവരങ്ങൾ.', searchCity: 'ലോകമെമ്പാടുമുള്ള നഗരം അല്ലെങ്കിൽ സ്ഥലം തിരയുക',
    useLocation: 'എന്റെ സ്ഥലം ഉപയോഗിക്കുക', forecast: '7 ദിവസത്തെ പ്രവചനം', agriSummary: 'കാർഷിക സംഗ്രഹം',
    historyTitle: 'സംരക്ഷിച്ച രോഗനിർണയ ചരിത്രം', historySub: 'ഈ ബ്രൗസറിൽ സംരക്ഷിച്ച മുൻ AI ഫലങ്ങൾ.',
    clear: 'ചരിത്രം മായ്ക്കുക', noHistory: 'ഇതുവരെ ഫലങ്ങളൊന്നും സംരക്ഷിച്ചിട്ടില്ല', expertTitle: 'കൃഷി വിദഗ്ധ വിവരങ്ങൾ',
    expertSub: 'വിള ആസൂത്രണം, മണ്ണ്, ജലസേചനം, കീടങ്ങൾ, രോഗങ്ങൾ, കാലാവസ്ഥ, വിളവെടുപ്പിന് ശേഷമുള്ള പരിപാലനം എന്നിവയ്ക്കുള്ള മാർഗനിർദ്ദേശം.',
    consultants: 'വിദഗ്ധ ഉപദേശകർ', searchTopics: 'കാർഷിക വിഷയങ്ങൾ തിരയുക', open: 'തുറക്കുക', close: 'അടയ്ക്കുക',
    settingsTitle: 'വെബ്‌സൈറ്റ് ക്രമീകരണങ്ങൾ', api: 'API വിലാസം', spline: 'Spline ദൃശ്യം', readyApi: 'തയ്യാർ', ask: 'കൃഷി AIയോട് ചോദിക്കുക',
    askHint: 'വിളകൾ, രോഗം, ജലസേചനം, മണ്ണ് അല്ലെങ്കിൽ കൃഷി മാനേജ്മെന്റ് എന്നിവയെക്കുറിച്ച് ചോദിക്കുക…', send: 'അയയ്ക്കുക', scanAgain: 'മറ്റൊരു വിള സ്കാൻ ചെയ്യുക',
    language: 'ഭാഷ', unknown: 'അജ്ഞാതം', weatherNoMatch: 'പൊരുത്തപ്പെടുന്ന സ്ഥലം കണ്ടെത്തിയില്ല.', weatherResolveError: 'ഈ സ്ഥലം കണ്ടെത്താനായില്ല.',
    weatherForecastError: 'കാലാവസ്ഥാ ഡാറ്റ ലോഡ് ചെയ്യാനായില്ല.', weatherNetworkError: 'നെറ്റ്‌വർക്ക് കണക്ഷൻ ലഭ്യമല്ല.', weatherResolving: 'സ്ഥലം കണ്ടെത്തുന്നു…',
    weatherLoading: 'കാലാവസ്ഥ ലോഡ് ചെയ്യുന്നു…', chooseLocation: 'പൊരുത്തപ്പെടുന്ന സ്ഥലം തിരഞ്ഞെടുക്കുക', locationPermissionDenied: 'ലൊക്കേഷൻ അനുമതി നിരസിച്ചു.',
    locationUnavailable: 'ലൊക്കേഷൻ ലഭ്യമല്ല. ഉപകരണ ലൊക്കേഷൻ സേവനം പരിശോധിച്ച് വീണ്ടും ശ്രമിക്കുക.', locationTimeout: 'ലൊക്കേഷൻ അഭ്യർത്ഥനയുടെ സമയം കഴിഞ്ഞു.',
    locationLoading: 'നിങ്ങളുടെ സ്ഥലത്തെ കാലാവസ്ഥ ലോഡ് ചെയ്യുന്നു…', useSearch: 'കാലാവസ്ഥ ലോഡ് ചെയ്യാൻ മുകളിൽ തിരയുക.', humidity: 'ഈർപ്പം', rain: 'മഴ', cloud: 'മേഘം', wind: 'കാറ്റ്'
  }

};

function repairMojibake(value) {
  if (typeof value !== 'string' || !/[ÃÂâðà¤à¦àªà®à°à²à´]/.test(value)) return value;
  const cp1252 = { 0x20ac: 0x80, 0x201a: 0x82, 0x192: 0x83, 0x201e: 0x84, 0x2026: 0x85, 0x2020: 0x86, 0x2021: 0x87, 0x2c6: 0x88, 0x2030: 0x89, 0x160: 0x8a, 0x2039: 0x8b, 0x152: 0x8c, 0x17d: 0x8e, 0x2018: 0x91, 0x2019: 0x92, 0x201c: 0x93, 0x201d: 0x94, 0x2022: 0x95, 0x2013: 0x96, 0x2014: 0x97, 0x2dc: 0x98, 0x2122: 0x99, 0x161: 0x9a, 0x203a: 0x9b, 0x153: 0x9c, 0x17e: 0x9e, 0x178: 0x9f };
  try {
    const bytes = Uint8Array.from(Array.from(value, (char) => {
      const code = char.charCodeAt(0);
      return cp1252[code] ?? (code <= 255 ? code : 0);
    }));
    return new TextDecoder('utf-8', { fatal: true }).decode(bytes);
  } catch {
    return value;
  }
}

function repairMojibakeDeep(value) {
  if (typeof value === 'string') return repairMojibake(value);
  if (Array.isArray(value)) return value.forEach(repairMojibakeDeep);
  if (value && typeof value === 'object') Object.keys(value).forEach((key) => { value[key] = repairMojibakeDeep(value[key]); });
  return value;
}

repairMojibakeDeep(T);

const tr = (lang, key) => T[lang]?.[key] || T.en[key] || key;

const EXPERT_TOPICS = [
  { title: 'Crop Planning', icon: 'ðŸŒ±', summary: 'Choose a crop plan using season, soil, water and local market conditions.', sections: [
    ['Before sowing', 'Select a locally suitable variety. Check seed quality, expected crop duration, water availability and the previous crop. Prefer a soil test when available.'],
    ['Field practice', 'Prepare a clean seedbed, maintain suitable spacing and avoid planting too early or too late for the local season. Keep records of sowing date, seed lot and field observations.']
  ] },
  { title: 'Irrigation & Water Management', icon: 'ðŸ’§', summary: 'Use water according to crop stage, soil moisture and weather rather than a fixed routine.', sections: [
    ['Practical approach', 'Check soil moisture near the root zone before irrigating. Irrigation need changes with crop stage, soil type, temperature, wind and rainfall.'],
    ['Avoid losses', 'Prevent standing water unless the crop specifically requires it. Keep drainage channels clear and prefer efficient irrigation methods where practical.']
  ] },
  { title: 'Soil & Plant Nutrition', icon: 'ðŸ§ª', summary: 'Build soil fertility through testing, balanced nutrients and organic matter.', sections: [
    ['Nutrient planning', 'Use soil-test results and the crop recommendation for nutrient planning. Do not assume that more fertilizer always means more yield.'],
    ['Good practice', 'Split nitrogen where the crop and local recommendation support it, keep nutrients away from direct seed contact when required, and correct pH or micronutrient issues based on testing.']
  ] },
  { title: 'Pest Management', icon: 'ðŸ›', summary: 'Use integrated pest management instead of spraying automatically.', sections: [
    ['Scout first', 'Inspect leaves, stems, flowers and the underside of leaves regularly. Record the pest, affected area, crop stage and whether beneficial insects are present.'],
    ['Treatment decision', 'Use non-chemical measures first when effective. If a pesticide is genuinely needed, identify the pest and crop correctly, use only a currently registered product for that use, and follow its label.']
  ] },
  { title: 'Disease Management', icon: 'ðŸ©º', summary: 'Confirm symptoms and field pattern before deciding on treatment.', sections: [
    ['Diagnosis', 'Check the whole plant, symptom pattern, crop age, recent rain or humidity, soil moisture and how the problem is spreading. A single low-confidence AI image should not be treated as a confirmed diagnosis.'],
    ['Action', 'Remove or manage severely affected material when appropriate, improve sanitation and airflow, and avoid unnecessary leaf wetness. For chemical treatment, follow the current label and local agricultural or KVK advice.']
  ] },
  { title: 'Weather-Based Farm Decisions', icon: 'â˜ï¸', summary: 'Use short-term weather information to plan irrigation, spraying and field work.', sections: [
    ['Before rain', 'If substantial rain is expected, reassess irrigation and avoid unnecessary foliar applications immediately before rainfall.'],
    ['During severe weather', 'Pause field operations during lightning or dangerous storms. Protect seedlings, drainage, structures and harvested produce according to the expected hazard.']
  ] },
  { title: 'Harvest & Storage', icon: 'ðŸ“¦', summary: 'Good harvesting and storage practices protect quality and reduce losses.', sections: [
    ['Harvest', 'Harvest at the crop-appropriate maturity and avoid unnecessary mechanical injury. Keep harvested produce clean and away from contaminated plant material.'],
    ['Storage', 'Dry grains to a safe storage condition, keep stores clean and ventilated, monitor for moisture and pests, and use approved storage practices for the commodity.']
  ] },
  { title: 'Farm Records & Market Planning', icon: 'ðŸ“Š', summary: 'Simple records help farmers compare costs, yield and crop decisions.', sections: [
    ['Record', 'Track sowing date, variety, inputs, irrigation, pest or disease observations, harvest quantity and major expenses.'],
    ['Market decision', 'Compare local market conditions, quality requirements, transport cost and expected price before choosing when and where to sell.']
  ] }
];

const consultantFallback = [
  ['ICAR Agriculture Referral', 'Agricultural extension and expert referral', 'https://icar.gov.in/'],
  ['Krishi Vigyan Kendra (KVK)', 'Local crop and farm advisory through ICAR network', 'https://kvk.icar.gov.in/']
];

function weatherCondition(code, lang) {
  const map = {
    en: { 0: 'Clear sky', 1: 'Mainly clear', 2: 'Partly cloudy', 3: 'Overcast', 45: 'Fog', 48: 'Rime fog', 51: 'Drizzle', 53: 'Drizzle', 55: 'Heavy drizzle', 61: 'Light rain', 63: 'Rain', 65: 'Heavy rain', 80: 'Rain showers', 81: 'Rain showers', 82: 'Heavy showers', 95: 'Thunderstorm' },
    hi: { 0: 'à¤¸à¤¾à¤« à¤†à¤¸à¤®à¤¾à¤¨', 1: 'à¤®à¥à¤–à¥à¤¯à¤¤à¤ƒ à¤¸à¤¾à¤«', 2: 'à¤†à¤‚à¤¶à¤¿à¤• à¤¬à¤¾à¤¦à¤²', 3: 'à¤˜à¤¨à¥‡ à¤¬à¤¾à¤¦à¤²', 45: 'à¤•à¥‹à¤¹à¤°à¤¾', 48: 'à¤•à¥‹à¤¹à¤°à¤¾', 51: 'à¤¹à¤²à¥à¤•à¥€ à¤«à¥à¤¹à¤¾à¤°', 53: 'à¤«à¥à¤¹à¤¾à¤°', 55: 'à¤¤à¥‡à¤œà¤¼ à¤«à¥à¤¹à¤¾à¤°', 61: 'à¤¹à¤²à¥à¤•à¥€ à¤¬à¤¾à¤°à¤¿à¤¶', 63: 'à¤¬à¤¾à¤°à¤¿à¤¶', 65: 'à¤¤à¥‡à¤œà¤¼ à¤¬à¤¾à¤°à¤¿à¤¶', 80: 'à¤¬à¤¾à¤°à¤¿à¤¶ à¤•à¥€ à¤¬à¥Œà¤›à¤¾à¤°', 81: 'à¤¬à¤¾à¤°à¤¿à¤¶ à¤•à¥€ à¤¬à¥Œà¤›à¤¾à¤°', 82: 'à¤¤à¥‡à¤œà¤¼ à¤¬à¥Œà¤›à¤¾à¤°', 95: 'à¤†à¤‚à¤§à¥€-à¤¤à¥‚à¤«à¤¾à¤¨' }
  };
  const table = map[lang] || map.en;
  const value = table[code];
  if (value) return repairMojibake(value);
  if (code === 56 || code === 57) return 'Freezing drizzle';
  if (code === 66 || code === 67) return 'Freezing rain';
  if (code === 71 || code === 73 || code === 75) return 'Snowfall';
  if (code === 77) return 'Snow grains';
  if (code === 85 || code === 86) return 'Snow showers';
  if (code === 96 || code === 99) return 'Thunderstorm with hail';
  return 'Weather';
}

function weatherIcon(code) {
  if (code === 0) return Sun;
  if (code >= 95) return AlertTriangle;
  if ([71, 73, 75, 77, 85, 86].includes(code)) return CloudSnow;
  if (code >= 51 && code <= 82) return CloudRain;
  return CloudSun;
}

function formatDay(value) {
  return new Date(value).toLocaleDateString('en-IN', { weekday: 'short', day: 'numeric', month: 'short' });
}

function AnimatedNumber({ value, suffix = '' }) {
  const nodeRef = useRef(null);
  useEffect(() => {
    const node = nodeRef.current;
    if (!node) return undefined;
    const target = Number(value) || 0;
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      node.textContent = `${Math.round(target)}${suffix}`;
      return undefined;
    }
    let frame = 0;
    const start = performance.now();
    const tick = (now) => {
      const progress = Math.min(1, (now - start) / 700);
      node.textContent = `${Math.round(target * (1 - Math.pow(1 - progress, 3)))}${suffix}`;
      if (progress < 1) frame = requestAnimationFrame(tick);
    };
    node.textContent = `0${suffix}`;
    frame = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(frame);
  }, [value, suffix]);
  return <span ref={nodeRef}>{`${Math.round(Number(value) || 0)}${suffix}`}</span>;
}

function App() {
  const [lang, setLang] = useState(() => localStorage.getItem('krishi_lang') || 'en');
  const [file, setFile] = useState(null);
  const [preview, setPreview] = useState('');
  const [result, setResult] = useState(null);
  const [advice, setAdvice] = useState(null);
  const [loading, setLoading] = useState(false);
  const [history, setHistory] = useState(() => {
    try { return JSON.parse(localStorage.getItem(HISTORY_KEY) || '[]'); } catch { return []; }
  });
  const [weather, setWeather] = useState(null);
  const [weatherCity, setWeatherCity] = useState('');
  const [weatherChoices, setWeatherChoices] = useState([]);
  const [weatherQuery, setWeatherQuery] = useState('');
  const [weatherLoading, setWeatherLoading] = useState(false);
  const [weatherPhase, setWeatherPhase] = useState('');
  const [weatherError, setWeatherError] = useState('');
  const [consultants, setConsultants] = useState([]);
  const [topicQuery, setTopicQuery] = useState('');
  const [topic, setTopic] = useState(null);
  const [chatOpen, setChatOpen] = useState(false);
  const [message, setMessage] = useState('');
  const [chatMessages, setChatMessages] = useState([{ role: 'assistant', text: `${T.en.ask} â€” ${T.en.askHint}` }]);
  const [chatLoading, setChatLoading] = useState(false);
  const [mobileMenu, setMobileMenu] = useState(false);
  const [settings, setSettings] = useState(false);
  const [activeSection, setActiveSection] = useState('top');
  const [splineLoading, setSplineLoading] = useState(true);
  const [splineLoadError, setSplineLoadError] = useState(false);
  const splineViewerRef = useRef(null);
  const [animatedConfidence, setAnimatedConfidence] = useState(0);

  useEffect(() => {
    let active = true;
    import('@splinetool/viewer').catch((error) => {
      console.error('Spline Viewer failed to initialize', error);
      if (active) {
        setSplineLoading(false);
        setSplineLoadError(true);
      }
    });
    return () => { active = false; };
  }, []);

  useEffect(() => {
    const viewer = splineViewerRef.current;
    if (!viewer) return undefined;
    const onLoadStart = () => { setSplineLoading(true); setSplineLoadError(false); };
    const onLoadComplete = () => {
      setSplineLoading(false);
      setSplineLoadError(false);
    };
    const onContextLoss = () => { setSplineLoading(false); setSplineLoadError(true); };
    viewer.addEventListener('load-start', onLoadStart);
    viewer.addEventListener('load-complete', onLoadComplete);
    viewer.addEventListener('context-loss', onContextLoss);

    return () => {
      viewer.removeEventListener('load-start', onLoadStart);
      viewer.removeEventListener('load-complete', onLoadComplete);
      viewer.removeEventListener('context-loss', onContextLoss);

    };
  }, []);

  useEffect(() => {
    if (!result || result.error) {
      setAnimatedConfidence(0);
      return undefined;
    }
    const target = Math.max(0, Math.min(100, Number(result.prediction?.confidence) || 0));
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      setAnimatedConfidence(target);
      return undefined;
    }
    let frame = 0;
    const started = performance.now();
    const animate = (now) => {
      const progress = Math.min(1, (now - started) / 900);
      const eased = 1 - Math.pow(1 - progress, 3);
      setAnimatedConfidence(target * eased);
      if (progress < 1) frame = requestAnimationFrame(animate);
    };
    frame = requestAnimationFrame(animate);
    return () => cancelAnimationFrame(frame);
  }, [result]);

  useEffect(() => {
    localStorage.setItem('krishi_lang', lang);
  }, [lang]);

  useEffect(() => {
    const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    const sections = [...document.querySelectorAll('.hero, .process-strip, .section, footer')];
    if (reduceMotion || !('IntersectionObserver' in window)) {
      sections.forEach((section) => section.classList.add('is-visible'));
    }
    const observer = !reduceMotion && 'IntersectionObserver' in window ? new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add('is-visible');
          observer.unobserve(entry.target);
        }
      });
    }, { threshold: 0.12, rootMargin: '0px 0px -35px 0px' }) : null;
    if (observer) sections.forEach((section) => observer.observe(section));

    const navObserver = 'IntersectionObserver' in window ? new IntersectionObserver((entries) => {
      const current = entries.filter((entry) => entry.isIntersecting).sort((a, b) => b.intersectionRatio - a.intersectionRatio)[0];
      if (current) setActiveSection(current.target.id);
    }, { threshold: [0.05, 0.2, 0.4], rootMargin: '-18% 0px -62% 0px' }) : null;
    ['top', 'scanner', 'weather', 'history', 'experts'].forEach((id) => {
      const target = document.getElementById(id);
      if (target) navObserver?.observe(target);
    });

    let frame = 0;
    const onPointerMove = (event) => {
      if (frame) return;
      frame = window.requestAnimationFrame(() => {
        if (window.matchMedia('(prefers-reduced-motion: reduce)').matches || window.innerWidth <= 1100) {
          frame = 0;
          return;
        }
        const x = (event.clientX / window.innerWidth - 0.5) * 2;
        const y = (event.clientY / window.innerHeight - 0.5) * 2;
        document.documentElement.style.setProperty('--pointer-x', `${x.toFixed(3)}`);
        document.documentElement.style.setProperty('--pointer-y', `${y.toFixed(3)}`);
        frame = 0;
      });
    };
    const onScroll = () => {
      document.querySelector('.topbar')?.classList.toggle('scrolled', window.scrollY > 12);
      const progress = Math.min(1, window.scrollY / Math.max(1, window.innerHeight));
      document.documentElement.style.setProperty('--hero-shift', `${(progress * 16).toFixed(2)}px`);
      document.documentElement.style.setProperty('--hero-scale', `${(1 - progress * 0.025).toFixed(4)}`);
    };
    window.addEventListener('pointermove', onPointerMove, { passive: true });
    window.addEventListener('scroll', onScroll, { passive: true });
    onScroll();
    return () => {
      observer?.disconnect();
      navObserver?.disconnect();
      window.removeEventListener('pointermove', onPointerMove);
      window.removeEventListener('scroll', onScroll);
      if (frame) window.cancelAnimationFrame(frame);
    };
  }, []);

  useEffect(() => {
    fetch(`${API}/api/consultants`)
      .then((response) => response.json())
      .then((data) => {
        if (data?.success && Array.isArray(data.consultants)) setConsultants(data.consultants);
      })
      .catch(() => {});
  }, []);

  const text = (key) => tr(lang, key);
  const filteredTopics = useMemo(() => {
    const q = topicQuery.trim().toLowerCase();
    if (!q) return EXPERT_TOPICS;
    return EXPERT_TOPICS.filter((item) => `${item.title} ${item.summary}`.toLowerCase().includes(q));
  }, [topicQuery]);

  function scrollToId(id) {
    document.getElementById(id)?.scrollIntoView({ behavior: 'smooth', block: 'start' });
    setMobileMenu(false);
  }

  function handlePick(event) {
    const selected = event.target.files?.[0];
    if (!selected) return;
    setFile(selected);
    setPreview(URL.createObjectURL(selected));
    setResult(null);
    setAdvice(null);
  }

  async function analyze() {
    if (!file || loading) return;
    setLoading(true);
    setResult(null);
    setAdvice(null);
    try {
      const formData = new FormData();
      formData.append('image', file);
      const response = await fetch(`${API}/api/ai-vision`, { method: 'POST', body: formData });
      let data;
      try { data = await response.json(); } catch { throw new Error('Prediction service returned an unreadable response'); }
      if (!response.ok || data.success === false) throw new Error(data.error || 'Prediction failed');

      console.log('[KRISHI DEBUG] RAW JSON:', JSON.stringify(data, null, 2)); console.log('[KRISHI DEBUG] FILE:', file?.name); console.log('[KRISHI DEBUG] PREDICTION JSON:', JSON.stringify(data.prediction, null, 2)); const vision = data.vision || {};
    const prediction = vision.disease ? { class_name: vision.disease, crop: vision.crop || 'crop', confidence: Number(vision.confidence || 0), severity: Number(vision.confidence || 0) >= 80 ? 'high' : Number(vision.confidence || 0) >= 60 ? 'medium' : 'low', status: 'gemini_visual_assessment', diagnosis_message: vision.observations || vision.reason || 'Gemini visual assessment' } : (data.prediction || data.result?.prediction || data.result || {});
      if (!prediction.class_name && !prediction.disease && !prediction.label) {
        throw new Error('Prediction response did not include a diagnosis');
      }
      let adviceData = null;
      try {
        const geminiQuestion = `Using the Gemini Vision assessment below, give the farmer a practical, safe action plan for this crop.
Return ONLY these four sections in English/Hindi according to the selected language:
DESCRIPTION:
TREATMENT:
PREVENTION:
FARMER ACTION:

Do not claim the diagnosis is certain. Do not invent pesticide/fungicide doses or unsupported product names. For chemical treatment, say to use only a currently registered product for the identified crop/disease and follow the label/local agricultural guidance.

Crop: ${prediction.crop || data.crop || 'crop'}
Disease: ${prediction.class_name || prediction.disease || prediction.label || 'unknown'}
Gemini confidence: ${Number(prediction.confidence || 0)}%
Visible observations: ${vision.observations || 'not provided'}
Gemini reason: ${vision.reason || 'not provided'}`;

        const adviceResponse = await fetch(`${API}/api/chat`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            message: geminiQuestion,
            language: lang,
            context: {
              crop: prediction.crop || data.crop || 'crop',
              disease: prediction.class_name || prediction.disease || prediction.label || 'unknown',
              confidence: prediction.confidence || 0
            },
            history: []
          })
        });

        const adviceJson = await adviceResponse.json();

        if (adviceResponse.ok && adviceJson.source === 'gemini_ai') {
          const reply = String(adviceJson.reply || '').replace(/\\r/g, '');
          const extractSection = (label, nextLabels) => {
            const next = nextLabels.length
              ? nextLabels.join('|')
              : '$';
            const re = new RegExp(`(?:^|\\n)\\s*\\**\\s*${label}\\s*\\**\\s*:?\\s*([\\s\\S]*?)(?=\\n\\s*\\**\\s*(?:${next})\\s*\\**\\s*:?|$)`, 'i');
            const match = reply.match(re);
            return match ? match[1].trim() : '';
          };

          adviceData = {
            description: extractSection('DESCRIPTION', ['TREATMENT', 'PREVENTION', 'FARMER ACTION']),
            treatment: extractSection('TREATMENT', ['PREVENTION', 'FARMER ACTION']),
            prevention: extractSection('PREVENTION', ['FARMER ACTION']),
            farmer_action: extractSection('FARMER ACTION', [])
          };

          if (!adviceData.description && !adviceData.treatment && !adviceData.prevention && !adviceData.farmer_action) {
            adviceData.description = reply;
          }

          setAdvice(adviceData);
        }
      } catch (error) {
        console.warn('[KRISHI MOBILE] Gemini advice unavailable:', error);
      }

      data.prediction = prediction;
      setResult(data);
      const historyItem = {
        id: crypto.randomUUID ? crypto.randomUUID() : String(Date.now()),
        timestamp: new Date().toISOString(),
        filename: file.name,
        diagnosis: prediction.class_name || 'Unknown',
        confidence: Number(prediction.confidence || 0),
        severity: prediction.severity || 'unknown',
        status: prediction.status || '',
        governmentAlert: data.government_alert || null,
        crop: prediction.crop || data.crop || '',
        advice: adviceData
      };
      setHistory((previous) => {
        const next = [historyItem, ...previous].slice(0, 50);
        localStorage.setItem(HISTORY_KEY, JSON.stringify(next));
        return next;
      });
    } catch (error) {
      setResult({ error: error.message || 'Unable to analyse image' });
    } finally {
      setLoading(false);
    }
  }

  async function sendChat() {
    const question = message.trim();
    if (!question || chatLoading) return;
    const nextMessages = [...chatMessages, { role: 'user', text: question }];
    setChatMessages(nextMessages);
    setMessage('');
    setChatLoading(true);
    try {
      const response = await fetch(`${API}/api/chat`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          message: question,
          language: lang,
          context: {
            crop: result?.prediction?.class_name || 'crop',
            disease: result?.prediction?.class_name || 'unknown disease',
            confidence: result?.prediction?.confidence || 0
          },
          history: nextMessages.slice(-8)
        })
      });
      const data = await response.json();
      setChatMessages((current) => [...current, { role: 'assistant', text: data.reply || data.answer || data.error || 'Please try again.' }]);
    } catch {
      setChatMessages((current) => [...current, { role: 'assistant', text: 'AI service is temporarily unavailable.' }]);
    } finally {
      setChatLoading(false);
    }
  }

  async function loadForecastForPlace(place, cacheKey = `${place.latitude},${place.longitude}`) {
    setWeatherLoading(true);
    setWeatherPhase('forecast');
    setWeatherError('');
    setWeatherChoices([]);
    try {
      const cached = weatherCache.get(cacheKey);
      if (cached && Date.now() - cached.savedAt < WEATHER_CACHE_TTL) {
        setWeather({ meta: cached.place, data: cached.data });
        setWeatherCity(cached.place.name);
        return;
      }
      let data;
      try {
        data = await readApiJson(forecastUrl(place.latitude, place.longitude), text('weatherForecastError'));
      } catch (error) {
        if (error instanceof TypeError) throw new Error(text('weatherNetworkError'));
        throw error;
      }
      const resolved = { ...place, timezone: place.timezone || data.timezone };
      setWeather({ meta: resolved, data });
      setWeatherCity(resolved.name);
      weatherCache.set(cacheKey, { place: resolved, data, savedAt: Date.now() });
      if (weatherCache.size > 12) weatherCache.delete(weatherCache.keys().next().value);
    } catch (error) {
      setWeather(null);
      setWeatherError(error.message || text('weatherForecastError'));
    } finally {
      setWeatherLoading(false);
      setWeatherPhase('');
    }
  }

  async function loadWeatherByCity() {
    const query = weatherQuery.trim();
    if (!query || weatherLoading) return;
    const cacheKey = `query:${normalizePlace(query)}`;
    const cached = weatherCache.get(cacheKey);
    if (cached && Date.now() - cached.savedAt < WEATHER_CACHE_TTL) {
      setWeather({ meta: cached.place, data: cached.data });
      setWeatherCity(cached.place.name);
      setWeatherError('');
      setWeatherChoices([]);
      return;
    }
    setWeatherLoading(true);
    setWeatherPhase('resolve');
    setWeatherError('');
    setWeatherChoices([]);
    try {
      const params = new URLSearchParams({ name: query, count: '10', language: 'en', format: 'json' });
      let geo;
      try {
        geo = await readApiJson(`https://geocoding-api.open-meteo.com/v1/search?${params}`, text('weatherResolveError'));
        if (!geo.results?.length) {
          const terms = query.split(/[\s,]+/).filter(Boolean);
          for (let end = terms.length - 1; end > 0 && !geo.results?.length; end -= 1) {
            const fallbackParams = new URLSearchParams({ name: terms.slice(0, end).join(' '), count: '10', language: 'en', format: 'json' });
            geo = await readApiJson(`https://geocoding-api.open-meteo.com/v1/search?${fallbackParams}`, text('weatherResolveError'));
          }
        }
      } catch (error) {
        if (error instanceof TypeError) throw new Error(text('weatherNetworkError'));
        throw error;
      }
      const places = rankedPlaces(Array.isArray(geo.results) ? geo.results : [], query);
      if (!places.length) throw new Error(text('weatherNoMatch'));
      const exactMatches = places.filter((place) => normalizePlace(place.name) === normalizePlace(query));
      const queryHasContext = exactMatches.some((place) => [place.admin1, place.admin2, place.country]
        .filter(Boolean).some((part) => normalizePlace(query).includes(normalizePlace(part))));
      if (exactMatches.length > 1 && !queryHasContext && normalizePlace(query) === normalizePlace(exactMatches[0].name)) {
        setWeatherChoices(exactMatches.slice(0, 6));
        setWeather(null);
        return;
      }
      setWeatherPhase('forecast');
      await loadForecastForPlace(places[0], cacheKey);
    } catch (error) {
      setWeather(null);
      setWeatherError(error.message || text('weatherResolveError'));
    } finally {
      setWeatherLoading(false);
      setWeatherPhase('');
    }
  }

  function useBrowserLocation() {
    if (!navigator.geolocation) {
      setWeatherError(text('locationUnavailable'));
      return;
    }
    setWeatherLoading(true);
    setWeatherPhase('location');
    setWeatherError('');
    setWeatherChoices([]);
    navigator.geolocation.getCurrentPosition(({ coords }) => {
      loadForecastForPlace({ name: 'My location', latitude: coords.latitude, longitude: coords.longitude, timezone: '' }, `coords:${coords.latitude.toFixed(3)},${coords.longitude.toFixed(3)}`);
    }, (error) => {
      setWeatherLoading(false);
      setWeatherPhase('');
      if (error.code === 1) setWeatherError(text('locationPermissionDenied'));
      else if (error.code === 3) setWeatherError(text('locationTimeout'));
      else setWeatherError(text('locationUnavailable'));
    }, { enableHighAccuracy: false, timeout: 10000, maximumAge: 60000 });
  }

  function clearHistory() {
    localStorage.removeItem(HISTORY_KEY);
    setHistory([]);
  }

  function loadHistoryItem(item) {
    setResult({
      prediction: {
        class_name: item.diagnosis,
        confidence: item.confidence,
        severity: item.severity,
        status: item.status,
        crop: item.crop
      },
      government_alert: item.governmentAlert || (typeof item.alert === 'boolean' ? { required: item.alert } : null)
    });
    setAdvice(item.advice || null);
    scrollToId('scanner');
  }

  return (
    <div className="app-shell">
      <div className="ambient ambient-a" />
      <div className="ambient ambient-b" />

      <header className="topbar">
        <button className="brand brand-button" onClick={() => scrollToId('top')} type="button">
          <span className="brand-mark"><Leaf size={19} /></span>
          <span><b>KRISHI RAKSHAK</b><small>AI CROP INTELLIGENCE</small></span>
        </button>
        <nav className={mobileMenu ? 'navlinks open' : 'navlinks'}>
          <button className={activeSection === 'top' ? 'active' : ''} onClick={() => scrollToId('top')}>{text('home')}</button>
          <button className={activeSection === 'scanner' ? 'active' : ''} onClick={() => scrollToId('scanner')}>{text('scanner')}</button>
          <button className={activeSection === 'weather' ? 'active' : ''} onClick={() => scrollToId('weather')}>{text('weather')}</button>
          <button className={activeSection === 'history' ? 'active' : ''} onClick={() => scrollToId('history')}>{text('history')}<span className="nav-badge">{history.length}</span></button>
          <button className={activeSection === 'experts' ? 'active' : ''} onClick={() => scrollToId('experts')}>{text('experts')}</button>
        </nav>
        <div className="top-actions">
          <select value={lang} onChange={(event) => setLang(event.target.value)} aria-label="Language">
            {LANGS.map(([value, name]) => <option key={value} value={value}>{name}</option>)}
          </select>
          <button className="icon-btn" title={text('settings')} onClick={() => setSettings(true)} type="button"><Settings2 size={18} /></button>
          <button className="icon-btn" onClick={() => setChatOpen(true)} type="button"><MessageCircle size={18} /></button>
          <button className="icon-btn menu-btn" onClick={() => setMobileMenu((value) => !value)} type="button"><Menu size={19} /></button>
        </div>
      </header>

      <main>
        <section className="hero" id="top">
          <div className="hero-copy">
            <div className="eyebrow"><span className="live-dot" />{text('heroEyebrow')}</div>
            <h1>{text('heroTitle1')}<br /><span>{text('heroTitle2')}</span></h1>
            <p className="hero-lede">{text('heroText')}</p>
            <div className="hero-actions">
              <button className="btn btn-primary" onClick={() => scrollToId('scanner')} type="button"><ScanLine size={17} />{text('scan')}<ArrowRight size={16} /></button>
              <button className="btn btn-glass" onClick={() => setChatOpen(true)} type="button"><Bot size={17} />{text('talk')}</button>
            </div>
            <div className="hero-proof">
              <span><CheckCircle2 size={14} />{text('online')}</span>
              <span><CheckCircle2 size={14} />{text('offline')}</span>
              <span><CheckCircle2 size={14} />{text('languages')}</span>
            </div>
            <div className="micro-stats">
              <div><b>192</b><span>{text('classes')}</span></div>
              <div><b>224</b><span>{text('vision')}</span></div>
              <div><b>24/7</b><span>{text('field')}</span></div>
            </div>
          </div>

          <div className="hero-stage">
            <div className="stage-grid" />
            <spline-viewer
              ref={splineViewerRef}
              className="spline-viewer"
              url={SPLINE_SCENE}
              loading="eager"
              loading-anim="true"
              events-target="local"
              aria-label="Interactive Krishi Rakshak agriculture scene"
            />
            {splineLoading && <div className="scene-loader" role="status"><span className="spinner" />Loading 3D field scene</div>}
            {splineLoadError && <div className="scene-error" role="status">3D scene could not start in this browser.</div>}
            <div className="stage-vignette" />
            <div className="stage-label label-left"><span className="pulse-ring" /><div><b>LIVE VISION</b><small>leaf signal online</small></div></div>
            <div className="stage-label label-right"><Activity size={15} /><div><b>AI STATUS</b><small>{loading ? text('analyzing') : 'Analysis ready'}</small></div></div>
            <div className="floating-card card-top"><span className="mini-icon"><Zap size={15} /></span><div><b>FAST ANALYSIS</b><small>Vision model active</small></div></div>
            <div className="floating-card card-bottom"><span className="mini-icon"><ShieldCheck size={15} /></span><div><b>FALLBACK READY</b><small>Offline TFLite available</small></div></div>
          </div>
        </section>

        <section className="process-strip">
          <div><span>01</span><b>SCAN</b><small>Upload a leaf image</small></div>
          <div><span>02</span><b>ANALYSE</b><small>AI reads crop signals</small></div>
          <div><span>03</span><b>INTERPRET</b><small>Confidence + severity</small></div>
          <div><span>04</span><b>ACT</b><small>Guidance + alerts</small></div>
        </section>

        <section className="section" id="scanner">
          <div className="section-head">
            <div><div className="eyebrow">{text('diagnostics')}</div><h2>{text('fromImage')} <span>{text('fieldAction')}</span></h2></div>
            <p>Existing prediction, advice and chat APIs remain unchanged.</p>
          </div>
          <div className="scanner-layout">
            <div className="glass-panel upload-panel">
              <div className="panel-kicker"><Upload size={15} />{text('imageInput')}</div>
              <label className={loading ? 'dropzone is-analyzing' : 'dropzone'}>
                {preview ? (
                  <div className="preview-wrap"><img src={preview} alt="Selected crop" /><span className="preview-chip"><FileImage size={13} /> {file?.name}</span></div>
                ) : (
                  <><div className="upload-orb"><Upload size={23} /></div><strong>{text('drop')}</strong><span>{text('uploadHint')}</span></>
                )}
                <input type="file" accept="image/*" onChange={handlePick} />
              </label>
              {file && <div className="file-meta"><span>{file.name}</span><span>{Math.round(file.size / 1024)} KB</span></div>}
              <button className="btn btn-primary wide" disabled={!file || loading} onClick={analyze} type="button"><Sparkles size={17} />{loading ? text('analyzing') : text('analyze')}<ArrowRight size={16} /></button>
              <div className="safe-note"><Cpu size={15} /><span>{text('offlineNote')}</span></div>
            </div>

            <div className="glass-panel result-panel">
              <div className="panel-kicker"><Activity size={15} />{text('output')}</div>
              {!result ? (
                <div className="result-empty"><div className="scan-orb"><ScanLine size={27} /></div><h3>{text('ready')}</h3><p>{text('readyText')}</p></div>
              ) : result.error ? (
                <div className="result-empty"><div className="error-orb">!</div><h3>{result.error}</h3></div>
              ) : (
                <>
                  <div className="diagnosis-head">
                    <div><span>{text('diagnosis')}</span><h3>{result.prediction?.class_name || text('unknown')}</h3></div>
                    <strong className={`severity ${String(result.prediction?.severity || '').toLowerCase()}`}>{result.prediction?.severity || 'â€”'}</strong>
                  </div>
                  <div className="confidence-row">
                    <div><span>{text('confidence')}</span><b>{animatedConfidence.toFixed(1)}%</b></div>
                    <div className="confidence-bar"><i style={{ width: `${animatedConfidence}%` }} /></div>
                  </div>
                  <div className="metric-grid">
                    <div><span>{text('status')}</span><b>{result.prediction?.status || 'â€”'}</b></div>
                    <div><span>{text('alert')}</span><b>{typeof result.government_alert?.required === 'boolean' ? (result.government_alert.required ? 'Required' : 'Not required') : 'No alert status returned'}</b>
                      {result.government_alert?.status && <small>{result.government_alert.status}</small>}
                      {result.government_alert?.alert_id && <small>Alert ID: {result.government_alert.alert_id}</small>}
                    </div>
                  </div>
                  {advice && <div className="advice-grid">
                    {[[text('description'), advice.description], [text('treatment'), advice.treatment], [text('prevention'), advice.prevention], [text('farmerAction'), advice.farmer_action]].map(([title, body]) => <article key={title}><span>{title}</span><p>{body}</p></article>)}
                  </div>}
                  <div className="result-actions">
                    <button className="btn btn-glass" onClick={() => scrollToId('history')} type="button"><HistoryIcon size={16} />{text('history')}</button>
                    <button className="btn btn-primary" onClick={() => { setFile(null); setPreview(''); setResult(null); setAdvice(null); }} type="button"><RefreshCw size={16} />{text('scanAgain')}</button>
                  </div>
                </>
              )}
            </div>
          </div>
        </section>

        <section className="section weather-section" id="weather">
          <div className="section-head"><div><div className="eyebrow">WEATHER INTELLIGENCE</div><h2>{text('weatherTitle')}</h2><p>{text('weatherSub')}</p></div></div>
          <div className="weather-toolbar glass-panel">
            <div className="searchbox"><Search size={16} /><input aria-label={text('searchCity')} value={weatherQuery} onChange={(event) => setWeatherQuery(event.target.value)} onKeyDown={(event) => { if (event.key === 'Enter') loadWeatherByCity(); }} placeholder={text('searchCity')} /><button aria-label="Search worldwide weather" onClick={loadWeatherByCity} type="button"><ArrowRight size={16} /></button></div>
            <button className="btn btn-glass" onClick={useBrowserLocation} type="button"><LocateFixed size={16} />{text('useLocation')}</button>
          </div>
          {weatherError && <div className="inline-error"><AlertTriangle size={16} />{weatherError}</div>}
          {weatherChoices.length > 0 && <div className="location-choices glass-panel" aria-label={text('chooseLocation')}><b>{text('chooseLocation')}</b>{weatherChoices.map((place) => <button key={`${place.id}-${place.latitude}-${place.longitude}`} type="button" onClick={() => loadForecastForPlace(place, `query:${normalizePlace(weatherQuery)}`)}><span><strong>{place.name}</strong><small>{[place.admin2, place.admin1, place.country].filter((value, index, values) => value && values.indexOf(value) === index).join(', ')}</small></span>{place.population ? <small>{Number(place.population).toLocaleString()} people</small> : null}</button>)}</div>}
          {weatherLoading ? (
            <div className="loading-card glass-panel"><div className="spinner" />{text(weatherPhase === 'resolve' ? 'weatherResolving' : weatherPhase === 'location' ? 'locationLoading' : 'weatherLoading')}</div>
          ) : !weather ? (
            <div className="empty-wide glass-panel"><CloudSun size={28} /><b>{text('useSearch')}</b></div>
          ) : (
            <div className="weather-grid">
              <div className="glass-panel current-weather">
                <div className="weather-place"><MapPin size={15} /><span><b>{weatherCity}</b>{locationLine(weather.meta) && <small>{locationLine(weather.meta)}</small>}{weather.meta.timezone && <small>{weather.meta.timezone}</small>}</span></div>
                <div className="current-main">
                  <div><span>NOW</span><b><AnimatedNumber value={weather.data.current.temperature_2m} suffix="Â°" /></b><em>{weatherCondition(weather.data.current.weather_code, lang)}</em></div>
                  {React.createElement(weatherIcon(weather.data.current.weather_code), { size: 58 })}
                </div>
                <div className="weather-metrics">
                  <div><Droplets /><b>{weather.data.current.relative_humidity_2m}%</b><small>{text('humidity')}</small></div>
                  <div><Activity /><b>{Math.round(weather.data.current.apparent_temperature)}Â°C</b><small>Feels like</small></div>
                  <div><Wind /><b>{Math.round(weather.data.current.wind_speed_10m)} km/h</b><small>{text('wind')}</small></div>
                  <div><Wind /><b>{Math.round(weather.data.current.wind_direction_10m)}Â°</b><small>Wind direction</small></div>
                  <div><CloudRain /><b>{weather.data.current.rain} mm</b><small>{text('rain')}</small></div>
                  <div><CloudSun /><b>{weather.data.current.cloud_cover}%</b><small>{text('cloud')}</small></div>
                </div>
              </div>
              <div className="glass-panel">
                <div className="panel-kicker"><CalendarDays size={15} />{text('forecast')}</div>
                <div className="forecast-row">{weather.data.daily.time.map((day, index) => {
                  const Icon = weatherIcon(weather.data.daily.weather_code[index]);
                  return <div className="forecast-card" key={day}><b>{index === 0 ? 'Today' : formatDay(day)}</b><Icon size={24} /><strong><AnimatedNumber value={weather.data.daily.temperature_2m_max[index]} suffix="Â°" /></strong><span><AnimatedNumber value={weather.data.daily.temperature_2m_min[index]} suffix="Â°" /></span><small>{weather.data.daily.precipitation_probability_max[index]}% rain</small></div>;
                })}</div>
              </div>
              <div className="glass-panel agri-summary">
                <div className="panel-kicker"><Leaf size={15} />{text('agriSummary')}</div>
                <div className="summary-items">
                  <div><span>Rain probability</span><b>{weather.data.daily.precipitation_probability_max[0]}%</b></div>
                  <div><span>Max temperature</span><b>{Math.round(weather.data.daily.temperature_2m_max[0])}Â°C</b></div>
                  <div><span>Min temperature</span><b>{Math.round(weather.data.daily.temperature_2m_min[0])}Â°C</b></div>
                  <div><span>Sunrise</span><b>{new Date(weather.data.daily.sunrise[0]).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</b></div>
                  <div><span>Sunset</span><b>{new Date(weather.data.daily.sunset[0]).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</b></div>
                </div>
              </div>
            </div>
          )}
        </section>

        <section className="section" id="history">
          <div className="section-head">
            <div><div className="eyebrow">PREDICTION HISTORY</div><h2>{text('historyTitle')}</h2><p>{text('historySub')}</p></div>
            {history.length > 0 && <button className="btn btn-glass danger-btn" onClick={clearHistory} type="button"><Trash2 size={16} />{text('clear')}</button>}
          </div>
          {history.length === 0 ? <div className="empty-wide glass-panel"><HistoryIcon size={30} /><b>{text('noHistory')}</b></div> : <div className="history-grid">{history.map((item) => <button className="history-card glass-panel" key={item.id} onClick={() => loadHistoryItem(item)} type="button"><div className="history-icon"><Leaf size={18} /></div><div><span>{item.diagnosis}</span><b>{item.confidence.toFixed(1)}% Â· {item.severity}</b><small>{item.filename}</small><small>{new Date(item.timestamp).toLocaleString()}</small></div><ArrowRight size={17} /></button>)}</div>}
        </section>

        <section className="section" id="experts">
          <div className="section-head"><div><div className="eyebrow">EXPERT AGRICULTURE</div><h2>{text('expertTitle')}</h2><p>{text('expertSub')}</p></div></div>
          <div className="topic-search glass-panel"><Search size={16} /><input value={topicQuery} onChange={(event) => setTopicQuery(event.target.value)} placeholder={text('searchTopics')} /></div>
          <div className="expert-layout">
            <div className="topic-grid">{filteredTopics.map((item, index) => <button className="topic-card glass-panel" key={item.title} onClick={() => setTopic(item)} type="button"><span className="topic-number">{String(index + 1).padStart(2, '0')}</span><div className="topic-emoji">{item.icon}</div><b>{item.title}</b><p>{item.summary}</p><span className="topic-open">{text('open')} <ArrowRight size={14} /></span></button>)}</div>
            <div className="consultants">
              <div className="consultant-head"><div><div className="eyebrow">{text('consultants')}</div><h3>Official referral contacts</h3></div><UsersRound size={20} /></div>
              {(consultants.length ? consultants.slice(0, 6).map((consultant) => <div className="consultant-card" key={consultant.email || consultant.name}><div className="consultant-avatar"><UserRound size={17} /></div><div><b>{consultant.name}</b><span>{consultant.role}</span><small>{consultant.specialization}</small><div className="contact-row">{consultant.phone && <a href={`tel:${consultant.phone}`}><span>{consultant.phone}</span></a>}{consultant.email && <a href={`mailto:${consultant.email}`}><Mail size={13} />{consultant.email}</a>}</div></div></div>) : consultantFallback.map(([name, description, url]) => <div className="consultant-card" key={name}><div className="consultant-avatar"><UserRound size={17} /></div><div><b>{name}</b><span>{description}</span><a href={url} target="_blank" rel="noreferrer"><ExternalLink size={13} /> Official site</a></div></div>))}
            </div>
          </div>
        </section>

        <section className="section technology"><div className="tech-panel"><div className="tech-copy"><div className="eyebrow">TECHNOLOGY</div><h2>Modern AI.<br /><span>Field-first delivery.</span></h2><p>The website is an interaction layer over your existing services: vision prediction, Gemini guidance, history, weather context and expert workflows.</p></div><div className="tech-stack"><div><Cpu /><b>Vision model</b><span>192-class crop intelligence</span></div><div><Zap /><b>Offline safety net</b><span>Local TFLite inference</span></div><div><Sparkles /><b>Gemini guidance</b><span>Detailed multilingual advice</span></div><div><CloudSun /><b>Weather context</b><span>7-day field forecast</span></div></div></div></section>
      </main>

      <footer><button className="brand brand-button" onClick={() => scrollToId('top')} type="button"><span className="brand-mark"><Leaf size={16} /></span><span><b>KRISHI RAKSHAK</b><small>AI CROP INTELLIGENCE</small></span></button><span>AI-powered crop intelligence Â· Team Innov8X</span><button onClick={() => setSettings(true)} type="button"><Settings2 size={15} /></button></footer>

      {chatOpen && <div className="modal-overlay" onClick={() => setChatOpen(false)}><aside className="chat-drawer" onClick={(event) => event.stopPropagation()}><header><div><span>KRISHI AI</span><b>{text('ask')}</b></div><button onClick={() => setChatOpen(false)} type="button"><X /></button></header><main>{chatMessages.map((item, index) => <div className={`bubble ${item.role}`} key={`${item.role}-${index}`}>{item.text}</div>)}{chatLoading && <div className="bubble assistant"><span className="typing"><i /><i /><i /></span></div>}</main><div className="chat-input"><input value={message} onChange={(event) => setMessage(event.target.value)} onKeyDown={(event) => { if (event.key === 'Enter') sendChat(); }} placeholder={text('askHint')} /><button onClick={sendChat} disabled={chatLoading} type="button"><Send size={16} /></button></div></aside></div>}

      {topic && <div className="modal-overlay" onClick={() => setTopic(null)}><div className="topic-modal" onClick={(event) => event.stopPropagation()}><header><div><span>EXPERT AGRICULTURE</span><h3>{topic.icon} {topic.title}</h3></div><button onClick={() => setTopic(null)} type="button"><X /></button></header><p>{topic.summary}</p><div className="topic-sections">{topic.sections.map(([title, body]) => <article key={title}><b>{title}</b><p>{body}</p></article>)}</div><div className="expert-note"><ShieldCheck size={16} /><span>General expert guidance. Confirm crop, stage, local conditions and current product labels before chemical treatment.</span></div></div></div>}

      {settings && <div className="modal-overlay" onClick={() => setSettings(false)}><div className="settings-modal" onClick={(event) => event.stopPropagation()}><header><div><span>KRISHI RAKSHAK</span><h3>{text('settings')}</h3></div><button onClick={() => setSettings(false)} type="button"><X /></button></header><div className="setting-row"><span>{text('language')}</span><select value={lang} onChange={(event) => setLang(event.target.value)}>{LANGS.map(([value, name]) => <option key={value} value={value}>{name}</option>)}</select></div><div className="setting-row"><span>{text('api')}</span><code>{API}</code><b className="ok"><CheckCircle2 size={14} />{text('readyApi')}</b></div><div className="setting-row"><span>{text('spline')}</span><a href={SPLINE_SCENE} target="_blank" rel="noreferrer">Open scene <ExternalLink size={14} /></a></div><div className="setting-note"><ShieldCheck size={16} /> Backend and Flutter app are not modified by this website.</div></div></div>}
    </div>
  );
}

const rootElement = document.getElementById('root');
const reactRoot = globalThis.__krishiRakshakRoot || createRoot(rootElement);
globalThis.__krishiRakshakRoot = reactRoot;
reactRoot.render(<App />);


