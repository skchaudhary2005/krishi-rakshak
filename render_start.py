from pathlib import Path
import os

path = Path("api_server.py")
text = path.read_text(encoding="utf-8")

bad = """# Gunicorn imports api_server:app. Keep startup lightweight.\\n# Load classes/database at startup; load the TFLite model on first prediction.\\ntry:\\n    load_classes()\\n    init_database()\\nexcept Exception as e:\\n    print(f"KRISHI RAKSHAK startup failed: {e}")\\n    raise\\n\n    # Do not allow Gunicorn to start a broken application.\\n    raise
"""

good = """# Gunicorn imports api_server:app. Keep startup lightweight.
# Load classes/database at startup; load the TFLite model on first prediction.
try:
    load_classes()
    init_database()
except Exception as e:
    print(f"KRISHI RAKSHAK startup failed: {e}")
    raise
"""

if bad in text:
    text = text.replace(bad, good)
    path.write_text(text, encoding="utf-8")

os.execvp(
    "gunicorn",
    [
        "gunicorn",
        "--bind", f"0.0.0.0:{os.environ.get('PORT', '10000')}",
        "--workers", "1",
        "--threads", "4",
        "--timeout", "120",
        "api_server:app",
    ],
)
