"""
Convert trained Keras model to TensorFlow.js format
Run after training completes
"""

import subprocess
import sys
from pathlib import Path

MODEL_PATH = 'models/crop_disease_real/best_model.h5'
OUTPUT_PATH = 'public/models/crop_disease_real'

print("=" * 70)
print("🔄 CONVERTING MODEL TO TENSORFLOW.JS")
print("=" * 70)

# Check if model exists
if not Path(MODEL_PATH).exists():
    print(f"\n❌ Model not found: {MODEL_PATH}")
    print("   Train the model first with: python train_model.py")
    sys.exit(1)

print(f"\nInput:  {MODEL_PATH}")
print(f"Output: {OUTPUT_PATH}")

# Create output directory
Path(OUTPUT_PATH).mkdir(parents=True, exist_ok=True)

# Convert
print("\n🔄 Converting...")
try:
    result = subprocess.run([
        'tensorflowjs_converter',
        '--input_format=keras',
        MODEL_PATH,
        OUTPUT_PATH
    ], capture_output=True, text=True, check=True)
    
    print("✅ Conversion successful!")
    print(f"\n📁 Files created in {OUTPUT_PATH}/:")
    print("   - model.json")
    print("   - group1-shard*.bin")
    print("   - classes.json (already exists)")
    
    print("\n🎯 Next steps:")
    print("   1. Model is ready at: /models/crop_disease_real/")
    print("   2. React app will load it automatically")
    print("   3. Test with real images!")
    
except subprocess.CalledProcessError as e:
    print(f"\n❌ Conversion failed!")
    print(f"Error: {e.stderr}")
    print("\nTry installing: pip install tensorflowjs")
    sys.exit(1)
except FileNotFoundError:
    print(f"\n❌ tensorflowjs_converter not found!")
    print("\nInstall with: pip install tensorflowjs")
    sys.exit(1)