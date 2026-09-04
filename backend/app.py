from flask import Flask, request, jsonify
from flask_cors import CORS
from google import genai
from google.genai import types
from dotenv import load_dotenv
from PIL import Image

import io
import os
import json
import re
import time


# ============================================================
# ENVIRONMENT
# ============================================================

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
ENV_FILE = os.path.join(BASE_DIR, ".env")

load_dotenv(ENV_FILE)


# ============================================================
# FLASK
# ============================================================

app = Flask(__name__)
CORS(app)


# ============================================================
# GEMINI
# ============================================================

API_KEY = os.getenv("GEMINI_API_KEY")

if not API_KEY:
    raise RuntimeError(
        "GEMINI_API_KEY is missing. "
        "Put GEMINI_API_KEY=YOUR_KEY inside backend/.env"
    )

client = genai.Client(api_key=API_KEY)

MODEL_NAME = "gemini-3.6-flash"


# ============================================================
# LANGUAGES
# ============================================================

LANGUAGE_NAMES = {
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
    "or": "Odia",
    "ur": "Urdu",
}


# ============================================================
# HEALTH
# ============================================================

@app.route("/health", methods=["GET"])
def health():
    return jsonify({
        "success": True,
        "status": "ok",
        "service": "Krishi Rakshak AI"
    })


# ============================================================
# ANALYZE IMAGE
# ============================================================

@app.route("/analyze", methods=["POST"])
def analyze():

    try:

        print("=" * 60)
        print("REQUEST RECEIVED")
        print("=" * 60)

        # ----------------------------------------------------
        # IMAGE
        # ----------------------------------------------------

        image_file = request.files.get("image")

        if image_file is None:
            return jsonify({
                "success": False,
                "error": "Image is required"
            }), 400

        image_bytes = image_file.read()

        if not image_bytes:
            return jsonify({
                "success": False,
                "error": "Image is empty"
            }), 400

        mime_type = image_file.mimetype or "image/jpeg"

        try:
            test_image = Image.open(io.BytesIO(image_bytes))
            test_image.verify()

            print(
                "IMAGE VERIFIED:",
                test_image.format,
                test_image.size
            )

        except Exception as e:
            print("IMAGE VALIDATION ERROR:", repr(e))

            return jsonify({
                "success": False,
                "error": "Backend received an invalid image"
            }), 400

        print("Image received:", len(image_bytes), "bytes")
        print("MIME type:", mime_type)


        # ----------------------------------------------------
        # LANGUAGE
        # ----------------------------------------------------

        language = request.form.get(
            "language",
            "en"
        ).lower().strip()

        selected_language = LANGUAGE_NAMES.get(
            language,
            "English"
        )

        print("Language:", selected_language)


        # ----------------------------------------------------
        # PROMPT
        # ----------------------------------------------------

        prompt = f"""
You are Krishi Rakshak AI, an agricultural plant disease
assistant helping Indian farmers.

Analyze the ORIGINAL PLANT IMAGE carefully.

The farmer selected language:
{selected_language}

Your task has TWO stages:

STAGE 1 — IDENTIFY THE PLANT

First identify the crop/plant visible in the image.

Examples:
Apple, Tomato, Potato, Peach, Cherry, Grape,
Corn, Bell Pepper, Strawberry, etc.

Do NOT assume the crop from the filename.

STAGE 2 — IDENTIFY DISEASE

After identifying the crop, examine the visible symptoms.

Important rules:

1. Identify the crop from the actual image.
2. Identify the disease from the actual visual symptoms.
3. Never invent a disease.
4. Never confuse different crops.
5. If the image looks like an Apple leaf, do NOT report a
   Peach disease unless there is very strong visual evidence
   that the plant is actually Peach.
6. If crop identification is uncertain, say "Unknown crop".
7. If disease identification is uncertain, say "Unknown disease".
8. Do not claim 100% certainty.
9. Give a reasonable confidence estimate based only on the image.
10. Keep advice simple for an Indian farmer.
11. Avoid dangerous pesticide instructions.
12. If chemical treatment is mentioned, tell the farmer to
    follow the product label and local agricultural expert advice.
13. Mention professional agricultural advice for serious cases.
14. Answer completely in {selected_language}.

Return ONLY valid JSON.

Do not use Markdown.
Do not use ```json.
Do not add any text before or after the JSON.

Use exactly these fields:

{{
    "crop": "...",
    "disease": "...",
    "confidence": "...",
    "severity": "...",
    "description": "...",
    "treatment": "...",
    "prevention": "...",
    "farmer_action": "...",
    "warning": "..."
}}
"""


        # ----------------------------------------------------
        # SEND ACTUAL IMAGE TO GEMINI
        # ----------------------------------------------------

        print("Sending ACTUAL IMAGE to Gemini...")
        print("Model:", MODEL_NAME)

        image_part = types.Part.from_bytes(
            data=image_bytes,
            mime_type=mime_type
        )


        # ----------------------------------------------------
        # GEMINI REQUEST WITH RETRY
        # ----------------------------------------------------

        response = None
        last_error = None

        for attempt in range(3):

            try:

                print(
                    f"Gemini attempt {attempt + 1}/3..."
                )

                response = client.models.generate_content(
                    model=MODEL_NAME,
                    contents=[
                        image_part,
                        prompt
                    ]
                )

                break

            except Exception as e:

                last_error = e

                print(
                    "Gemini attempt failed:",
                    repr(e)
                )

                if attempt < 2:
                    print(
                        "Retrying in 3 seconds..."
                    )
                    time.sleep(3)


        if response is None:

            raise Exception(
                f"Gemini request failed after 3 attempts: "
                f"{last_error}"
            )


        # ----------------------------------------------------
        # GEMINI RAW RESPONSE
        # ----------------------------------------------------

        text = (response.text or "").strip()

        print("=" * 60)
        print("GEMINI RAW RESPONSE")
        print("=" * 60)
        print(text)
        print("=" * 60)


        if not text:

            raise Exception(
                "Gemini returned an empty response"
            )


        # ----------------------------------------------------
        # REMOVE MARKDOWN
        # ----------------------------------------------------

        text = re.sub(
            r"```json",
            "",
            text,
            flags=re.IGNORECASE
        )

        text = text.replace(
            "```",
            ""
        ).strip()


        # ----------------------------------------------------
        # PARSE JSON
        # ----------------------------------------------------

        try:

            ai_data = json.loads(text)

        except json.JSONDecodeError:

            print(
                "Gemini response was not valid JSON."
            )

            start = text.find("{")
            end = text.rfind("}")

            if start != -1 and end != -1 and end > start:

                json_text = text[start:end + 1]

                try:

                    ai_data = json.loads(
                        json_text
                    )

                except json.JSONDecodeError:

                    ai_data = {
                        "crop": "Unknown crop",
                        "disease": "Unknown disease",
                        "confidence": "Unknown",
                        "severity": "Unknown",
                        "description": text,
                        "treatment": "",
                        "prevention": "",
                        "farmer_action": "",
                        "warning": "AI response could not be parsed."
                    }

            else:

                ai_data = {
                    "crop": "Unknown crop",
                    "disease": "Unknown disease",
                    "confidence": "Unknown",
                    "severity": "Unknown",
                    "description": text,
                    "treatment": "",
                    "prevention": "",
                    "farmer_action": "",
                    "warning": "AI response could not be parsed."
                }


        # ----------------------------------------------------
        # NORMALIZE RESPONSE
        # ----------------------------------------------------

        result = {

            "success": True,

            "language": language,

            "crop": str(
                ai_data.get(
                    "crop",
                    "Unknown crop"
                )
            ),

            "disease": str(
                ai_data.get(
                    "disease",
                    "Unknown disease"
                )
            ),

            "confidence": str(
                ai_data.get(
                    "confidence",
                    "Unknown"
                )
            ),

            "severity": str(
                ai_data.get(
                    "severity",
                    "Unknown"
                )
            ),

            "description": str(
                ai_data.get(
                    "description",
                    ""
                )
            ),

            "treatment": str(
                ai_data.get(
                    "treatment",
                    ""
                )
            ),

            "prevention": str(
                ai_data.get(
                    "prevention",
                    ""
                )
            ),

            "farmer_action": str(
                ai_data.get(
                    "farmer_action",
                    ""
                )
            ),

            "warning": str(
                ai_data.get(
                    "warning",
                    ""
                )
            ),

            "ai_response": ai_data
        }


        # ----------------------------------------------------
        # PRINT FINAL RESULT
        # ----------------------------------------------------

        print("=" * 60)
        print("AI RESPONSE SUCCESS")
        print("=" * 60)

        print(
            json.dumps(
                result,
                ensure_ascii=False,
                indent=2
            )
        )

        print("=" * 60)


        return jsonify(result), 200


    # ========================================================
    # ERROR HANDLING
    # ========================================================

    except Exception as e:

        print("=" * 60)
        print("ANALYZE ERROR")
        print("=" * 60)
        print(repr(e))
        print("=" * 60)

        return jsonify({
            "success": False,
            "error": str(e)
        }), 500


# ============================================================
# OLD ENDPOINT SUPPORT
# ============================================================

@app.route("/disease-advice", methods=["POST"])
def disease_advice():

    return analyze()


# ============================================================
# START SERVER
# ============================================================

if __name__ == "__main__":

    print("=" * 60)
    print("KRISHI RAKSHAK AI BACKEND")
    print("=" * 60)

    print(
        "Health : http://127.0.0.1:5000/health"
    )

    print(
        "Analyze: http://127.0.0.1:5000/analyze"
    )

    print("=" * 60)

    app.run(
        host="0.0.0.0",
        port=5000,
        debug=True
    )