import { useEffect, useState } from 'react';
import { AlertTriangle, MapPin, RefreshCw, Activity, ShieldAlert } from 'lucide-react';
import Navbar from '../components/Navbar';

type Hotspot = {
  state: string | null; district: string | null; disease: string | null; severity: string | null;
  alert_count: number; avg_confidence: number | null;
  location: { latitude: number | null; longitude: number | null };
  first_seen: string | null; last_seen: string | null;
};
type Summary = { total_alerts: number; diseases: number; states: number; districts: number; avg_confidence: number | null };
const API_BASE = import.meta.env.VITE_API_BASE_URL || 'http://127.0.0.1:5000';
const severityClass = (s: string | null) => s === 'high' ? 'bg-red-100 text-red-700' : s === 'medium' ? 'bg-amber-100 text-amber-700' : 'bg-green-100 text-green-700';

const Hotspots = () => {
  const [hotspots,setHotspots]=useState<Hotspot[]>([]); const [summary,setSummary]=useState<Summary|null>(null);
  const [loading,setLoading]=useState(true); const [error,setError]=useState('');
  const loadData=async()=>{try{setLoading(true);setError('');
    const [a,b]=await Promise.all([fetch(API_BASE+'/api/hotspots?limit=100'),fetch(API_BASE+'/api/hotspots/summary')]);
    if(!a.ok||!b.ok) throw new Error('Hotspot API is not available');
    setHotspots((await a.json()).hotspots||[]); setSummary((await b.json()).summary||null);
  }catch(e){setError(e instanceof Error?e.message:'Unable to load hotspot data')}finally{setLoading(false)}};
  useEffect(()=>{loadData()},[]);
  return <div className="min-h-screen bg-gray-50"><Navbar/><main className="container mx-auto max-w-7xl px-4 py-8">
    <section className="rounded-3xl bg-gradient-to-r from-green-900 via-emerald-800 to-green-700 p-6 md:p-8 text-white shadow-xl mb-8">
      <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-5"><div>
        <div className="flex items-center gap-2 text-green-100 text-sm font-semibold mb-2"><MapPin size={18}/> DISEASE SURVEILLANCE</div>
        <h1 className="text-3xl md:text-4xl font-extrabold">Crop Disease Hotspots</h1>
        <p className="mt-2 max-w-2xl text-green-50">Aggregated disease alerts from Krishi Rakshak scans, ready for GIS visualization and government monitoring.</p>
      </div><button onClick={loadData} className="inline-flex items-center justify-center gap-2 rounded-xl bg-white px-4 py-3 font-semibold text-green-800 hover:bg-green-50"><RefreshCw size={18}/>Refresh</button></div>
    </section>
    {summary&&<section className="grid grid-cols-2 md:grid-cols-5 gap-4 mb-8">{[
      ['Total Alerts',summary.total_alerts,Activity],['Diseases',summary.diseases,ShieldAlert],['States',summary.states,MapPin],['Districts',summary.districts,MapPin],['Avg Confidence',(summary.avg_confidence??0)+'%',Activity]
    ].map(([label,value,Icon])=><div key={String(label)} className="rounded-2xl bg-white p-5 shadow-sm border border-gray-100"><Icon className="text-green-600 mb-3" size={22}/><p className="text-sm text-gray-500">{label}</p><p className="text-2xl font-extrabold text-gray-900">{value}</p></div>)}</section>}
    {loading&&<div className="rounded-2xl bg-white p-10 text-center shadow-sm">Loading hotspot data...</div>}
    {error&&!loading&&<div className="rounded-2xl bg-red-50 border border-red-200 p-5 text-red-700 flex items-center gap-3"><AlertTriangle size={22}/>{error}. Make sure Flask is running on port 5000.</div>}
    {!loading&&!error&&hotspots.length===0&&<div className="rounded-2xl bg-white p-10 text-center shadow-sm text-gray-500">No government alerts with location data have been recorded yet.</div>}
    <section className="grid gap-5 md:grid-cols-2">{hotspots.map((h,i)=><article key={h.disease+'-'+h.district+'-'+i} className="rounded-2xl bg-white border border-gray-100 shadow-sm p-6">
      <div className="flex items-start justify-between gap-4"><div><p className="text-xs uppercase tracking-wider text-gray-400">Hotspot #{i+1}</p><h2 className="text-xl font-bold text-gray-900 mt-1">{h.disease||'Unknown disease'}</h2></div>
      <span className={'px-3 py-1 rounded-full text-xs font-bold uppercase '+severityClass(h.severity)}>{h.severity||'unknown'}</span></div>
      <div className="grid grid-cols-2 gap-4 mt-5">
        <div><p className="text-xs text-gray-400">Location</p><p className="font-semibold">{h.district||'Unknown district'}</p><p className="text-sm text-gray-500">{h.state||'Unknown state'}</p></div>
        <div><p className="text-xs text-gray-400">Alerts</p><p className="text-2xl font-extrabold text-gray-900">{h.alert_count}</p></div>
        <div><p className="text-xs text-gray-400">Avg. Confidence</p><p className="font-semibold">{h.avg_confidence??0}%</p></div>
        <div><p className="text-xs text-gray-400">Coordinates</p><p className="font-mono text-xs">{h.location.latitude??'—'}, {h.location.longitude??'—'}</p></div>
      </div>
    </article>)}</section>
  </main></div>
};
export default Hotspots;
