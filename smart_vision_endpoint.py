import base64
import json
import os
import re
import urllib.error
import urllib.request
from io import BytesIO

from flask import request, jsonify
from PIL import Image


ALLOWED_MIME = {
    "image/jpeg",
    "image/png",
    "image/webp",
}


def _prepare_image(image_bytes, mime_type):
    mime_type = (mime_type or "").lower().strip()

    try:
        image = Image.open(BytesIO(image_bytes))
        image.verify()
    except Exception as exc:
        raise ValueError(f"Invalid or unreadable image: {exc}")

    if len(image_bytes) <= 8 * 1024 * 1024 and mime_type in ALLOWED_MIME:
        return image_bytes, mime_type

    image = Image.open(BytesIO(image_bytes)).convert("RGB")
    image.thumbnail((1600, 1600))

    output = BytesIO()
    image.save(output, format="JPEG", quality=88, optimize=True)

    return output.getvalue(), "image/jpeg"


def _extract_json(text):
    text = (text or "").strip()

    text = re.sub(
        r"^```(?:json)?\s*|\s*```$",
        "",
        text,
        flags=re.IGNORECASE | re.DOTALL,
    ).strip()

    try:
        return json.loads(text)
    except Exception:
        pass

    start = text.find("{")
    end = text.rfind("}")

    if start >= 0 and end > start:
        return json.loads(text[start:end + 1])

    raise ValueError("Gemini returned non-JSON vision output")


def _call_gemini_vision(
    image_bytes,
    mime_type,
    language,
    local_prediction,
    api_key,
    models,
):
    if not api_key:
        raise RuntimeError("GEMINI_API_KEY is not configured")

    language_names = {
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

    language_name = language_names.get(language, "English")

    local_signal = "Unavailable"
    if local_prediction:
        local_signal = json.dumps(
            {
                "class_name": local_prediction.get("class_name"),
                "confidence": local_prediction.get("confidence"),
                "top_predictions": local_prediction.get(
                    "top_predictions", []
                ),
            },
            ensure_ascii=False,
        )

    prompt = f"""
You are the visual crop-disease diagnostician for Krishi Rakshak.

Inspect the uploaded crop image DIRECTLY.

IMPORTANT SAFETY RULE:
The image may contain a crop, disease, pest, nutrient problem, abiotic problem,
or plant type that was NOT present in the application's 192-class training dataset.

NEVER force an unknown image into one of the known training classes.

Return ONLY valid JSON.

Use this exact schema:

{{
  "crop": "string",
  "disease_or_condition": "string",
  "diagnosis_confidence": 0,
  "diagnosis_status": "confirmed|likely|uncertain|not_crop_or_unusable",
  "severity": "none|low|medium|high|uncertain",
  "visual_evidence": [
    "string"
  ],
  "cause_or_likely_causes": [
    "string"
  ],
  "description": "string",
  "treatment": "string",
  "prevention": "string",
  "irrigation": "string",
  "fertilizer_management": "string",
  "monitoring": "string",
  "farmer_action": "string",
  "agronomic_warning": "string"
}}

LANGUAGE:
Reply in {language_name}.

DIAGNOSIS RULES:
1. Identify the crop from the image when possible.
2. Identify the visible disorder/disease/pest when visual evidence supports it.
3. You are NOT limited to the application's training classes.
4. If the image is blurry, too far away, heavily obstructed, not a plant,
   or does not contain enough evidence, return "uncertain" or
   "not_crop_or_unusable".
5. Do not invent certainty.
6. Keep diagnosis confidence realistic.
7. Distinguish fungal, bacterial, viral, pest, nutrient and abiotic causes
   when the image supports that distinction.
8. The local ML result below is ONLY a weak supporting signal. It may be wrong.
9. If your visual assessment conflicts with the local ML result, use the
   visual evidence and explain the conflict briefly.
10. For healthy plants, say they appear healthy rather than inventing a disease.

TREATMENT SAFETY:
- Never invent pesticide/fungicide names, doses, concentrations or spray rates.
- Do not recommend disease-specific chemical treatment when diagnosis_status
  is "uncertain" or "not_crop_or_unusable".
- For "likely", clearly label disease-specific treatment as provisional and
  recommend confirmation first.
- For "confirmed", give practical management steps, including non-chemical
  measures first and chemical treatment only as a conditional option using
  currently registered products and their labels/local agricultural guidance.
- Include irrigation and fertilizer management only when relevant.
- Do not tell the farmer to apply excessive fertilizer or water.

LOCAL MODEL SIGNAL:
{local_signal}

Return JSON only.
"""

    encoded = base64.b64encode(image_bytes).decode("ascii")

    payload = {
        "contents": [
            {
                "role": "user",
                "parts": [
                    {
                        "inline_data": {
                            "mime_type": mime_type,
                            "data": encoded,
                        }
                    },
                    {
                        "text": prompt,
                    },
                ],
            }
        ],
        "generationConfig": {
            "temperature": 0.1,
            "maxOutputTokens": 3072,
            "responseMimeType": "application/json",
        },
    }

    last_error = None

    for model in models:
        try:
            url = (
                "https://generativelanguage.googleapis.com/v1beta/"
                f"models/{model}:generateContent?key={api_key}"
            )

            body = json.dumps(payload, ensure_ascii=False).encode("utf-8")

            req = urllib.request.Request(
                url,
                data=body,
                headers={"Content-Type": "application/json"},
                method="POST",
            )

            with urllib.request.urlopen(req, timeout=45) as response:
                raw = response.read().decode("utf-8")

            data = json.loads(raw)

            candidates = data.get("candidates") or []
            texts = []

            for candidate in candidates:
                content = candidate.get("content") or {}
                for part in content.get("parts") or []:
                    if isinstance(part, dict) and part.get("text"):
                        texts.append(part["text"])

            if not texts:
                raise RuntimeError("Gemini returned no vision text")

            result = _extract_json("\n".join(texts))

            if not isinstance(result, dict):
                raise ValueError("Gemini vision response is not an object")

            result["_model"] = model
            return result

        except Exception as exc:
            last_error = exc

    raise last_error or RuntimeError("All Gemini vision models failed")


def register_smart_vision_endpoint(
    app,
    local_predict_fn,
    api_key,
    models,
):
    @app.route("/api/predict-smart", methods=["POST"])
    def predict_smart():
        try:
            if "image" not in request.files:
                return jsonify({
                    "success": False,
                    "error": "No image uploaded. Use field name 'image'.",
                }), 400

            image_file = request.files["image"]

            if not image_file.filename:
                return jsonify({
                    "success": False,
                    "error": "Empty image filename.",
                }), 400

            image_bytes = image_file.read()

            if not image_bytes:
                return jsonify({
                    "success": False,
                    "error": "Uploaded image is empty.",
                }), 400

            mime_type = image_file.mimetype or "image/jpeg"
            image_bytes, mime_type = _prepare_image(
                image_bytes,
                mime_type,
            )

            language = str(
                request.form.get("language") or "en"
            ).lower()

            if language not in {
                "en",
                "hi",
                "pa",
                "mr",
                "bn",
                "gu",
                "ta",
                "te",
                "kn",
                "ml",
            }:
                language = "en"

            local_prediction = None

            try:
                if local_predict_fn is not None:
                    local_prediction = local_predict_fn(
                        BytesIO(image_bytes)
                    )
            except Exception as exc:
                print(
                    f"[SMART VISION] Local model signal unavailable: {exc}"
                )

            vision = _call_gemini_vision(
                image_bytes=image_bytes,
                mime_type=mime_type,
                language=language,
                local_prediction=local_prediction,
                api_key=api_key,
                models=models,
            )

            crop = str(
                vision.get("crop") or "Unknown"
            ).strip()

            disease = str(
                vision.get("disease_or_condition")
                or "Uncertain"
            ).strip()

            try:
                confidence = float(
                    vision.get("diagnosis_confidence", 0)
                )
            except (TypeError, ValueError):
                confidence = 0.0

            confidence = max(
                0.0,
                min(100.0, confidence)
            )

            diagnosis_status = str(
                vision.get("diagnosis_status") or "uncertain"
            ).lower()

            allowed_statuses = {
                "confirmed",
                "likely",
                "uncertain",
                "not_crop_or_unusable",
            }

            if diagnosis_status not in allowed_statuses:
                diagnosis_status = "uncertain"

            severity = str(
                vision.get("severity") or "uncertain"
            ).lower()

            if severity not in {
                "none",
                "low",
                "medium",
                "high",
                "uncertain",
            }:
                severity = "uncertain"

            evidence = vision.get("visual_evidence") or []
            causes = vision.get("cause_or_likely_causes") or []

            description = str(
                vision.get("description") or ""
            ).strip()

            treatment = str(
                vision.get("treatment") or ""
            ).strip()

            prevention = str(
                vision.get("prevention") or ""
            ).strip()

            irrigation = str(
                vision.get("irrigation") or ""
            ).strip()

            fertilizer = str(
                vision.get("fertilizer_management") or ""
            ).strip()

            monitoring = str(
                vision.get("monitoring") or ""
            ).strip()

            farmer_action = str(
                vision.get("farmer_action") or ""
            ).strip()

            warning = str(
                vision.get("agronomic_warning") or ""
            ).strip()

            if diagnosis_status in {
                "uncertain",
                "not_crop_or_unusable",
            }:
                ui_status = (
                    "not_crop_or_unusable"
                    if diagnosis_status == "not_crop_or_unusable"
                    else "low_confidence"
                )

                treatment = (
                    "Do not apply disease-specific pesticide, fungicide, "
                    "or other chemical treatment from this image alone. "
                    "Take a clear close-up image of affected leaves and "
                    "confirm the problem with a qualified local agriculture "
                    "professional or KVK."
                )

                farmer_action = (
                    farmer_action
                    or
                    "Retake clear close-up photos of the affected leaf, "
                    "include both healthy and affected areas, and check "
                    "several plants before taking disease-specific action."
                )

            elif diagnosis_status == "likely":
                ui_status = "requires_confirmation"

                treatment = (
                    "Provisional guidance only. Confirm the diagnosis before "
                    "using any disease-specific chemical treatment. "
                    + treatment
                )

            else:
                ui_status = (
                    "healthy"
                    if disease.lower() in {
                        "healthy",
                        "normal",
                        "no disease",
                    }
                    else "disease_detected"
                )

            class_name = (
                crop if disease.lower() in {"healthy", "normal"}
                else f"{crop} {disease}".strip()
            )

            prediction = {
                "class_id": (
                    local_prediction.get("class_id")
                    if isinstance(local_prediction, dict)
                    else None
                ),
                "class_name": class_name,
                "confidence": round(confidence, 2),
                "status": ui_status,
                "severity": severity,
                "diagnosis_status": diagnosis_status,
                "diagnosis_actionable": (
                    diagnosis_status == "confirmed"
                ),
                "diagnosis_message": warning,
                "crop": crop,
                "disease": disease,
            }

            advice = {
                "description": description,
                "summary": description,
                "treatment": treatment,
                "prevention": prevention,
                "farmer_action": farmer_action,
                "irrigation": irrigation,
                "fertilizer_management": fertilizer,
                "monitoring": monitoring,
                "visual_evidence": evidence,
                "cause_or_likely_causes": causes,
            }

            return jsonify({
                "success": True,
                "source": "gemini_vision",
                "analysis_mode": "vision_first_with_local_ml_crosscheck",
                "prediction": prediction,
                "advice": advice,
                "top_predictions": (
                    local_prediction.get("top_predictions", [])
                    if isinstance(local_prediction, dict)
                    else []
                ),
                "local_model_signal": local_prediction,
                "government_alert": {
                    "required": False,
                    "alert_id": None,
                    "status": "not_required",
                },
                "vision_analysis": {
                    "crop": crop,
                    "disease_or_condition": disease,
                    "confidence": round(confidence, 2),
                    "diagnosis_status": diagnosis_status,
                    "severity": severity,
                    "visual_evidence": evidence,
                    "cause_or_likely_causes": causes,
                    "model": vision.get("_model"),
                },
                "disclaimer": (
                    "AI vision guidance is informational. Confirm serious "
                    "or uncertain crop problems with qualified local "
                    "agricultural guidance before disease-specific chemical use."
                ),
            }), 200

        except Exception as exc:
            print(f"[SMART VISION ERROR] {exc}")

            return jsonify({
                "success": False,
                "error": (
                    "Vision analysis could not be completed safely. "
                    "Please retry with a clear crop-leaf image."
                ),
            }), 500
