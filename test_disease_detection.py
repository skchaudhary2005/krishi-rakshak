#!/usr/bin/env python3
"""
Test disease detection on real images and show detailed results
"""

import os
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '2'

import tensorflow as tf
from tensorflow import keras
import numpy as np
from pathlib import Path
from PIL import Image
import json
import random

print("=" * 80)
print("🧪 CROP DISEASE DETECTION TEST")
print("=" * 80)

# ============================================================================
# LOAD MODEL
# ============================================================================

MODEL_PATH = Path("public/models/final_deployed_model/best_model.h5")
CLASSES_PATH = Path("models/combined_best_models/crop_disease_real/classes.json")

print(f"\n📦 Loading model...")
model = keras.models.load_model(MODEL_PATH)
print(f"✅ Model loaded: {model.count_params():,} parameters")

# Load class names if available
class_names = {}
class_to_name = {}

if CLASSES_PATH.exists():
    with open(CLASSES_PATH, 'r') as f:
        class_names = json.load(f)
    # Reverse mapping: index -> name
    class_to_name = {v: k for k, v in class_names.items()}
    print(f"✅ Loaded {len(class_names)} class names")
else:
    print(f"⚠️  Class names not found, using indices")

# ============================================================================
# FIND TEST IMAGES
# ============================================================================

TEST_DATA_PATH = Path("datasets/unified/test")

if not TEST_DATA_PATH.exists():
    print(f"\n❌ Test dataset not found: {TEST_DATA_PATH}")
    exit(1)

print(f"\n📁 Searching for test images in: {TEST_DATA_PATH}")

# Collect all test images
test_images = []
for class_dir in TEST_DATA_PATH.iterdir():
    if class_dir.is_dir():
        images = list(class_dir.glob("*.jpg")) + list(class_dir.glob("*.JPG")) + \
                 list(class_dir.glob("*.png")) + list(class_dir.glob("*.PNG"))
        for img_path in images:
            test_images.append({
                'path': img_path,
                'true_class': class_dir.name,
                'class_index': class_names.get(class_dir.name, -1)
            })

print(f"✅ Found {len(test_images)} test images across {len(list(TEST_DATA_PATH.iterdir()))} classes")

# ============================================================================
# SELECT RANDOM IMAGES FOR TESTING
# ============================================================================

NUM_SAMPLES = min(10, len(test_images))  # Test 10 random images
selected_images = random.sample(test_images, NUM_SAMPLES)

print(f"\n🎲 Testing {NUM_SAMPLES} random images...")
print("=" * 80)

# ============================================================================
# TEST EACH IMAGE
# ============================================================================

correct_predictions = 0
correct_top3 = 0

for i, img_info in enumerate(selected_images, 1):
    img_path = img_info['path']
    true_class = img_info['true_class']
    true_index = img_info['class_index']
    
    print(f"\n[{i}/{NUM_SAMPLES}] Testing: {img_path.name}")
    print("-" * 80)
    print(f"📁 Location: {img_path.parent.name}/")
    print(f"🏷️  True Disease: {true_class}")
    
    try:
        # Load and preprocess image
        img = Image.open(img_path).convert('RGB')
        original_size = img.size
        
        # Resize to model input size
        img_resized = img.resize((224, 224))
        img_array = np.array(img_resized) / 255.0
        img_array = np.expand_dims(img_array, axis=0)
        
        # Make prediction
        predictions = model.predict(img_array, verbose=0)
        
        # Get top 5 predictions
        top_5_idx = np.argsort(predictions[0])[-5:][::-1]
        top_5_probs = predictions[0][top_5_idx]
        
        # Check if prediction is correct
        predicted_idx = top_5_idx[0]
        is_correct = (predicted_idx == true_index) if true_index != -1 else False
        is_in_top3 = (true_index in top_5_idx[:3]) if true_index != -1 else False
        
        if is_correct:
            correct_predictions += 1
        if is_in_top3:
            correct_top3 += 1
        
        # Display results
        print(f"\n📊 Detection Results:")
        print(f"   Image size: {original_size[0]}x{original_size[1]} → 224x224")
        print(f"\n   Top 5 Predictions:")
        
        for rank, (idx, prob) in enumerate(zip(top_5_idx, top_5_probs), 1):
            predicted_name = class_to_name.get(idx, f"Class_{idx}")
            confidence = prob * 100
            
            # Mark correct prediction
            marker = ""
            if idx == true_index:
                marker = " ✅ CORRECT!"
            elif rank <= 3 and true_index in top_5_idx[:3]:
                marker = " (in top 3)"
            
            print(f"      {rank}. {predicted_name:<40} {confidence:>6.2f}%{marker}")
        
        # Overall assessment
        print(f"\n   Assessment:")
        if is_correct:
            print(f"   ✅ CORRECT - Top prediction matches true disease!")
        elif is_in_top3:
            print(f"   ⚠️  PARTIAL - True disease in top 3 predictions")
        else:
            print(f"   ❌ INCORRECT - True disease not in top 5")
        
    except Exception as e:
        print(f"   ❌ Error processing image: {e}")

# ============================================================================
# SUMMARY STATISTICS
# ============================================================================

print("\n" + "=" * 80)
print("📊 DETECTION SUMMARY")
print("=" * 80)

accuracy = (correct_predictions / NUM_SAMPLES) * 100
top3_accuracy = (correct_top3 / NUM_SAMPLES) * 100

print(f"\n✅ Images Tested: {NUM_SAMPLES}")
print(f"✅ Correct Predictions: {correct_predictions}/{NUM_SAMPLES} ({accuracy:.1f}%)")
print(f"✅ Top-3 Accuracy: {correct_top3}/{NUM_SAMPLES} ({top3_accuracy:.1f}%)")

print(f"\n📈 Performance:")
if accuracy >= 70:
    print(f"   🟢 EXCELLENT - Model performing well!")
elif accuracy >= 60:
    print(f"   🟡 GOOD - Model performing acceptably")
else:
    print(f"   🔴 NEEDS IMPROVEMENT - Consider retraining")

print("\n💡 Note: This is a small sample test.")
print("   Full test set (8,396 images) shows: 72.19% accuracy, 97% top-3 accuracy")

print("\n" + "=" * 80)
print("✅ DISEASE DETECTION TEST COMPLETE")
print("=" * 80 + "\n")