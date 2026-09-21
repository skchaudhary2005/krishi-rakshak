import { useEffect, useState } from 'react';
import { AlertTriangle, Bug, CheckCircle, Upload, Loader2, ShieldAlert } from 'lucide-react';
import Navbar from '../components/Navbar';

type Detection = {
  class_name: string;
  confidence: number;
  bbox: number[];
};

type RiskAssessment = {
  score: number;
  level: 'low' | 'medium' | 'high';
  label: string;
  recommended_actions: string[];
  validated: boolean;
  method: string;
};

const PestDetection = () => {
  const [file, setFile] = useState<File | null>(null);
  const [detections, setDetections] = useState<Detection[]>([]);
  const [risk, setRisk] = useState<RiskAssessment | null>(null);
  const [loading, setLoading] = useState(false);
  const [configured, setConfigured] = useState<boolean | null>(null);
  const [error, setError] = useState('');

  useEffect(() => {
    fetch('http://127.0.0.1:5000/api/pest-detect/status')
      .then((r) => r.json())
      .then((data) => setConfigured(Boolean(data.configured)))
      .catch(() => setConfigured(false));
  }, []);

  const detect = async () => {
    if (!file) return;
    setLoading(true);
    setError('');
    setDetections([]);
    setRisk(null);

    try {
      const form = new FormData();
      form.append('image', file);
      form.append('confidence', '0.25');

      const response = await fetch('http://127.0.0.1:5000/api/pest-detect', {
        method: 'POST',
        body: form,
      });
      const data = await response.json();

      if (!response.ok || !data.success) {
        throw new Error(data.error || 'Pest detection failed');
      }

      setDetections(data.detections || []);
      setRisk(data.risk_assessment || null);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Pest detection failed');
    } finally {
      setLoading(false);
    }
  };

  const riskClass =
    risk?.level === 'high'
      ? 'bg-red-50 border-red-200 text-red-800'
      : risk?.level === 'medium'
        ? 'bg-orange-50 border-orange-200 text-orange-800'
        : 'bg-green-50 border-green-200 text-green-800';

  return (
    <div className="min-h-screen">
      <Navbar />
      <main className="container mx-auto px-4 py-8 max-w-4xl">
        <div className="card">
          <div className="flex items-center gap-3 mb-6">
            <Bug className="text-primary-600" size={34} />
            <div>
              <h1 className="text-3xl font-bold text-gray-800">AI Pest Detection</h1>
              <p className="text-gray-600">YOLO-based pest detection with explainable risk assessment.</p>
            </div>
          </div>

          <div className="mb-5 p-4 rounded-xl border bg-gray-50">
            <div className="flex items-center gap-2 font-semibold">
              {configured ? <CheckCircle className="text-green-600" size={20} /> : <AlertTriangle className="text-orange-600" size={20} />}
              {configured === null ? 'Checking YOLO model...' : configured ? 'YOLO model ready' : 'YOLO model not configured'}
            </div>
            {!configured && configured !== null && (
              <p className="text-sm text-gray-600 mt-2">
                Install Ultralytics and place your <code>best.pt</code> at
                <code className="ml-1">public/models/pest/best.pt</code>.
              </p>
            )}
          </div>

          <label className="block border-2 border-dashed rounded-xl p-8 text-center cursor-pointer hover:bg-primary-50">
            <Upload className="mx-auto mb-3 text-primary-600" size={32} />
            <span className="font-semibold">{file ? file.name : 'Choose a crop/pest image'}</span>
            <input
              type="file"
              accept="image/*"
              className="hidden"
              onChange={(e) => setFile(e.target.files?.[0] || null)}
            />
          </label>

          <button
            onClick={detect}
            disabled={!file || loading || !configured}
            className="btn-primary w-full mt-5 flex items-center justify-center gap-2 disabled:opacity-50"
          >
            {loading ? <Loader2 className="animate-spin" size={20} /> : <Bug size={20} />}
            {loading ? 'Detecting pests...' : 'Detect Pests'}
          </button>

          {error && <div className="mt-5 p-4 bg-red-50 text-red-700 rounded-xl">{error}</div>}

          {risk && (
            <section className={`mt-7 p-5 rounded-xl border ${riskClass}`}>
              <div className="flex items-center gap-3">
                <ShieldAlert size={26} />
                <div>
                  <h2 className="text-xl font-bold">Pest Risk Assessment</h2>
                  <p className="font-semibold">{risk.label} · Score {risk.score}/100</p>
                </div>
              </div>
              <div className="mt-4 h-3 bg-white/70 rounded-full overflow-hidden">
                <div
                  className="h-full rounded-full bg-current opacity-70"
                  style={{ width: `${Math.min(100, Math.max(0, risk.score))}%` }}
                />
              </div>
              <div className="mt-4">
                <h3 className="font-bold mb-2">Recommended actions</h3>
                <ol className="space-y-2">
                  {risk.recommended_actions.map((action, i) => (
                    <li key={i} className="flex gap-2">
                      <span className="font-bold">{i + 1}.</span>
                      <span>{action}</span>
                    </li>
                  ))}
                </ol>
              </div>
              {!risk.validated && (
                <p className="text-xs mt-4 opacity-80">
                  Risk score is an explainable rule-based prototype, not a validated agronomic forecast.
                </p>
              )}
            </section>
          )}

          {detections.length > 0 && (
            <div className="mt-7">
              <h2 className="text-xl font-bold mb-3">Detected Pests ({detections.length})</h2>
              <div className="space-y-3">
                {detections.map((d, i) => (
                  <div key={i} className="p-4 rounded-xl bg-green-50 border border-green-200">
                    <div className="flex justify-between">
                      <span className="font-bold">{d.class_name}</span>
                      <span>{d.confidence.toFixed(1)}%</span>
                    </div>
                    <p className="text-sm text-gray-600 mt-1">Bounding box: [{d.bbox.join(', ')}]</p>
                  </div>
                ))}
              </div>
            </div>
          )}

          {file && !loading && detections.length === 0 && !error && configured && (
            <div className="mt-6 p-4 bg-blue-50 rounded-xl">
              No pest detected above the current confidence threshold.
            </div>
          )}
        </div>
      </main>
    </div>
  );
};

export default PestDetection;
