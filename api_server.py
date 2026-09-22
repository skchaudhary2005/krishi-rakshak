import cv2
import numpy as np
import os
import json
import uuid
import sqlite3
import urllib.request
import urllib.error
from datetime import datetime, timezone

import numpy as np
from PIL import Image
from flask import Flask, request, jsonify
from flask_cors import CORS

try:
    import tensorflow as tf
except Exception as e:
    raise RuntimeError(f"TensorFlow import failed: {e}")


# ============================================================
# CONFIG
# ============================================================

BASE_DIR = os.path.dirname(os.path.abspath(__file__))


MODEL_DIR = os.path.join(
    BASE_DIR,
    "public",
    "models",
    "unified_192"
)

MODEL_PATH = os.path.join(
    MODEL_DIR,
    "krishi_rakshak.tflite"
)

CLASSES_PATH = os.path.join(
    MODEL_DIR,
    "classes.json"
)

DB_PATH = os.path.join(
    BASE_DIR,
    "krishi_rakshak.db"
)

HOST = "0.0.0.0"
PORT = int(os.environ.get("PORT", "5000"))

EXPECTED_CLASSES = 192
INPUT_SIZE = 224

# ============================================================
# GEMINI AI CONFIG
# ============================================================
# Keep the API key ONLY on the backend machine.
# PowerShell: $env:GEMINI_API_KEY = "YOUR_KEY"
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "").strip()
GEMINI_MODEL = os.environ.get("GEMINI_MODEL", "gemini-3.7-flash")
GEMINI_FALLBACK_MODELS = [GEMINI_MODEL, "gemini-3.6-flash", "gemini-3.5-flash", "gemini-3.5-flash-lite"]
GEMINI_TIMEOUT_SECONDS = 20



# ============================================================
# FLASK
# ============================================================

app = Flask(__name__)
CORS(app)


# ============================================================
# GLOBAL MODEL VARIABLES
# ============================================================

interpreter = None
input_details = None
output_details = None
classes = []


# ============================================================
# DATABASE
# ============================================================

def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_database():
    conn = get_db()
    cursor = conn.cursor()

    cursor.execute("""
        CREATE TABLE IF NOT EXISTS government_alerts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,

            alert_id TEXT UNIQUE NOT NULL,
            prediction_id TEXT,

            crop TEXT,
            disease TEXT,
            class_id INTEGER,

            confidence REAL,
            severity TEXT,
            status TEXT DEFAULT 'pending',

            latitude REAL,
            longitude REAL,
            district TEXT,
            state TEXT,

            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        )
    """)

    cursor.execute("""
        CREATE INDEX IF NOT EXISTS idx_alert_status
        ON government_alerts(status)
    """)

    cursor.execute("""
        CREATE INDEX IF NOT EXISTS idx_alert_severity
        ON government_alerts(severity)
    """)

    cursor.execute("""
        CREATE INDEX IF NOT EXISTS idx_alert_created
        ON government_alerts(created_at)
    """)

    conn.commit()
    conn.close()

    print(f"[DATABASE] SQLite ready: {DB_PATH}")


# ============================================================
# MODEL LOADING
# ============================================================

def load_classes():
    global classes

    if not os.path.exists(CLASSES_PATH):
        raise FileNotFoundError(
            f"classes.json not found: {CLASSES_PATH}"
        )

    with open(CLASSES_PATH, "r", encoding="utf-8") as f:
        data = json.load(f)

    # Current classes.json format:
    # {
    #   "0": "apple apple scab",
    #   "1": "apple black rot",
    #   ...
    # }

    if isinstance(data, dict):
        try:
            classes = [
                data[str(i)]
                for i in range(len(data))
            ]
        except Exception:
            # fallback
            classes = list(data.values())

    elif isinstance(data, list):
        classes = data

    else:
        raise ValueError(
            "Unsupported classes.json format"
        )

    if len(classes) != EXPECTED_CLASSES:
        raise ValueError(
            f"Expected {EXPECTED_CLASSES} classes, "
            f"but found {len(classes)}"
        )

    print(
        f"[MODEL] Loaded {len(classes)} classes"
    )


def load_model():
    global interpreter
    global input_details
    global output_details

    if not os.path.exists(MODEL_PATH):
        raise FileNotFoundError(
            f"TFLite model not found: {MODEL_PATH}"
        )

    interpreter = tf.lite.Interpreter(
        model_path=MODEL_PATH
    )

    interpreter.allocate_tensors()

    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    print(
        f"[MODEL] Input shape: "
        f"{input_details[0]['shape']}"
    )

    print(
        f"[MODEL] Input dtype: "
        f"{input_details[0]['dtype']}"
    )

    print(
        f"[MODEL] Output shape: "
        f"{output_details[0]['shape']}"
    )

    print(
        f"[MODEL] Output dtype: "
        f"{output_details[0]['dtype']}"
    )

    expected_input_shape = (
        1,
        INPUT_SIZE,
        INPUT_SIZE,
        3
    )

    if tuple(input_details[0]["shape"]) != expected_input_shape:
        raise ValueError(
            f"Unexpected model input shape: "
            f"{input_details[0]['shape']}"
        )

    output_shape = tuple(
        output_details[0]["shape"]
    )

    if output_shape[-1] != EXPECTED_CLASSES:
        raise ValueError(
            f"Expected {EXPECTED_CLASSES} output classes, "
            f"got {output_shape}"
        )

    print("[MODEL] 192-class TFLite model loaded successfully")


# ============================================================
# IMAGE PREPROCESSING
# ============================================================

def preprocess_image(image_file):
    """
    IMPORTANT:

    Current TFLite model contains MobileNetV2
    preprocessing internally.

    Therefore:
        DO NOT divide pixels by 255 here.

    Feed raw 0-255 float32 pixels.
    """

    image = Image.open(image_file).convert("RGB")

    image = image.resize(
        (INPUT_SIZE, INPUT_SIZE),
        Image.Resampling.BILINEAR
    )

    image_array = np.asarray(
        image,
        dtype=np.float32
    )

    image_array = np.expand_dims(
        image_array,
        axis=0
    )

    return image_array


# ============================================================
# MODEL PREDICTION
# ============================================================

def predict_image(image_file):
    input_tensor = preprocess_image(
        image_file
    )

    interpreter.set_tensor(
        input_details[0]["index"],
        input_tensor
    )

    interpreter.invoke()

    output = interpreter.get_tensor(
        output_details[0]["index"]
    )

    probabilities = np.asarray(
        output[0],
        dtype=np.float32
    )

    # Safety normalization if output is logits
    if (
        np.any(probabilities < 0)
        or not np.isclose(
            np.sum(probabilities),
            1.0,
            atol=0.05
        )
    ):
        exp_values = np.exp(
            probabilities -
            np.max(probabilities)
        )

        probabilities = (
            exp_values /
            np.sum(exp_values)
        )

    top_indices = np.argsort(
        probabilities
    )[::-1][:5]

    top_predictions = []

    for index in top_indices:
        index = int(index)

        top_predictions.append({
            "class_id": index,
            "class_name": classes[index],
            "confidence": round(
                float(probabilities[index]) * 100,
                2
            )
        })

    best_index = int(top_indices[0])
    best_confidence = float(
        probabilities[best_index]
    ) * 100

    best_class = classes[best_index]

    return {
        "class_id": best_index,
        "class_name": best_class,
        "confidence": round(
            best_confidence,
            2
        ),
        "top_predictions": top_predictions
    }


# ============================================================
# DISEASE / SEVERITY LOGIC
# ============================================================

HIGH_SEVERITY_KEYWORDS = [
    "late blight",
    "early blight",
    "bacterial",
    "virus",
    "viral",
    "canker",
    "black rot",
    "fire blight",
    "yellow leaf curl",
    "mosaic",
    "wilt",
    "scab",
    "rust"
]


def is_healthy(class_name):
    name = class_name.lower()

    healthy_keywords = [
        "healthy",
        "normal"
    ]

    return any(
        keyword in name
        for keyword in healthy_keywords
    )


def calculate_severity(
    class_name,
    confidence
):
    if is_healthy(class_name):
        return "none"

    name = class_name.lower()

    is_high_risk = any(
        keyword in name
        for keyword in HIGH_SEVERITY_KEYWORDS
    )

    if is_high_risk:
        if confidence >= 70:
            return "high"

        return "medium"

    if confidence >= 80:
        return "medium"

    return "low"


def government_alert_required(
    class_name,
    confidence,
    severity
):
    if is_healthy(class_name):
        return False

    if confidence < 70:
        return False

    return severity in [
        "medium",
        "high"
    ]


# ============================================================
# RISK ASSESSMENT ENGINE (V1)
# ============================================================
# Transparent rule-based prototype. This is NOT an agronomic prediction model.
# It combines model confidence, disease severity, and optional weather signals.


def calculate_risk_assessment(class_name, confidence, severity, weather=None):
    """Return a transparent 0-100 risk score and explainable contributing factors."""
    weather = weather or {}

    try:
        confidence = max(0.0, min(100.0, float(confidence)))
    except (TypeError, ValueError):
        confidence = 0.0

    if is_healthy(class_name):
        return {
            "score": 0.0,
            "level": "low",
            "factors": [{"name": "healthy_prediction", "impact": 0, "detail": "The detected class is marked healthy."}],
            "method": "rule_based_v1",
            "validated": False
        }

    severity_points = {
        "none": 0.0,
        "low": 25.0,
        "medium": 60.0,
        "high": 90.0
    }.get(str(severity).lower(), 25.0)

    # Disease confidence is the strongest signal available from the current model.
    score = confidence * 0.55 + severity_points * 0.30
    factors = [
        {"name": "model_confidence", "impact": round(confidence * 0.55, 2), "detail": f"Prediction confidence is {confidence:.2f}%"},
        {"name": "disease_severity", "impact": round(severity_points * 0.30, 2), "detail": f"Current severity is {severity}"}
    ]

    weather_score = 0.0
    try:
        humidity = float(weather.get("humidity")) if weather.get("humidity") is not None else None
        rainfall = float(weather.get("rainfall")) if weather.get("rainfall") is not None else None
    except (TypeError, ValueError):
        humidity, rainfall = None, None

    if humidity is not None:
        humidity_points = 20.0 if humidity >= 80 else 10.0 if humidity >= 60 else 0.0
        weather_score += humidity_points
        factors.append({"name": "humidity", "impact": round(humidity_points * 0.10, 2), "detail": f"Humidity is {humidity:.1f}%"})

    if rainfall is not None:
        rainfall_points = 15.0 if rainfall > 10 else 8.0 if rainfall > 2 else 0.0
        weather_score += rainfall_points
        factors.append({"name": "rainfall", "impact": round(rainfall_points * 0.10, 2), "detail": f"Rainfall is {rainfall:.1f} mm"})

    # Weather contributes only when supplied; keep the final score bounded.
    score += min(20.0, weather_score * 0.10)
    score = round(max(0.0, min(100.0, score)), 2)

    level = "high" if score >= 65 else "medium" if score >= 35 else "low"

    return {
        "score": score,
        "level": level,
        "factors": factors,
        "method": "rule_based_v1",
        "validated": False
    }


def get_optional_weather(data):
    def parse_float(value):
        if value is None or value == "":
            return None
        try:
            return float(value)
        except (TypeError, ValueError):
            return None

    return {
        "temperature": parse_float(data.get("temperature")),
        "humidity": parse_float(data.get("humidity")),
        "rainfall": parse_float(data.get("rainfall")),
        "condition": data.get("weather_condition") or data.get("condition")
    }


@app.route("/api/risk-assessment", methods=["POST"])
def risk_assessment():
    """Calculate explainable crop disease risk from an existing prediction context."""
    try:
        data = request.get_json(silent=True) or {}
        prediction = data.get("prediction") or data
        class_name = str(prediction.get("class_name") or prediction.get("disease") or "unknown disease")
        confidence = prediction.get("confidence", 0)
        severity = prediction.get("severity", calculate_severity(class_name, float(confidence or 0)))
        weather = data.get("weather") or {}

        result = calculate_risk_assessment(class_name, confidence, severity, weather)
        return jsonify({
            "success": True,
            "prediction": {
                "class_name": class_name,
                "confidence": float(confidence or 0),
                "severity": severity
            },
            "weather": weather,
            "risk_assessment": result,
            "disclaimer": "Rule-based prototype for decision support; not a validated agronomic risk forecast."
        }), 200
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 400


# ============================================================
# LOCATION EXTRACTION
# ============================================================

def get_optional_location(data):
    def parse_float(value):
        if value is None:
            return None

        try:
            return float(value)
        except Exception:
            return None

    return {
        "latitude": parse_float(
            data.get("latitude")
        ),
        "longitude": parse_float(
            data.get("longitude")
        ),
        "district": data.get(
            "district"
        ),
        "state": data.get(
            "state"
        )
    }


# ============================================================
# SAVE GOVERNMENT ALERT
# ============================================================

def save_government_alert(
    prediction_id,
    prediction,
    location
):
    alert_id = str(
        uuid.uuid4()
    )

    now = datetime.now(
        timezone.utc
    ).isoformat()

    class_name = prediction[
        "class_name"
    ]

    # Try to extract crop from:
    # "apple black rot"
    # "tomato late blight"
    # etc.

    parts = class_name.split()

    if len(parts) >= 2:
        crop = parts[0]
    else:
        crop = class_name

    disease = class_name

    conn = get_db()

    cursor = conn.cursor()

    cursor.execute("""
        INSERT INTO government_alerts (
            alert_id,
            prediction_id,
            crop,
            disease,
            class_id,
            confidence,
            severity,
            status,
            latitude,
            longitude,
            district,
            state,
            created_at,
            updated_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, (
        alert_id,
        prediction_id,
        crop,
        disease,
        prediction["class_id"],
        prediction["confidence"],
        prediction["severity"],
        "pending",
        location["latitude"],
        location["longitude"],
        location["district"],
        location["state"],
        now,
        now
    ))

    conn.commit()
    conn.close()

    print(
        f"[GOVERNMENT ALERT] "
        f"{alert_id} | "
        f"{disease} | "
        f"{prediction['confidence']}% | "
        f"{prediction['severity']}"
    )

    return alert_id


# ============================================================
# SERIALIZE ALERT
# ============================================================

def alert_to_dict(row):
    return {
        "alert_id": row["alert_id"],
        "prediction_id": row["prediction_id"],

        "crop": row["crop"],
        "disease": row["disease"],
        "class_id": row["class_id"],

        "confidence": row["confidence"],
        "severity": row["severity"],
        "status": row["status"],

        "location": {
            "latitude": row["latitude"],
            "longitude": row["longitude"],
            "district": row["district"],
            "state": row["state"]
        },

        "created_at": row["created_at"],
        "updated_at": row["updated_at"]
    }


# ============================================================
# HEALTH
# ============================================================

@app.route(
    "/api/health",
    methods=["GET"]
)
def health():
    return jsonify({
        "status": "ok",
        "service": "Krishi Rakshak API",
        "model": "krishi_rakshak.tflite",
        "classes": len(classes),
        "input_size": INPUT_SIZE,
        "database": os.path.exists(DB_PATH),
        "timestamp": datetime.now(
            timezone.utc
        ).isoformat()
    })


# ============================================================
# CLASSES
# ============================================================

@app.route(
    "/api/classes",
    methods=["GET"]
)
def get_classes():
    return jsonify({
        "count": len(classes),
        "classes": {
            str(i): classes[i]
            for i in range(len(classes))
        }
    })


# ============================================================
# PREDICT
# ============================================================

@app.route(
    "/api/predict",
    methods=["POST"]
)
def predict():
    prediction_id = str(
        uuid.uuid4()
    )

    try:

        if "image" not in request.files:
            return jsonify({
                "success": False,
                "error": "No image uploaded. Use field name 'image'."
            }), 400

        image_file = request.files[
            "image"
        ]

        if image_file.filename == "":
            return jsonify({
                "success": False,
                "error": "Empty image filename."
            }), 400

        prediction = predict_image(
            image_file
        )

        severity = calculate_severity(
            prediction["class_name"],
            prediction["confidence"]
        )

        prediction["severity"] = severity

        # Optional weather context supplied by the frontend.
        weather = get_optional_weather(request.form)

        risk_assessment = calculate_risk_assessment(
            prediction["class_name"],
            prediction["confidence"],
            severity,
            weather
        )

        # Keep the existing alert rule intact for backward compatibility.
        # Risk assessment is added as decision-support context.
        alert_required = government_alert_required(
            prediction["class_name"],
            prediction["confidence"],
            severity
        )

        if is_healthy(
            prediction["class_name"]
        ):
            status = "healthy"

        elif prediction["confidence"] >= 50:
            status = "disease_detected"

        else:
            status = "low_confidence"

        location = get_optional_location(
            request.form
        )

        alert_id = None
        alert_status = "not_required"

        if alert_required:

            alert_id = save_government_alert(
                prediction_id,
                prediction,
                location
            )

            alert_status = "pending"

        timestamp = datetime.now(
            timezone.utc
        ).isoformat()

        response = {
            "success": True,

            "prediction_id": prediction_id,
            "timestamp": timestamp,

            "prediction": {
                "class_id": prediction["class_id"],
                "class_name": prediction["class_name"],
                "confidence": prediction["confidence"],
                "status": status,
                "severity": severity
            },

            "risk_assessment": risk_assessment,

            "government_alert": {
                "required": alert_required,
                "alert_id": alert_id,
                "status": alert_status
            },

            "top_predictions": prediction[
                "top_predictions"
            ]
        }

        return jsonify(response), 200

    except Exception as e:

        print(
            f"[PREDICTION ERROR] {e}"
        )

        return jsonify({
            "success": False,
            "prediction_id": prediction_id,
            "error": str(e)
        }), 500


# ============================================================
# HOTSPOTS / GIS AGGREGATION
# ============================================================

@app.route("/api/hotspots", methods=["GET"])
def get_hotspots():
    """Return aggregated disease hotspots from stored government alerts."""
    try:
        state = request.args.get("state")
        district = request.args.get("district")
        disease = request.args.get("disease")
        severity = request.args.get("severity")
        limit = request.args.get("limit", default=100, type=int)
        limit = max(1, min(limit, 500))

        where = ["1=1"]
        params = []
        for column, value in (("state", state), ("district", district), ("disease", disease), ("severity", severity)):
            if value:
                where.append(f"LOWER({column}) = LOWER(?)")
                params.append(value)

        conn = get_db()
        rows = conn.execute(f"""
            SELECT state, district, disease, severity,
                   COUNT(*) AS alert_count,
                   ROUND(AVG(confidence), 2) AS avg_confidence,
                   ROUND(AVG(latitude), 6) AS latitude,
                   ROUND(AVG(longitude), 6) AS longitude,
                   MIN(created_at) AS first_seen,
                   MAX(created_at) AS last_seen
            FROM government_alerts
            WHERE {' AND '.join(where)}
            GROUP BY state, district, disease, severity
            ORDER BY alert_count DESC, last_seen DESC
            LIMIT ?
        """, (*params, limit)).fetchall()
        conn.close()

        hotspots = []
        for row in rows:
            hotspots.append({
                "state": row["state"],
                "district": row["district"],
                "disease": row["disease"],
                "severity": row["severity"],
                "alert_count": row["alert_count"],
                "avg_confidence": row["avg_confidence"],
                "location": {"latitude": row["latitude"], "longitude": row["longitude"]},
                "first_seen": row["first_seen"],
                "last_seen": row["last_seen"]
            })

        return jsonify({
            "success": True,
            "count": len(hotspots),
            "hotspots": hotspots,
            "filters": {"state": state, "district": district, "disease": disease, "severity": severity}
        }), 200
    except Exception as e:
        print(f"[HOTSPOT ERROR] {e}")
        return jsonify({"success": False, "error": str(e)}), 500


@app.route("/api/hotspots/summary", methods=["GET"])
def hotspot_summary():
    """Return dashboard-ready totals and severity distribution."""
    try:
        conn = get_db()
        totals = conn.execute("""
            SELECT COUNT(*) AS total_alerts,
                   COUNT(DISTINCT disease) AS diseases,
                   COUNT(DISTINCT state) AS states,
                   COUNT(DISTINCT district) AS districts,
                   ROUND(AVG(confidence), 2) AS avg_confidence
            FROM government_alerts
        """).fetchone()
        severity_rows = conn.execute("""
            SELECT severity, COUNT(*) AS count
            FROM government_alerts
            GROUP BY severity
        """).fetchall()
        conn.close()

        return jsonify({
            "success": True,
            "summary": {
                "total_alerts": totals["total_alerts"],
                "diseases": totals["diseases"],
                "states": totals["states"],
                "districts": totals["districts"],
                "avg_confidence": totals["avg_confidence"]
            },
            "severity_distribution": {row["severity"]: row["count"] for row in severity_rows}
        }), 200
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


# ============================================================
# MANUAL GOVERNMENT ALERT
# ============================================================

@app.route(
    "/api/government/alert",
    methods=["POST"]
)
def government_alert():

    try:

        data = request.get_json(
            silent=True
        ) or {}

        prediction_id = data.get(
            "prediction_id"
        )

        prediction_data = data.get(
            "prediction"
        )

        if not prediction_data:
            return jsonify({
                "success": False,
                "error": "prediction object is required"
            }), 400

        prediction = {
            "class_id": prediction_data.get(
                "class_id"
            ),
            "class_name": prediction_data.get(
                "class_name",
                "unknown"
            ),
            "confidence": float(
                prediction_data.get(
                    "confidence",
                    0
                )
            ),
            "severity": prediction_data.get(
                "severity",
                "medium"
            )
        }

        location = {
            "latitude": data.get(
                "latitude"
            ),
            "longitude": data.get(
                "longitude"
            ),
            "district": data.get(
                "district"
            ),
            "state": data.get(
                "state"
            )
        }

        alert_id = save_government_alert(
            prediction_id,
            prediction,
            location
        )

        return jsonify({
            "success": True,
            "alert_id": alert_id,
            "status": "received"
        }), 201

    except Exception as e:

        return jsonify({
            "success": False,
            "error": str(e)
        }), 500


# ============================================================
# GET ALL GOVERNMENT ALERTS
# ============================================================

@app.route(
    "/api/government/alerts",
    methods=["GET"]
)
def get_government_alerts():

    try:

        status = request.args.get(
            "status"
        )

        severity = request.args.get(
            "severity"
        )

        limit = request.args.get(
            "limit",
            default=100,
            type=int
        )

        limit = max(
            1,
            min(limit, 1000)
        )

        conn = get_db()

        query = """
            SELECT *
            FROM government_alerts
            WHERE 1 = 1
        """

        params = []

        if status:
            query += """
                AND status = ?
            """
            params.append(status)

        if severity:
            query += """
                AND severity = ?
            """
            params.append(severity)

        query += """
            ORDER BY created_at DESC
            LIMIT ?
        """

        params.append(limit)

        rows = conn.execute(
            query,
            params
        ).fetchall()

        conn.close()

        alerts = [
            alert_to_dict(row)
            for row in rows
        ]

        return jsonify({
            "success": True,
            "count": len(alerts),
            "alerts": alerts
        })

    except Exception as e:

        return jsonify({
            "success": False,
            "error": str(e)
        }), 500


# ============================================================
# GET SINGLE ALERT
# ============================================================

@app.route(
    "/api/government/alerts/<alert_id>",
    methods=["GET"]
)
def get_single_alert(alert_id):

    conn = get_db()

    row = conn.execute("""
        SELECT *
        FROM government_alerts
        WHERE alert_id = ?
    """, (
        alert_id,
    )).fetchone()

    conn.close()

    if row is None:
        return jsonify({
            "success": False,
            "error": "Alert not found"
        }), 404

    return jsonify({
        "success": True,
        "alert": alert_to_dict(row)
    })


# ============================================================
# UPDATE ALERT STATUS
# ============================================================

@app.route(
    "/api/government/alerts/<alert_id>/status",
    methods=["POST", "PUT", "PATCH"]
)
def update_alert_status(alert_id):

    try:

        data = request.get_json(
            silent=True
        ) or {}

        new_status = data.get(
            "status"
        )

        allowed_statuses = [
            "pending",
            "verified",
            "resolved",
            "rejected"
        ]

        if new_status not in allowed_statuses:
            return jsonify({
                "success": False,
                "error": (
                    "Invalid status. "
                    f"Allowed: {allowed_statuses}"
                )
            }), 400

        now = datetime.now(
            timezone.utc
        ).isoformat()

        conn = get_db()

        cursor = conn.cursor()

        cursor.execute("""
            UPDATE government_alerts
            SET status = ?,
                updated_at = ?
            WHERE alert_id = ?
        """, (
            new_status,
            now,
            alert_id
        ))

        if cursor.rowcount == 0:
            conn.close()

            return jsonify({
                "success": False,
                "error": "Alert not found"
            }), 404

        conn.commit()

        row = conn.execute("""
            SELECT *
            FROM government_alerts
            WHERE alert_id = ?
        """, (
            alert_id,
        )).fetchone()

        conn.close()

        return jsonify({
            "success": True,
            "message": "Alert status updated",
            "alert": alert_to_dict(row)
        })

    except Exception as e:

        return jsonify({
            "success": False,
            "error": str(e)
        }), 500


# ============================================================
# GOVERNMENT DASHBOARD STATS
# ============================================================

@app.route(
    "/api/government/stats",
    methods=["GET"]
)
def government_stats():

    try:

        conn = get_db()

        total = conn.execute("""
            SELECT COUNT(*)
            FROM government_alerts
        """).fetchone()[0]

        pending = conn.execute("""
            SELECT COUNT(*)
            FROM government_alerts
            WHERE status = 'pending'
        """).fetchone()[0]

        verified = conn.execute("""
            SELECT COUNT(*)
            FROM government_alerts
            WHERE status = 'verified'
        """).fetchone()[0]

        resolved = conn.execute("""
            SELECT COUNT(*)
            FROM government_alerts
            WHERE status = 'resolved'
        """).fetchone()[0]

        high = conn.execute("""
            SELECT COUNT(*)
            FROM government_alerts
            WHERE severity = 'high'
        """).fetchone()[0]

        medium = conn.execute("""
            SELECT COUNT(*)
            FROM government_alerts
            WHERE severity = 'medium'
        """).fetchone()[0]

        low = conn.execute("""
            SELECT COUNT(*)
            FROM government_alerts
            WHERE severity = 'low'
        """).fetchone()[0]

        disease_rows = conn.execute("""
            SELECT
                disease,
                COUNT(*) AS count
            FROM government_alerts
            GROUP BY disease
            ORDER BY count DESC
            LIMIT 10
        """).fetchall()

        crop_rows = conn.execute("""
            SELECT
                crop,
                COUNT(*) AS count
            FROM government_alerts
            GROUP BY crop
            ORDER BY count DESC
            LIMIT 10
        """).fetchall()

        district_rows = conn.execute("""
            SELECT
                district,
                COUNT(*) AS count
            FROM government_alerts
            WHERE district IS NOT NULL
              AND district != ''
            GROUP BY district
            ORDER BY count DESC
            LIMIT 10
        """).fetchall()

        conn.close()

        return jsonify({
            "success": True,

            "total_alerts": total,

            "status": {
                "pending": pending,
                "verified": verified,
                "resolved": resolved
            },

            "severity": {
                "high": high,
                "medium": medium,
                "low": low
            },

            "top_diseases": [
                {
                    "disease": row["disease"],
                    "count": row["count"]
                }
                for row in disease_rows
            ],

            "top_crops": [
                {
                    "crop": row["crop"],
                    "count": row["count"]
                }
                for row in crop_rows
            ],

            "top_districts": [
                {
                    "district": row["district"],
                    "count": row["count"]
                }
                for row in district_rows
            ]
        })

    except Exception as e:

        return jsonify({
            "success": False,
            "error": str(e)
        }), 500


# ============================================================
# DELETE ALERT - ADMIN USE
# ============================================================

@app.route(
    "/api/government/alerts/<alert_id>",
    methods=["DELETE"]
)
def delete_alert(alert_id):

    try:

        conn = get_db()

        cursor = conn.cursor()

        cursor.execute("""
            DELETE FROM government_alerts
            WHERE alert_id = ?
        """, (
            alert_id,
        ))

        if cursor.rowcount == 0:
            conn.close()

            return jsonify({
                "success": False,
                "error": "Alert not found"
            }), 404

        conn.commit()
        conn.close()

        return jsonify({
            "success": True,
            "message": "Alert deleted",
            "alert_id": alert_id
        })

    except Exception as e:

        return jsonify({
            "success": False,
            "error": str(e)
        }), 500



# ============================================================
# AI ADVICE + AI CHAT
# ============================================================

def _kr_language_name(code):
    names = {
        "en": "English",
        "hi": "Hindi",
        "pa": "Punjabi",
        "mr": "Marathi",
        "bn": "Bengali",
        "gu": "Gujarati",
        "ta": "Tamil",
        "te": "Telugu",
        "kn": "Kannada",
        "ml": "Malayalam",
    }
    return names.get(str(code or "en").lower(), "English")


def _kr_disease_advice(disease, crop, language):
    disease_l = str(disease or "").lower()
    crop = str(crop or "crop")
    lang = str(language or "en").lower()

    healthy = ("healthy" in disease_l) or ("normal" in disease_l)

    if healthy:
        en = {
            "summary": f"The {crop} leaf appears healthy according to the AI prediction.",
            "farmer_action": "Continue regular field monitoring, balanced nutrition, irrigation, and sanitation.",
            "treatment": "No disease treatment is indicated from this prediction.",
            "prevention": "Keep the field clean, monitor new growth, and inspect plants regularly for early symptoms.",
        }
    elif any(x in disease_l for x in ["virus", "viral", "mosaic", "yellow leaf curl"]):
        en = {
            "summary": f"The AI detected a possible viral disease in {crop}.",
            "farmer_action": "Isolate clearly affected plants where practical, remove severely affected material safely, control insect vectors, and monitor nearby plants.",
            "treatment": "Viral diseases generally do not have a direct curative chemical treatment. Use locally recommended vector-management and sanitation practices.",
            "prevention": "Use healthy planting material, manage insect vectors, remove infected plant debris, and avoid moving infected material between fields.",
        }
    elif any(x in disease_l for x in ["bacterial", "bacterial spot", "fire blight", "canker"]):
        en = {
            "summary": f"The AI detected a possible bacterial disease in {crop}.",
            "farmer_action": "Remove severely affected plant parts where appropriate, avoid unnecessary leaf wetting, sanitize tools, and monitor spread.",
            "treatment": "Use only a locally registered product if recommended for this crop and disease. Follow the product label and local agricultural guidance exactly.",
            "prevention": "Use clean planting material, improve field sanitation, avoid working wet foliage, and manage irrigation to reduce prolonged leaf wetness.",
        }
    elif any(x in disease_l for x in ["late blight", "early blight", "black rot", "rust", "scab", "leaf spot", "powdery", "mildew", "rot", "wilt"]):
        en = {
            "summary": f"The AI detected a possible fungal or fungal-like disease in {crop}.",
            "farmer_action": "Remove heavily affected material where appropriate, improve airflow, avoid prolonged leaf wetness, and monitor the surrounding crop.",
            "treatment": "Use only a locally registered fungicide/product when appropriate for this crop and disease. Follow the product label and local agricultural guidance; do not use an invented dose.",
            "prevention": "Use resistant or healthy planting material where available, maintain sanitation, improve spacing/airflow, and manage irrigation carefully.",
        }
    else:
        en = {
            "summary": f"The AI detected {disease} in {crop}.",
            "farmer_action": "Inspect several plants and compare symptoms before taking large-scale action. Remove severely affected material where appropriate and monitor spread.",
            "treatment": "Use only a locally registered treatment confirmed for this crop and disease. Follow the product label and local agricultural guidance.",
            "prevention": "Maintain field sanitation, use healthy planting material, monitor regularly, and avoid practices that increase disease spread.",
        }

    # Keep the API useful without pretending that translations are authoritative.
    if lang == "hi":
        return {
            "summary": f"AI à¤•à¥‡ à¤…à¤¨à¥à¤¸à¤¾à¤° {crop} à¤®à¥‡à¤‚ {disease} à¤•à¥€ à¤¸à¤‚à¤­à¤¾à¤µà¤¨à¤¾ à¤¹à¥ˆà¥¤",
            "farmer_action": "à¤ªà¥à¤°à¤­à¤¾à¤µà¤¿à¤¤ à¤ªà¥Œà¤§à¥‹à¤‚ à¤•à¥€ à¤œà¤¾à¤à¤š à¤•à¤°à¥‡à¤‚, à¤¬à¤¹à¥à¤¤ à¤…à¤§à¤¿à¤• à¤ªà¥à¤°à¤­à¤¾à¤µà¤¿à¤¤ à¤­à¤¾à¤—à¥‹à¤‚ à¤•à¥‹ à¤‰à¤šà¤¿à¤¤ à¤¤à¤°à¥€à¤•à¥‡ à¤¸à¥‡ à¤¹à¤Ÿà¤¾à¤à¤ à¤”à¤° à¤†à¤¸à¤ªà¤¾à¤¸ à¤•à¥‡ à¤ªà¥Œà¤§à¥‹à¤‚ à¤•à¥€ à¤¨à¤¿à¤—à¤°à¤¾à¤¨à¥€ à¤•à¤°à¥‡à¤‚à¥¤",
            "treatment": "à¤•à¥‡à¤µà¤² à¤‡à¤¸ à¤«à¤¸à¤² à¤”à¤° à¤°à¥‹à¤— à¤•à¥‡ à¤²à¤¿à¤ à¤¸à¥à¤¥à¤¾à¤¨à¥€à¤¯ à¤°à¥‚à¤ª à¤¸à¥‡ à¤ªà¤‚à¤œà¥€à¤•à¥ƒà¤¤ à¤¦à¤µà¤¾/à¤‰à¤¤à¥à¤ªà¤¾à¤¦ à¤•à¤¾ à¤‰à¤ªà¤¯à¥‹à¤— à¤•à¤°à¥‡à¤‚à¥¤ à¤²à¥‡à¤¬à¤² à¤”à¤° à¤•à¥ƒà¤·à¤¿ à¤µà¤¿à¤­à¤¾à¤— à¤•à¥€ à¤¸à¤²à¤¾à¤¹ à¤•à¤¾ à¤ªà¤¾à¤²à¤¨ à¤•à¤°à¥‡à¤‚; à¤…à¤¨à¥à¤®à¤¾à¤¨à¤¿à¤¤ à¤®à¤¾à¤¤à¥à¤°à¤¾ à¤¨ à¤²à¥‡à¤‚à¥¤",
            "prevention": "à¤–à¥‡à¤¤ à¤•à¥€ à¤¸à¥à¤µà¤šà¥à¤›à¤¤à¤¾ à¤°à¤–à¥‡à¤‚, à¤¸à¥à¤µà¤¸à¥à¤¥ à¤°à¥‹à¤ªà¤£ à¤¸à¤¾à¤®à¤—à¥à¤°à¥€ à¤•à¤¾ à¤‰à¤ªà¤¯à¥‹à¤— à¤•à¤°à¥‡à¤‚ à¤”à¤° à¤¨à¤¿à¤¯à¤®à¤¿à¤¤ à¤¨à¤¿à¤—à¤°à¤¾à¤¨à¥€ à¤•à¤°à¥‡à¤‚à¥¤",
        } if not healthy else {
            "summary": f"AI à¤•à¥‡ à¤…à¤¨à¥à¤¸à¤¾à¤° {crop} à¤•à¤¾ à¤ªà¤¤à¥à¤¤à¤¾ à¤¸à¥à¤µà¤¸à¥à¤¥ à¤¦à¤¿à¤–à¤¾à¤ˆ à¤¦à¥‡ à¤°à¤¹à¤¾ à¤¹à¥ˆà¥¤",
            "farmer_action": "à¤¨à¤¿à¤¯à¤®à¤¿à¤¤ à¤¨à¤¿à¤—à¤°à¤¾à¤¨à¥€, à¤¸à¤‚à¤¤à¥à¤²à¤¿à¤¤ à¤ªà¥‹à¤·à¤£, à¤‰à¤šà¤¿à¤¤ à¤¸à¤¿à¤‚à¤šà¤¾à¤ˆ à¤”à¤° à¤–à¥‡à¤¤ à¤•à¥€ à¤¸à¥à¤µà¤šà¥à¤›à¤¤à¤¾ à¤œà¤¾à¤°à¥€ à¤°à¤–à¥‡à¤‚à¥¤",
            "treatment": "à¤‡à¤¸ à¤…à¤¨à¥à¤®à¤¾à¤¨ à¤•à¥‡ à¤†à¤§à¤¾à¤° à¤ªà¤° à¤•à¤¿à¤¸à¥€ à¤°à¥‹à¤— à¤‰à¤ªà¤šà¤¾à¤° à¤•à¥€ à¤†à¤µà¤¶à¥à¤¯à¤•à¤¤à¤¾ à¤¨à¤¹à¥€à¤‚ à¤¬à¤¤à¤¾à¤ˆ à¤—à¤ˆ à¤¹à¥ˆà¥¤",
            "prevention": "à¤–à¥‡à¤¤ à¤¸à¤¾à¤« à¤°à¤–à¥‡à¤‚ à¤”à¤° à¤¨à¤ˆ à¤µà¥ƒà¤¦à¥à¤§à¤¿ à¤®à¥‡à¤‚ à¤²à¤•à¥à¤·à¤£à¥‹à¤‚ à¤•à¥€ à¤¨à¤¿à¤¯à¤®à¤¿à¤¤ à¤œà¤¾à¤à¤š à¤•à¤°à¥‡à¤‚à¥¤",
        }

    if lang == "pa":
        return {
            "summary": f"AI à¨¦à©‡ à¨…à¨¨à©à¨¸à¨¾à¨° {crop} à¨µà¨¿à©±à¨š {disease} à¨¦à©€ à¨¸à©°à¨­à¨¾à¨µà¨¨à¨¾ à¨¹à©ˆà¥¤",
            "farmer_action": "à¨ªà©à¨°à¨­à¨¾à¨µà¨¿à¨¤ à¨ªà©Œà¨¦à¨¿à¨†à¨‚ à¨¦à©€ à¨œà¨¾à¨‚à¨š à¨•à¨°à©‹, à¨¬à¨¹à©à¨¤ à¨ªà©à¨°à¨­à¨¾à¨µà¨¿à¨¤ à¨¹à¨¿à©±à¨¸à¨¿à¨†à¨‚ à¨¨à©‚à©° à¨¢à©à©±à¨•à¨µà©‡à¨‚ à¨¤à¨°à©€à¨•à©‡ à¨¨à¨¾à¨² à¨¹à¨Ÿà¨¾à¨“ à¨…à¨¤à©‡ à¨¨à©‡à©œà¨²à©‡ à¨ªà©Œà¨¦à¨¿à¨†à¨‚ à¨¦à©€ à¨¨à¨¿à¨—à¨°à¨¾à¨¨à©€ à¨•à¨°à©‹à¥¤",
            "treatment": "à¨•à©‡à¨µà¨² à¨‡à¨¸ à¨«à¨¸à¨² à¨…à¨¤à©‡ à¨°à©‹à¨— à¨²à¨ˆ à¨¸à¨¥à¨¾à¨¨à¨• à¨¤à©Œà¨° 'à¨¤à©‡ à¨°à¨œà¨¿à¨¸à¨Ÿà¨°à¨¡ à¨‰à¨¤à¨ªà¨¾à¨¦ à¨µà¨°à¨¤à©‹ à¨…à¨¤à©‡ à¨²à©‡à¨¬à¨² à¨¦à©€ à¨¹à¨¦à¨¾à¨‡à¨¤ à¨®à©°à¨¨à©‹à¥¤",
            "prevention": "à¨–à©‡à¨¤ à¨¦à©€ à¨¸à¨«à¨¾à¨ˆ à¨°à©±à¨–à©‹, à¨¸à¨¿à¨¹à¨¤à¨®à©°à¨¦ à¨°à©‹à¨ªà¨£ à¨¸à¨®à©±à¨—à¨°à©€ à¨µà¨°à¨¤à©‹ à¨…à¨¤à©‡ à¨¨à¨¿à¨¯à¨®à¨¿à¨¤ à¨¨à¨¿à¨—à¨°à¨¾à¨¨à©€ à¨•à¨°à©‹à¥¤",
        }

    if lang == "mr":
        return {
            "summary": f"AI à¤¨à¥à¤¸à¤¾à¤° {crop} à¤®à¤§à¥à¤¯à¥‡ {disease} à¤šà¥€ à¤¶à¤•à¥à¤¯à¤¤à¤¾ à¤†à¤¹à¥‡.",
            "farmer_action": "à¤¬à¤¾à¤§à¤¿à¤¤ à¤à¤¾à¤¡à¤¾à¤‚à¤šà¥€ à¤¤à¤ªà¤¾à¤¸à¤£à¥€ à¤•à¤°à¤¾, à¤œà¤¾à¤¸à¥à¤¤ à¤¬à¤¾à¤§à¤¿à¤¤ à¤­à¤¾à¤— à¤¯à¥‹à¤—à¥à¤¯ à¤ªà¤¦à¥à¤§à¤¤à¥€à¤¨à¥‡ à¤•à¤¾à¤¢à¤¾ à¤†à¤£à¤¿ à¤†à¤¸à¤ªà¤¾à¤¸à¤šà¥à¤¯à¤¾ à¤à¤¾à¤¡à¤¾à¤‚à¤µà¤° à¤²à¤•à¥à¤· à¤ à¥‡à¤µà¤¾.",
            "treatment": "à¤«à¤•à¥à¤¤ à¤¯à¤¾ à¤ªà¤¿à¤•à¤¾à¤¸à¤¾à¤ à¥€ à¤†à¤£à¤¿ à¤°à¥‹à¤—à¤¾à¤¸à¤¾à¤ à¥€ à¤¸à¥à¤¥à¤¾à¤¨à¤¿à¤• à¤ªà¤¾à¤¤à¤³à¥€à¤µà¤° à¤¨à¥‹à¤‚à¤¦à¤£à¥€à¤•à¥ƒà¤¤ à¤‰à¤¤à¥à¤ªà¤¾à¤¦à¤¨ à¤µà¤¾à¤ªà¤°à¤¾ à¤†à¤£à¤¿ à¤²à¥‡à¤¬à¤² à¤µ à¤•à¥ƒà¤·à¥€ à¤®à¤¾à¤°à¥à¤—à¤¦à¤°à¥à¤¶à¤¨à¤¾à¤šà¥‡ à¤ªà¤¾à¤²à¤¨ à¤•à¤°à¤¾.",
            "prevention": "à¤¶à¥‡à¤¤à¤¾à¤šà¥€ à¤¸à¥à¤µà¤šà¥à¤›à¤¤à¤¾ à¤ à¥‡à¤µà¤¾, à¤¨à¤¿à¤°à¥‹à¤—à¥€ à¤²à¤¾à¤—à¤µà¤¡ à¤¸à¤¾à¤¹à¤¿à¤¤à¥à¤¯ à¤µà¤¾à¤ªà¤°à¤¾ à¤†à¤£à¤¿ à¤¨à¤¿à¤¯à¤®à¤¿à¤¤ à¤¨à¤¿à¤°à¥€à¤•à¥à¤·à¤£ à¤•à¤°à¤¾.",
        }

    if lang == "bn":
        return {
            "summary": f"AI à¦…à¦¨à§à¦¯à¦¾à¦¯à¦¼à§€ {crop}-à¦ {disease} à¦¹à¦“à¦¯à¦¼à¦¾à¦° à¦¸à¦®à§à¦­à¦¾à¦¬à¦¨à¦¾ à¦°à¦¯à¦¼à§‡à¦›à§‡à¥¤",
            "farmer_action": "à¦†à¦•à§à¦°à¦¾à¦¨à§à¦¤ à¦—à¦¾à¦› à¦ªà¦°à§€à¦•à§à¦·à¦¾ à¦•à¦°à§à¦¨, à¦—à§à¦°à§à¦¤à¦° à¦†à¦•à§à¦°à¦¾à¦¨à§à¦¤ à¦…à¦‚à¦¶ à¦¯à¦¥à¦¾à¦¯à¦¥à¦­à¦¾à¦¬à§‡ à¦¸à¦°à¦¾à¦¨ à¦à¦¬à¦‚ à¦†à¦¶à§‡à¦ªà¦¾à¦¶à§‡à¦° à¦—à¦¾à¦› à¦ªà¦°à§à¦¯à¦¬à§‡à¦•à§à¦·à¦£ à¦•à¦°à§à¦¨à¥¤",
            "treatment": "à¦¶à§à¦§à§ à¦à¦‡ à¦«à¦¸à¦² à¦“ à¦°à§‹à¦—à§‡à¦° à¦œà¦¨à§à¦¯ à¦¸à§à¦¥à¦¾à¦¨à§€à¦¯à¦¼à¦­à¦¾à¦¬à§‡ à¦¨à¦¿à¦¬à¦¨à§à¦§à¦¿à¦¤ à¦ªà¦£à§à¦¯ à¦¬à§à¦¯à¦¬à¦¹à¦¾à¦° à¦•à¦°à§à¦¨ à¦à¦¬à¦‚ à¦²à§‡à¦¬à§‡à¦² à¦“ à¦•à§ƒà¦·à¦¿ à¦ªà¦°à¦¾à¦®à¦°à§à¦¶ à¦…à¦¨à§à¦¸à¦°à¦£ à¦•à¦°à§à¦¨à¥¤",
            "prevention": "à¦•à§à¦·à§‡à¦¤ à¦ªà¦°à¦¿à¦·à§à¦•à¦¾à¦° à¦°à¦¾à¦–à§à¦¨, à¦¸à§à¦¸à§à¦¥ à¦°à§‹à¦ªà¦£ à¦‰à¦ªà¦•à¦°à¦£ à¦¬à§à¦¯à¦¬à¦¹à¦¾à¦° à¦•à¦°à§à¦¨ à¦à¦¬à¦‚ à¦¨à¦¿à¦¯à¦¼à¦®à¦¿à¦¤ à¦ªà¦°à§à¦¯à¦¬à§‡à¦•à§à¦·à¦£ à¦•à¦°à§à¦¨à¥¤",
        }

    return en


def _gemini_advice_details(disease, crop, confidence, language):
    if not GEMINI_API_KEY:
        raise RuntimeError("GEMINI_API_KEY is not configured")
    language_name = _language_instruction(language)
    prompt = f"""You are Krishi Rakshak, an expert agricultural advisor for Indian farmers.
Crop: {crop}
Suspected disease: {disease}
AI confidence: {confidence if confidence is not None else 'N/A'}%

Reply ONLY in {language_name}. Answer the farmer's treatment question practically. The farmer needs to know which medicine/spray can be used. When chemical control is appropriate, give the relevant active ingredient(s) and, only if confident, common registered product examples for this crop and disease. Tell the farmer to verify current registration in India and follow the product label. Never invent a product, dose, concentration, tank mix, waiting period, or spray interval. If the diagnosis is uncertain, say to confirm it before spraying. Also include prevention and immediate farmer actions.
Return JSON only with exactly: description, treatment, prevention, farmer_action."""
    payload=json.dumps({"contents":[{"role":"user","parts":[{"text":prompt}]}],"generationConfig":{"maxOutputTokens":1200,"thinkingConfig":{"thinkingLevel":"low"},"responseMimeType":"application/json"}}).encode('utf-8')
    opener=urllib.request.build_opener(urllib.request.ProxyHandler({})); last=None
    for model in GEMINI_FALLBACK_MODELS:
        if not model: continue
        req=urllib.request.Request(f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent",data=payload,headers={"Content-Type":"application/json","Accept":"application/json","x-goog-api-key":GEMINI_API_KEY},method="POST")
        try:
            with opener.open(req,timeout=GEMINI_TIMEOUT_SECONDS) as r:
                raw=r.read().decode('utf-8','replace')
            d=json.loads(raw); candidates=d.get('candidates') or []
            if not candidates: raise RuntimeError(f"Gemini {model} returned no candidates")
            parts=candidates[0].get('content',{}).get('parts',[])
            txt=''.join(str(x.get('text') or '') for x in parts if isinstance(x,dict)).strip()
            obj=json.loads(txt)
            keys=['description','treatment','prevention','farmer_action']
            if not all(isinstance(obj.get(k),str) and obj[k].strip() for k in keys): raise RuntimeError('Invalid Gemini advice JSON')
            print(f"[GEMINI ADVICE] SUCCESS: {model}")
            return {k:obj[k].strip() for k in keys}
        except Exception as e:
            last=e; print(f"[GEMINI ADVICE] {model} -> {e}")
    raise last or RuntimeError("All Gemini models failed for advice")


@app.route("/api/advice", methods=["POST"])
def ai_advice():
    try:
        data=request.get_json(silent=True) or {}
        disease=data.get("disease") or data.get("class_name") or "unknown disease"
        crop=data.get("crop") or "crop"
        language=str(data.get("language") or "en").lower()
        confidence=data.get("confidence")
        if language not in {"en","hi","pa","mr","bn","gu","ta","te","kn","ml"}: language="en"
        try:
            advice=_gemini_advice_details(disease,crop,confidence,language)
            source="gemini_ai_advice"
        except Exception as e:
            print(f"[GEMINI ADVICE FALLBACK] {e}")
            advice=_kr_disease_advice(disease,crop,language)
            if "description" not in advice and "summary" in advice:
                advice["description"]=advice["summary"]
            source="local_ai_advice"
        return jsonify({"success":True,"source":source,"language":language,"language_name":_kr_language_name(language),"crop":crop,"disease":disease,"confidence":confidence,"advice":advice,"disclaimer":"AI guidance is informational. Confirm diagnosis and treatment with a qualified local agriculture professional or official agricultural guidance before applying any crop-protection product."}),200
    except Exception as e:
        print(f"[AI ADVICE ERROR] {e}")
        return jsonify({"success":False,"error":str(e)}),500




def _language_instruction(language):
    names = {
        "en": "English", "hi": "Hindi", "pa": "Punjabi", "mr": "Marathi",
        "bn": "Bengali", "gu": "Gujarati", "ta": "Tamil", "te": "Telugu",
        "kn": "Kannada", "ml": "Malayalam",
    }
    return names.get(language, "English")


def _local_chat_fallback(message, language, crop, disease, confidence):
    """Fast offline fallback. It reacts to the actual question instead of one fixed answer."""
    q = message.lower()
    advice = _kr_disease_advice(disease, crop, language)
    lang = language

    # Expert/consultant request
    expert_words = ["expert", "doctor", "consult", "consultant", "scientist", "à¤µà¤¿à¤¶à¥‡à¤·à¤œà¥à¤ž", "à¤¸à¤²à¤¾à¤¹à¤•à¤¾à¤°", "à¨¡à¨¾à¨•à¨Ÿà¨°", "à¨®à¨¾à¨¹à¨°", "à¤¤à¤œà¥à¤ž", "à¤µà¤¿à¤¶à¥‡à¤·à¤œà¥à¤ž"]
    if any(x in q for x in expert_words):
        texts = {
            "en": "I can connect you with agriculture experts. Open the 'Expert Consultant' section to call or email an official agriculture referral contact.",
            "hi": "à¤®à¥ˆà¤‚ à¤†à¤ªà¤•à¥‹ à¤•à¥ƒà¤·à¤¿ à¤µà¤¿à¤¶à¥‡à¤·à¤œà¥à¤ž à¤¸à¥‡ à¤œà¥‹à¤¡à¤¼ à¤¸à¤•à¤¤à¤¾ à¤¹à¥‚à¤à¥¤ â€˜à¤µà¤¿à¤¶à¥‡à¤·à¤œà¥à¤ž à¤¸à¤²à¤¾à¤¹â€™ à¤¸à¥‡à¤•à¥à¤¶à¤¨ à¤–à¥‹à¤²à¤•à¤° à¤†à¤§à¤¿à¤•à¤¾à¤°à¤¿à¤• à¤•à¥ƒà¤·à¤¿ à¤¸à¤‚à¤ªà¤°à¥à¤• à¤•à¥‹ à¤•à¥‰à¤² à¤¯à¤¾ à¤ˆà¤®à¥‡à¤² à¤•à¤°à¥‡à¤‚à¥¤",
            "pa": "à¨®à©ˆà¨‚ à¨¤à©à¨¹à¨¾à¨¨à©‚à©° à¨–à©‡à¨¤à©€ à¨®à¨¾à¨¹à¨¿à¨° à¨¨à¨¾à¨² à¨œà©‹à©œ à¨¸à¨•à¨¦à¨¾ à¨¹à¨¾à¨‚à¥¤ â€˜à¨®à¨¾à¨¹à¨¿à¨° à¨¸à¨²à¨¾à¨¹â€™ à¨­à¨¾à¨— à¨–à©‹à¨²à©à¨¹à©‹ à¨…à¨¤à©‡ à¨…à¨§à¨¿à¨•à¨¾à¨°à¨¤ à¨–à©‡à¨¤à©€ à¨¸à©°à¨ªà¨°à¨• à¨¨à©‚à©° à¨•à¨¾à¨² à¨œà¨¾à¨‚ à¨ˆà¨®à©‡à¨² à¨•à¨°à©‹à¥¤",
            "mr": "à¤®à¥€ à¤¤à¥à¤®à¥à¤¹à¤¾à¤²à¤¾ à¤•à¥ƒà¤·à¥€ à¤¤à¤œà¥à¤œà¥à¤žà¤¾à¤¶à¥€ à¤œà¥‹à¤¡à¥‚ à¤¶à¤•à¤¤à¥‹. â€˜à¤¤à¤œà¥à¤œà¥à¤ž à¤¸à¤²à¥à¤²à¤¾â€™ à¤µà¤¿à¤­à¤¾à¤— à¤‰à¤˜à¤¡à¥‚à¤¨ à¤…à¤§à¤¿à¤•à¥ƒà¤¤ à¤•à¥ƒà¤·à¥€ à¤¸à¤‚à¤ªà¤°à¥à¤•à¤¾à¤¶à¥€ à¤•à¥‰à¤² à¤•à¤¿à¤‚à¤µà¤¾ à¤ˆà¤®à¥‡à¤² à¤•à¤°à¤¾.",
            "bn": "à¦†à¦®à¦¿ à¦†à¦ªà¦¨à¦¾à¦•à§‡ à¦•à§ƒà¦·à¦¿ à¦¬à¦¿à¦¶à§‡à¦·à¦œà§à¦žà§‡à¦° à¦¸à¦™à§à¦—à§‡ à¦¯à§‹à¦—à¦¾à¦¯à§‹à¦— à¦•à¦°à¦¤à§‡ à¦¸à¦¾à¦¹à¦¾à¦¯à§à¦¯ à¦•à¦°à¦¤à§‡ à¦ªà¦¾à¦°à¦¿à¥¤ â€˜à¦¬à¦¿à¦¶à§‡à¦·à¦œà§à¦ž à¦ªà¦°à¦¾à¦®à¦°à§à¦¶â€™ à¦¬à¦¿à¦­à¦¾à¦— à¦–à§à¦²à§‡ à¦¸à¦°à¦•à¦¾à¦°à¦¿ à¦•à§ƒà¦·à¦¿ à¦¯à§‹à¦—à¦¾à¦¯à§‹à¦—à§‡ à¦•à¦² à¦¬à¦¾ à¦‡à¦®à§‡à¦² à¦•à¦°à§à¦¨à¥¤",
            "gu": "àª¹à«àª‚ àª¤àª®àª¨à«‡ àª•à«ƒàª·àª¿ àª¨àª¿àª·à«àª£àª¾àª¤ àª¸àª¾àª¥à«‡ àªœà«‹àª¡àªµàª¾àª®àª¾àª‚ àª®àª¦àª¦ àª•àª°à«€ àª¶àª•à«àª‚ àª›à«àª‚. â€˜àª¨àª¿àª·à«àª£àª¾àª¤ àª¸àª²àª¾àª¹â€™ àªµàª¿àª­àª¾àª— àª–à«‹àª²à«€àª¨à«‡ àª…àª§àª¿àª•à«ƒàª¤ àª•à«ƒàª·àª¿ àª¸àª‚àªªàª°à«àª•àª¨à«‡ àª•à«‰àª² àª…àª¥àªµàª¾ àª‡àª®à«‡àª² àª•àª°à«‹.",
            "ta": "à®¨à®¾à®©à¯ à®‰à®™à¯à®•à®³à¯ˆ à®µà¯‡à®³à®¾à®£à¯ à®¨à®¿à®ªà¯à®£à®°à¯à®Ÿà®©à¯ à®¤à¯Šà®Ÿà®°à¯à®ªà¯ à®•à¯Šà®³à¯à®³ à®‰à®¤à®µ à®®à¯à®Ÿà®¿à®¯à¯à®®à¯. â€˜à®¨à®¿à®ªà¯à®£à®°à¯ à®†à®²à¯‹à®šà®©à¯ˆâ€™ à®ªà®•à¯à®¤à®¿à®¯à¯ˆà®¤à¯ à®¤à®¿à®±à®¨à¯à®¤à¯ à®…à®¤à®¿à®•à®¾à®°à®ªà¯à®ªà¯‚à®°à¯à®µ à®µà¯‡à®³à®¾à®£à¯ à®¤à¯Šà®Ÿà®°à¯à®ªà¯ˆ à®…à®´à¯ˆà®•à¯à®•à®µà¯à®®à¯ à®…à®²à¯à®²à®¤à¯ à®®à®¿à®©à¯à®©à®žà¯à®šà®²à¯ à®šà¯†à®¯à¯à®¯à®µà¯à®®à¯.",
            "te": "à°¨à±‡à°¨à± à°®à°¿à°®à±à°®à°²à±à°¨à°¿ à°µà±à°¯à°µà°¸à°¾à°¯ à°¨à°¿à°ªà±à°£à±à°¡à°¿à°¤à±‹ à°¸à°‚à°ªà±à°°à°¦à°¿à°‚à°šà°¡à°‚à°²à±‹ à°¸à°¹à°¾à°¯à°ªà°¡à°—à°²à°¨à±. â€˜à°¨à°¿à°ªà±à°£à±à°² à°¸à°²à°¹à°¾â€™ à°µà°¿à°­à°¾à°—à°¾à°¨à±à°¨à°¿ à°¤à±†à°°à°¿à°šà°¿ à°…à°§à°¿à°•à°¾à°°à°¿à°• à°µà±à°¯à°µà°¸à°¾à°¯ à°¸à°‚à°ªà±à°°à°¦à°¿à°‚à°ªà±à°¨à± à°•à°¾à°²à± à°²à±‡à°¦à°¾ à°‡à°®à±†à°¯à°¿à°²à± à°šà±‡à°¯à°‚à°¡à°¿.",
            "kn": "à²¨à²¿à²®à³à²®à²¨à³à²¨à³ à²•à³ƒà²·à²¿ à²¤à²œà³à²žà²°à³Šà²‚à²¦à²¿à²—à³† à²¸à²‚à²ªà²°à³à²•à²¿à²¸à²²à³ à²¨à²¾à²¨à³ à²¸à²¹à²¾à²¯ à²®à²¾à²¡à²¬à²¹à³à²¦à³. â€˜à²¤à²œà³à²žà²° à²¸à²²à²¹à³†â€™ à²µà²¿à²­à²¾à²—à²µà²¨à³à²¨à³ à²¤à³†à²°à³†à²¯à²¿à²°à²¿ à²®à²¤à³à²¤à³ à²…à²§à²¿à²•à³ƒà²¤ à²•à³ƒà²·à²¿ à²¸à²‚à²ªà²°à³à²•à²•à³à²•à³† à²•à²°à³† à²…à²¥à²µà²¾ à²‡à²®à³‡à²²à³ à²®à²¾à²¡à²¿.",
            "ml": "à´•àµƒà´·à´¿ à´µà´¿à´¦à´—àµà´§à´¨àµà´®à´¾à´¯à´¿ à´¬à´¨àµà´§à´ªàµà´ªàµ†à´Ÿà´¾àµ» à´žà´¾àµ» à´¸à´¹à´¾à´¯à´¿à´•àµà´•à´¾à´‚. â€˜à´µà´¿à´¦à´—àµà´§ à´‰à´ªà´¦àµ‡à´¶à´‚â€™ à´µà´¿à´­à´¾à´—à´‚ à´¤àµà´±à´¨àµà´¨àµ à´”à´¦àµà´¯àµ‹à´—à´¿à´• à´•à´¾àµ¼à´·à´¿à´• à´¬à´¨àµà´§à´ªàµà´ªàµ†à´Ÿàµ½ à´¨à´®àµà´ªà´±à´¿à´²àµ‡à´•àµà´•àµ à´µà´¿à´³à´¿à´•àµà´•àµà´•à´¯àµ‹ à´‡à´®àµ†à´¯à´¿àµ½ à´šàµ†à´¯àµà´¯àµà´•à´¯àµ‹ à´šàµ†à´¯àµà´¯àµà´•.",
        }
        return texts.get(lang, texts["en"])

    if any(x in q for x in ["treatment", "medicine", "spray", "fungicide", "pesticide", "à¤¦à¤µà¤¾", "à¤‡à¤²à¤¾à¤œ", "à¤¸à¥à¤ªà¥à¤°à¥‡", "à¤”à¤·à¤§", "à¤«à¤µà¤¾à¤°à¤£à¥€"]):
        return advice["treatment"]
    if any(x in q for x in ["prevent", "prevention", "protect", "à¤¬à¤šà¤¾à¤µ", "à¤°à¥‹à¤•à¤¥à¤¾à¤®", "à¤ªà¥à¤°à¤¤à¤¿à¤¬à¤‚à¤§"]):
        return advice["prevention"]
    if any(x in q for x in ["what should", "what do", "action", "à¤•à¤°à¤¨à¤¾", "à¤•à¥à¤¯à¤¾ à¤•à¤°", "à¤•à¤¾à¤¯ à¤•à¤°à¤¾à¤µà¥‡", "à¨•à©€ à¨•à¨°à¨¨à¨¾"]):
        return advice["farmer_action"]
    if any(x in q for x in ["disease", "problem", "symptom", "à¤°à¥‹à¤—", "à¤¬à¥€à¤®à¤¾à¤°à¥€", "à¤²à¤•à¥à¤·à¤£", "à¤¸à¤®à¤¸à¥à¤¯à¤¾"]):
        return advice["summary"]

    confidence_text = str(confidence) if confidence is not None else "N/A"
    templates = {
        "en": f"For your question about {crop}, the current scan context is {disease} ({confidence_text}% confidence). {advice['farmer_action']} If you tell me the visible symptoms, crop age and recent weather/irrigation, I can narrow the guidance.",
        "hi": f"à¤†à¤ªà¤•à¥‡ {crop} à¤¸à¥‡ à¤œà¥à¤¡à¤¼à¥‡ à¤¸à¤µà¤¾à¤² à¤•à¥‡ à¤²à¤¿à¤ à¤µà¤°à¥à¤¤à¤®à¤¾à¤¨ à¤¸à¥à¤•à¥ˆà¤¨ à¤®à¥‡à¤‚ {disease} ({confidence_text}% à¤µà¤¿à¤¶à¥à¤µà¤¸à¤¨à¥€à¤¯à¤¤à¤¾) à¤¦à¤¿à¤–à¤¾ à¤¹à¥ˆà¥¤ {advice['farmer_action']} à¤…à¤—à¤° à¤†à¤ª à¤¦à¤¿à¤–à¤¾à¤ˆ à¤¦à¥‡à¤¨à¥‡ à¤µà¤¾à¤²à¥‡ à¤²à¤•à¥à¤·à¤£, à¤«à¤¸à¤² à¤•à¥€ à¤‰à¤®à¥à¤° à¤”à¤° à¤¹à¤¾à¤² à¤•à¤¾ à¤®à¥Œà¤¸à¤®/à¤¸à¤¿à¤‚à¤šà¤¾à¤ˆ à¤¬à¤¤à¤¾à¤à¤, à¤¤à¥‹ à¤®à¥ˆà¤‚ à¤¸à¤²à¤¾à¤¹ à¤•à¥‹ à¤”à¤° à¤¸à¤Ÿà¥€à¤• à¤•à¤° à¤¸à¤•à¤¤à¤¾ à¤¹à¥‚à¤à¥¤",
        "pa": f"à¨¤à©à¨¹à¨¾à¨¡à©€ {crop} à¨«à¨¸à¨² à¨²à¨ˆ à¨®à©Œà¨œà©‚à¨¦à¨¾ à¨¸à¨•à©ˆà¨¨ à¨µà¨¿à©±à¨š {disease} ({confidence_text}% à¨­à¨°à©‹à¨¸à©‡à¨¯à©‹à¨—à¨¤à¨¾) à¨¦à¨¿à¨–à¨¾à¨ˆ à¨—à¨ˆ à¨¹à©ˆà¥¤ {advice['farmer_action']} à¨œà©‡ à¨¤à©à¨¸à©€à¨‚ à¨²à©±à¨›à¨£, à¨«à¨¸à¨² à¨¦à©€ à¨‰à¨®à¨° à¨…à¨¤à©‡ à¨¹à¨¾à¨²à©€à¨† à¨®à©Œà¨¸à¨®/à¨¸à¨¿à©°à¨šà¨¾à¨ˆ à¨¦à©±à¨¸à©‹ à¨¤à¨¾à¨‚ à¨®à©ˆà¨‚ à¨¹à©‹à¨° à¨¸à¨¹à©€ à¨¸à¨²à¨¾à¨¹ à¨¦à©‡ à¨¸à¨•à¨¦à¨¾ à¨¹à¨¾à¨‚à¥¤",
        "mr": f"à¤¤à¥à¤®à¤šà¥à¤¯à¤¾ {crop} à¤ªà¤¿à¤•à¤¾à¤šà¥à¤¯à¤¾ à¤¸à¤§à¥à¤¯à¤¾à¤šà¥à¤¯à¤¾ à¤¸à¥à¤•à¥…à¤¨à¤®à¤§à¥à¤¯à¥‡ {disease} ({confidence_text}% à¤µà¤¿à¤¶à¥à¤µà¤¾à¤¸à¤¾à¤°à¥à¤¹à¤¤à¤¾) à¤¦à¤¿à¤¸à¤¤ à¤†à¤¹à¥‡. {advice['farmer_action']} à¤¦à¤¿à¤¸à¤£à¤¾à¤°à¥€ à¤²à¤•à¥à¤·à¤£à¥‡, à¤ªà¤¿à¤•à¤¾à¤šà¥‡ à¤µà¤¯ à¤†à¤£à¤¿ à¤…à¤²à¥€à¤•à¤¡à¥€à¤² à¤¹à¤µà¤¾à¤®à¤¾à¤¨/à¤¸à¤¿à¤‚à¤šà¤¨ à¤¸à¤¾à¤‚à¤—à¤¿à¤¤à¤²à¥à¤¯à¤¾à¤¸ à¤®à¥€ à¤…à¤§à¤¿à¤• à¤…à¤šà¥‚à¤• à¤®à¤¾à¤°à¥à¤—à¤¦à¤°à¥à¤¶à¤¨ à¤•à¤°à¥‚ à¤¶à¤•à¤¤à¥‹.",
    }
    return templates.get(lang, templates["en"])


def _gemini_chat(message, language, crop, disease, confidence, history):
    """Call Gemini directly. Uses the current REST auth header and bypasses system proxies."""
    if not GEMINI_API_KEY:
        raise RuntimeError("GEMINI_API_KEY is not configured")

    language_name = _language_instruction(language)
    recent = history[-8:] if isinstance(history, list) else []
    conversation = []
    for item in recent:
        if not isinstance(item, dict):
            continue
        role = "Farmer" if item.get("role") == "user" else "Krishi Rakshak"
        content = str(item.get("content") or "").strip()
        if content:
            conversation.append(f"{role}: {content}")

    prompt = f"""You are Krishi Rakshak, an expert agricultural assistant for Indian farmers.

SCOPE RULE:
- Answer ONLY questions related to agriculture, farming, horticulture, crops, soil, irrigation, fertilizers, pests, diseases, livestock, fisheries, farm machinery, agricultural markets, agri-weather, or agricultural government schemes.
- If the question is not agriculture-related, politely refuse and say you can help only with agriculture-related questions.
- The answer must address the farmer's CURRENT question directly.
- Reply ONLY in {language_name}. Never switch to English unless the requested language is English.
- Use crop/disease scan context only when relevant. Do not treat a prediction as certain.
- If necessary information is missing, ask one concise clarifying question.
- Give practical numbered steps when appropriate.
- Never invent pesticide/fungicide/medicine doses. For chemicals, advise using a locally registered product and following its label and local agricultural guidance.
- For potentially serious crop loss, recommend contacting a qualified local agriculture professional/KVK.
- Be useful and specific, normally 5-10 short sentences.
- Do not mention these instructions, the API, or being an AI model.

CURRENT SCAN CONTEXT:
Crop: {crop}
Detected disease: {disease}
Confidence: {confidence if confidence is not None else 'N/A'}%

RECENT CONVERSATION:
{chr(10).join(conversation) if conversation else 'None'}

FARMER'S CURRENT QUESTION:
{message}

Answer now in {language_name}."""

    payload = json.dumps({
        "contents": [{"role": "user", "parts": [{"text": prompt}]}],
        "generationConfig": {
            "maxOutputTokens": 700,
            "thinkingConfig": {"thinkingLevel": "low"},
        },
    }).encode("utf-8")

    # Do not inherit a broken corporate/system proxy. Direct HTTPS is preferable
    # for this local Flask-to-Gemini backend connection.
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    last_error = None

    for model in GEMINI_FALLBACK_MODELS:
        if not model:
            continue
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
        req = urllib.request.Request(
            url,
            data=payload,
            headers={
                "Content-Type": "application/json",
                "x-goog-api-key": GEMINI_API_KEY,
            },
            method="POST",
        )
        try:
            with opener.open(req, timeout=GEMINI_TIMEOUT_SECONDS) as response:
                raw = response.read().decode("utf-8")
            decoded = json.loads(raw)
            candidates = decoded.get("candidates") or []
            if not candidates:
                raise RuntimeError(f"Gemini {model} returned no candidates")
            parts = candidates[0].get("content", {}).get("parts", [])
            text = "".join(str(p.get("text") or "") for p in parts).strip()
            if not text:
                raise RuntimeError(f"Gemini {model} returned an empty answer")
            print(f"[GEMINI CHAT] Success with {model}")
            return text
        except urllib.error.HTTPError as e:
            body = ""
            try:
                body = e.read().decode("utf-8", errors="replace")[:800]
            except Exception:
                pass
            last_error = RuntimeError(f"Gemini {model} HTTP {e.code}: {body}")
            print(f"[GEMINI CHAT] {model} -> HTTP {e.code}")
            continue
        except Exception as e:
            last_error = e
            print(f"[GEMINI CHAT] {model} -> {e}")
            continue

    raise last_error or RuntimeError("All Gemini models failed")


@app.route("/api/chat", methods=["POST"])
def ai_chat():
    try:
        data = request.get_json(silent=True) or {}
        message = str(data.get("message") or "").strip()
        language = str(data.get("language") or "en").lower()
        if language not in {"en", "hi", "pa", "mr", "bn", "gu", "ta", "te", "kn", "ml"}:
            language = "en"

        context = data.get("context") or {}
        crop = str(context.get("crop") or "crop")
        disease = str(context.get("disease") or context.get("class_name") or "unknown disease")
        confidence = context.get("confidence")
        history = data.get("history") or []

        if not message:
            return jsonify({"success": False, "error": "message is required"}), 400

        try:
            reply = _gemini_chat(message, language, crop, disease, confidence, history)
            source = "gemini_ai"
        except Exception as ai_error:
            print(f"[GEMINI CHAT FALLBACK] {ai_error}")
            reply = _local_chat_fallback(message, language, crop, disease, confidence)
            source = "local_ai_fallback"

        return jsonify({
            "success": True,
            "source": source,
            "language": language,
            "reply": reply,
            "context": {"crop": crop, "disease": disease, "confidence": confidence},
            "consultant_available": True,
            "disclaimer": "AI guidance is informational. Confirm diagnosis and treatment with a qualified local agriculture professional or official agricultural guidance.",
        }), 200

    except Exception as e:
        print(f"[AI CHAT ERROR] {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ============================================================
# OFFICIAL EXPERT / CONSULTANT REFERRALS
# ============================================================

OFFICIAL_CONSULTANTS = [
    {"name": "Dr. Mangi Lal Jat", "role": "Secretary (DARE) & Director General, ICAR", "specialization": "Agriculture research and national agricultural extension", "phone": "+91-11-23388991-9", "email": "dg.icar@nic.in"},
    {"name": "Dr. DK Yadav", "role": "Deputy Director General, Crop Science, ICAR", "specialization": "Crop science and crop production", "phone": "+91-11-23382545", "email": "ddgcs@icar.nic.in"},
    {"name": "Dr. Sanjay Kumar Singh", "role": "Deputy Director General, Horticultural Science, ICAR", "specialization": "Horticulture, fruits, vegetables and plantation crops", "phone": "+91-11-25842068", "email": "ddghort@icar.org.in"},
    {"name": "Dr. AK Nayak", "role": "Deputy Director General, Natural Resource Management, ICAR", "specialization": "Soil, water and natural resource management", "phone": "+91-11-25848364", "email": "ddgnrm@gmail.com"},
    {"name": "Dr. Rajbir Singh", "role": "Deputy Director General, Agricultural Extension, ICAR", "specialization": "Farmer advisory and agricultural extension", "phone": "+91-11-25843277", "email": "ddg-extn@icar.gov.in"},
    {"name": "Dr. Yashpal Singh Malik", "role": "Deputy Director General, Agricultural Education, ICAR", "specialization": "Agricultural education and expert referral", "phone": "+91-11-25841760", "email": "ddgedu@icar.gov.in"},
    {"name": "Dr. Joykrushna Jena", "role": "Deputy Director General, Fisheries Science, ICAR", "specialization": "Fisheries and aquaculture", "phone": "+91-11-25846738", "email": "ddgfs@icar.gov.in"},
    {"name": "Dr. Raghavendra Bhatta", "role": "Deputy Director General, Animal Science, ICAR", "specialization": "Livestock and animal science", "phone": "+91-11-23381119", "email": "ddgas@icar.nic.in"},
    {"name": "Dr. A Velmurugan", "role": "Assistant Director General, Soil & Water Management, ICAR", "specialization": "Soil and water management", "phone": "+91-9933270521", "email": "a.velmurugan@icar.org.in"},
    {"name": "Dr. Rakesh Kumar", "role": "Assistant Director General, AAF&CC, ICAR", "specialization": "Agriculture and allied field coordination", "phone": "+91-8901365282", "email": "rakesh.kumar1@icar.org.in"},
]


@app.route("/api/consultants", methods=["GET"])
def consultants():
    return jsonify({
        "success": True,
        "count": len(OFFICIAL_CONSULTANTS),
        "source": "ICAR official contact information",
        "consultants": OFFICIAL_CONSULTANTS,
        "note": "These are official ICAR referral contacts. Availability for individual farmer consultation may vary; use the contact to request the appropriate KVK or subject-matter expert.",
    }), 200



# ============================================================
# UNIFIED CROP HEALTH ASSESSMENT
# ============================================================

@app.route("/api/unified-assessment", methods=["POST"])
def unified_assessment():
    """Combine disease context, YOLO pest detection, and weather into one explainable result."""
    try:
        image = request.files.get("image")
        if image is None:
            return jsonify({"success": False, "error": "image file is required"}), 400

        disease = str(request.form.get("disease") or "unknown disease")
        try:
            disease_confidence = float(request.form.get("disease_confidence", "0"))
        except ValueError:
            disease_confidence = 0.0

        try:
            weather = json.loads(request.form.get("weather") or "{}")
            if not isinstance(weather, dict):
                weather = {}
        except Exception:
            weather = {}

        severity = calculate_severity(disease, disease_confidence * 100 if disease_confidence <= 1 else disease_confidence)
        disease_conf_pct = disease_confidence * 100 if disease_confidence <= 1 else disease_confidence
        disease_risk = calculate_risk_assessment(disease, disease_conf_pct, severity, weather)

        pest_result = detect_pests(image, 0.25)
        pest_risk = pest_result.get("risk_assessment") or assess_pest_risk(pest_result.get("detections", []))

        # Transparent prototype combination:
        # disease = 50%, pest = 30%, weather = 20%.
        # If weather is unavailable, renormalize the available disease/pest signals.
        disease_score = max(0.0, min(100.0, float(disease_risk.get("score", 0))))
        pest_score = max(0.0, min(100.0, float(pest_risk.get("score", 0))))

        weather_score = 0.0
        weather_factors = []
        humidity = weather.get("humidity")
        rainfall = weather.get("rainfall")
        try:
            if humidity is not None:
                humidity = float(humidity)
                if humidity >= 80:
                    weather_score += 60.0
                    weather_factors.append("high humidity")
                elif humidity >= 60:
                    weather_score += 30.0
                    weather_factors.append("moderate humidity")
            if rainfall is not None:
                rainfall = float(rainfall)
                if rainfall > 10:
                    weather_score += 40.0
                    weather_factors.append("recent rainfall")
                elif rainfall > 2:
                    weather_score += 20.0
                    weather_factors.append("some rainfall")
            weather_score = min(100.0, weather_score)
        except (TypeError, ValueError):
            weather_score = 0.0
            weather_factors = []

        weighted_parts = [(disease_score, 0.50), (pest_score, 0.30)]
        if humidity is not None or rainfall is not None:
            weighted_parts.append((weather_score, 0.20))
        weight_total = sum(weight for _, weight in weighted_parts)
        overall_score = round(
            sum(score * weight for score, weight in weighted_parts) / weight_total,
            2
        )
        overall_level = "high" if overall_score >= 70 else "medium" if overall_score >= 40 else "low"

        # Signal-strength indicator is deliberately separate from risk score.
        # Model confidence is evidence strength, not a validated probability.
        pest_confidences = [
            float(d.get("confidence", 0)) for d in pest_result.get("detections", [])
        ]
        pest_signal = max(pest_confidences) if pest_confidences else 0.0
        signal_values = [disease_conf_pct]
        if pest_confidences:
            signal_values.append(pest_signal)
        signal_strength = round(sum(signal_values) / len(signal_values), 2)
        signal_band = (
            "strong" if signal_strength >= 80
            else "moderate" if signal_strength >= 60
            else "weak"
        )

        actions = []
        if disease_risk.get("score", 0) > 0:
            actions.append("Inspect the affected crop area and nearby plants.")
        if pest_result.get("detections"):
            actions.extend(pest_risk.get("recommended_actions", [])[:2])
        if weather.get("humidity") is not None and float(weather.get("humidity") or 0) >= 80:
            actions.append("Monitor closely for disease-favorable high humidity.")
        if weather.get("rainfall") is not None and float(weather.get("rainfall") or 0) > 10:
            actions.append("Check drainage after rainfall and avoid unnecessary spraying during wet conditions.")
        if not actions:
            actions.append("Continue routine crop monitoring and rescan if symptoms change.")
        actions = list(dict.fromkeys(actions))

        return jsonify({
            "success": True,
            "disease": {
                "name": disease,
                "confidence": round(disease_conf_pct, 2),
                "severity": severity,
                "risk_assessment": disease_risk
            },
            "pest": {
                "detections": pest_result.get("detections", []),
                "count": pest_result.get("count", 0),
                "summary": pest_result.get("pest_summary", {}),
                "risk_assessment": pest_risk
            },
            "weather": weather,
            "overall_assessment": {
                "score": overall_score,
                "level": overall_level,
                "label": overall_level.title() + " overall crop health risk",
                "recommended_actions": actions,
                "signal_strength": {
                    "score": signal_strength,
                    "band": signal_band,
                    "note": "Model confidence is an evidence-strength signal, not a calibrated probability."
                },
                "components": {
                    "disease": {"score": round(disease_score, 2), "weight": 0.50},
                    "pest": {"score": round(pest_score, 2), "weight": 0.30},
                    "weather": {"score": round(weather_score, 2), "weight": 0.20, "factors": weather_factors}
                },
                "method": "unified_weighted_rule_based_v2",
                "validated": False
            },
            "disclaimer": "Unified risk is an explainable rule-based prototype using model outputs and supplied weather signals; it is not a validated agronomic forecast."
        }), 200
    except Exception as e:
        print(f"[UNIFIED ASSESSMENT ERROR] {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ============================================================
# PEST DETECTION (YOLO)
# ============================================================
# Optional custom Ultralytics model. Put trained weights at:
# public/models/pest/best.pt
# Or set PEST_MODEL_PATH to another .pt path.
try:
    from ultralytics import YOLO
    YOLO_AVAILABLE = True
except Exception:
    YOLO = None
    YOLO_AVAILABLE = False

PEST_MODEL_PATH = os.environ.get(
    "PEST_MODEL_PATH",
    os.path.join(BASE_DIR, "public", "models", "pest", "best.pt")
)
_pest_model = None


def load_pest_model():
    global _pest_model

    if not YOLO_AVAILABLE:
        return False

    if not os.path.exists(PEST_MODEL_PATH):
        return False

    _pest_model = YOLO(PEST_MODEL_PATH)
    print(f"[PEST] YOLO model loaded: {PEST_MODEL_PATH}")
    return True


def assess_pest_risk(detections):
    if not detections:
        return {"score":0,"level":"low","label":"No pest detected","recommended_actions":["Continue routine field monitoring.","Capture a clear close-up image and rescan if symptoms continue."],"validated":False,"method":"pest_rule_based_v1"}
    avg=sum(float(d.get("confidence",0)) for d in detections)/len(detections)
    count=len(detections)
    score=round(min(100.0,avg*0.75+min(count,10)*4),2)
    level="high" if score>=70 else "medium" if score>=40 else "low"
    actions=["Inspect nearby plants for the same pest.","Repeat the scan across several representative plants.","Confirm the pest identification before treatment."]
    if level=="high": actions.append("Follow local agricultural guidance and registered product labels before applying treatment.")
    return {"score":score,"level":level,"label":level.title()+" pest risk","recommended_actions":actions,"validated":False,"method":"pest_rule_based_v1"}

def detect_pests(image_file, confidence_threshold=0.25):
    global _pest_model
    if not YOLO_AVAILABLE:
        raise RuntimeError("Ultralytics is not installed")
    if not os.path.exists(PEST_MODEL_PATH):
        raise FileNotFoundError(f"Pest model not found: {PEST_MODEL_PATH}")
    if _pest_model is None:
        _pest_model = YOLO(PEST_MODEL_PATH)
    image_bytes = image_file.read()
    if not image_bytes:
        raise ValueError("Uploaded image is empty")
    image_array = np.frombuffer(image_bytes, dtype=np.uint8)
    image = cv2.imdecode(image_array, cv2.IMREAD_COLOR)
    if image is None:
        raise ValueError("Could not decode uploaded image")
    results = _pest_model.predict(source=image, conf=confidence_threshold, verbose=False)
    detections=[]
    for result in results:
        if result.boxes is None:
            continue
        for box in result.boxes:
            class_id=int(box.cls[0].item())
            confidence=float(box.conf[0].item())
            xyxy=box.xyxy[0].tolist()
            detections.append({'class_id':class_id,'class_name':result.names.get(class_id,str(class_id)),'confidence':round(confidence*100,2),'bbox':[round(float(v),2) for v in xyxy]})
    detections.sort(key=lambda x:x['confidence'], reverse=True)
    return {'success':True,'detections':detections,'count':len(detections),'pest_summary':{n:sum(1 for d in detections if d['class_name']==n) for n in set(d['class_name'] for d in detections)},'risk_assessment':assess_pest_risk(detections),'model':PEST_MODEL_PATH,'model_type':'YOLO'}

@app.route("/api/pest-detect", methods=["POST"])
def pest_detect():
    try:
        image = request.files.get("image")
        if image is None:
            return jsonify({
                "success": False,
                "error": "image file is required"
            }), 400

        threshold = request.form.get("confidence", "0.25")
        try:
            threshold = max(0.05, min(0.95, float(threshold)))
        except ValueError:
            threshold = 0.25

        result = detect_pests(image, threshold)

        return jsonify({
            "success": True,
            **result
        }), 200

    except FileNotFoundError as e:
        return jsonify({
            "success": False,
            "configured": False,
            "error": str(e),
            "next_step": "Add a trained YOLO pest model as public/models/pest/best.pt"
        }), 503

    except RuntimeError as e:
        return jsonify({
            "success": False,
            "configured": False,
            "error": str(e)
        }), 503

    except Exception as e:
        print(f"[PEST DETECTION ERROR] {e}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500


@app.route("/api/pest-detect/status", methods=["GET"])
def pest_detect_status():
    configured = bool(
        YOLO_AVAILABLE and os.path.exists(PEST_MODEL_PATH)
    )
    return jsonify({
        "success": True,
        "configured": configured,
        "yolo_installed": YOLO_AVAILABLE,
        "model_path": PEST_MODEL_PATH,
        "model_exists": os.path.exists(PEST_MODEL_PATH)
    }), 200


# ============================================================
# STARTUP
# ============================================================
def initialize_application():
    print("=" * 65)
    print("KRISHI RAKSHAK - APPLICATION INITIALIZATION")
    print("=" * 65)

    print(f"[CONFIG] Base: {BASE_DIR}")
    print(f"[CONFIG] Model: {MODEL_PATH}")
    print(f"[CONFIG] Classes: {CLASSES_PATH}")
    print(f"[CONFIG] Database: {DB_PATH}")

    print()
    print("[1/3] Loading classes...")

    load_classes()

    print(f"[OK] Classes loaded: {len(classes)}")

    print()
    print("[2/3] Loading TFLite model...")

    load_model()

    print("[OK] TFLite model loaded")

    print()
    print("[3/3] Initializing database...")

    init_database()

    print("[OK] Database initialized")

    print()
    print("=" * 65)
    print("KRISHI RAKSHAK API INITIALIZATION COMPLETE")
    print("=" * 65)


# IMPORTANT:
# Gunicorn imports this module as `api_server:app`.
# Therefore initialization must happen during module import,
# not only inside `if __name__ == "__main__"`.

try:
    initialize_application()

except Exception as e:
    print()
    print("=" * 65)
    print("KRISHI RAKSHAK INITIALIZATION FAILED")
    print("=" * 65)
    print(f"ERROR: {e}")
    print("=" * 65)

    # Do not allow Gunicorn to start a broken application.
    raise


if __name__ == "__main__":

    print()
    print("=" * 65)
    print("KRISHI RAKSHAK - GOVERNMENT CONNECTED API")
    print("=" * 65)

    print(f"[CONFIG] Model: {MODEL_PATH}")
    print(f"[CONFIG] Classes: {CLASSES_PATH}")
    print(f"[CONFIG] Database: {DB_PATH}")

    print()
    print("SERVER READY")

    print(f"Local:   http://127.0.0.1:{PORT}")
    print(f"Network: http://10.85.135.146:{PORT}")

    print()
    print("Endpoints:")
    print("  GET  /api/health")
    print("  GET  /api/classes")
    print("  POST /api/predict")
    print("  POST /api/pest-detect")
    print("  GET  /api/pest-detect/status")
    print("  POST /api/unified-assessment")
    print("  POST /api/risk-assessment")
    print("  GET  /api/hotspots")
    print("  GET  /api/hotspots/summary")
    print("  POST /api/government/alert")
    print("  GET  /api/government/alerts")
    print("  GET  /api/government/alerts/<alert_id>")
    print("  POST /api/government/alerts/<alert_id>/status")
    print("  GET  /api/government/stats")
    print("  POST /api/advice")
    print("  POST /api/chat")
    print("  GET  /api/consultants")

    print("=" * 65)

    app.run(
        host=HOST,
        port=PORT,
        debug=False
    )
