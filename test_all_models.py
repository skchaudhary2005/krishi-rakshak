#!/usr/bin/env python3
"""
TEST ALL MODELS - Compare performance and delete poor models
"""

import os
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '2'
os.environ['TF_ENABLE_ONEDNN_OPTS'] = '0'

import tensorflow as tf
from tensorflow import keras
from tensorflow.keras.preprocessing.image import ImageDataGenerator
from pathlib import Path
import json
import shutil
import numpy as np
from datetime import datetime

print("=" * 80)
print("🧪 TESTING ALL MODELS")
print("=" * 80)

# ============================================================================
# FIND ALL MODELS
# ============================================================================

MODELS_DIR = Path("models")
TEST_DATA = Path("datasets/unified/test")  # Use test set
VAL_DATA = Path("datasets/unified/valid")   # Use validation set

# Fallback to validation if test doesn't exist
if not TEST_DATA.exists():
    TEST_DATA = VAL_DATA
    print("⚠️  Using validation set for testing (test set not found)")

print(f"\n📂 Scanning for trained models...")

models_found = []

# Search for all .h5 files
for model_dir in MODELS_DIR.iterdir():
    if model_dir.is_dir():
        # Look for best_model.h5 or interrupted_model.h5
        best_model = model_dir / "best_model.h5"
        interrupted_model = model_dir / "interrupted_model.h5"
        
        if best_model.exists():
            models_found.append({
                'name': model_dir.name,
                'path': best_model,
                'type': 'best',
                'config': model_dir / 'config.json',
                'classes': model_dir / 'classes.json'
            })
        elif interrupted_model.exists():
            models_found.append({
                'name': model_dir.name,
                'path': interrupted_model,
                'type': 'interrupted',
                'config': model_dir / 'config.json',
                'classes': model_dir / 'classes.json'
            })

print(f"✅ Found {len(models_found)} models:\n")
for i, model in enumerate(models_found, 1):
    print(f"   {i}. {model['name']} ({model['type']})")

# ============================================================================
# LOAD TEST DATA
# ============================================================================

print(f"\n📊 Loading test data from: {TEST_DATA}")

test_datagen = ImageDataGenerator(rescale=1./255)

# ============================================================================
# TEST EACH MODEL
# ============================================================================

results = []

print("\n" + "=" * 80)
print("🚀 TESTING MODELS")
print("=" * 80)

for idx, model_info in enumerate(models_found, 1):
    print(f"\n[{idx}/{len(models_found)}] Testing: {model_info['name']}")
    print("-" * 80)
    
    try:
        # Load config to get image size
        img_size = 224  # Default
        num_classes = None
        
        if model_info['config'].exists():
            with open(model_info['config'], 'r') as f:
                config = json.load(f)
                img_size = config.get('image_size', 224)
                num_classes = config.get('num_classes')
        
        print(f"   📐 Image size: {img_size}x{img_size}")
        
        # Load the model
        print(f"   📦 Loading model...")
        model = keras.models.load_model(model_info['path'])
        
        # Get model info
        total_params = model.count_params()
        print(f"   ✅ Model loaded: {total_params:,} parameters")
        
        # Create test generator with correct image size
        test_generator = test_datagen.flow_from_directory(
            TEST_DATA,
            target_size=(img_size, img_size),
            batch_size=32,
            class_mode='categorical',
            shuffle=False
        )
        
        test_classes = len(test_generator.class_indices)
        print(f"   📊 Test classes: {test_classes}")
        print(f"   📊 Test samples: {test_generator.samples}")
        
        # Evaluate the model
        print(f"   🧪 Evaluating...")
        evaluation = model.evaluate(test_generator, verbose=0)
        
        # Get metrics
        loss = evaluation[0]
        accuracy = evaluation[1] if len(evaluation) > 1 else 0
        top3_acc = evaluation[2] if len(evaluation) > 2 else 0
        
        print(f"   📈 Loss: {loss:.4f}")
        print(f"   📈 Accuracy: {accuracy*100:.2f}%")
        if top3_acc > 0:
            print(f"   📈 Top-3 Accuracy: {top3_acc*100:.2f}%")
        
        # Make some predictions to check
        print(f"   🔮 Testing predictions...")
        predictions = model.predict(test_generator, verbose=0)
        predicted_classes = np.argmax(predictions, axis=1)
        true_classes = test_generator.classes
        
        # Calculate additional metrics
        correct = np.sum(predicted_classes == true_classes)
        total = len(true_classes)
        calc_accuracy = correct / total
        
        print(f"   ✅ Predictions work: {calc_accuracy*100:.2f}% accurate")
        
        # Store results
        results.append({
            'name': model_info['name'],
            'path': str(model_info['path']),
            'type': model_info['type'],
            'accuracy': float(accuracy),
            'top3_accuracy': float(top3_acc) if top3_acc > 0 else None,
            'loss': float(loss),
            'parameters': int(total_params),
            'image_size': img_size,
            'test_classes': test_classes,
            'test_samples': test_generator.samples,
            'status': 'PASS' if accuracy >= 0.60 else 'FAIL'  # 60% minimum
        })
        
        print(f"   {'✅ PASS' if accuracy >= 0.60 else '❌ FAIL'}")
        
        # Clear memory
        del model
        keras.backend.clear_session()
        
    except Exception as e:
        print(f"   ❌ Error: {e}")
        results.append({
            'name': model_info['name'],
            'path': str(model_info['path']),
            'type': model_info['type'],
            'accuracy': 0.0,
            'loss': 999.0,
            'error': str(e),
            'status': 'ERROR'
        })

# ============================================================================
# ANALYZE RESULTS
# ============================================================================

print("\n" + "=" * 80)
print("📊 RESULTS SUMMARY")
print("=" * 80)

# Sort by accuracy
results.sort(key=lambda x: x.get('accuracy', 0), reverse=True)

print(f"\n{'Rank':<6} {'Model Name':<35} {'Accuracy':<12} {'Status':<10}")
print("-" * 80)

for rank, result in enumerate(results, 1):
    acc = result.get('accuracy', 0) * 100
    status = result.get('status', 'UNKNOWN')
    
    status_icon = "✅" if status == "PASS" else "❌" if status == "FAIL" else "⚠️"
    print(f"{rank:<6} {result['name']:<35} {acc:>6.2f}%     {status_icon} {status}")

# ============================================================================
# SAVE RESULTS
# ============================================================================

results_file = Path("models/test_results.json")
with open(results_file, 'w') as f:
    json.dump({
        'timestamp': datetime.now().isoformat(),
        'test_data': str(TEST_DATA),
        'models_tested': len(results),
        'results': results
    }, f, indent=2)

print(f"\n💾 Results saved to: {results_file}")

# ============================================================================
# DELETE POOR PERFORMING MODELS
# ============================================================================

print("\n" + "=" * 80)
print("🗑️  CLEANING UP POOR MODELS")
print("=" * 80)

ACCURACY_THRESHOLD = 0.60  # 60% minimum
models_to_delete = []

for result in results:
    if result.get('status') in ['FAIL', 'ERROR']:
        models_to_delete.append(result)

if models_to_delete:
    print(f"\n⚠️  Found {len(models_to_delete)} poor performing models (< {ACCURACY_THRESHOLD*100}%)\n")
    
    for model in models_to_delete:
        print(f"   ❌ {model['name']}: {model.get('accuracy', 0)*100:.2f}%")
    
    response = input("\n🗑️  Delete these models? (yes/no): ").strip().lower()
    
    if response == 'yes':
        for model in models_to_delete:
            model_dir = Path(model['path']).parent
            try:
                shutil.rmtree(model_dir)
                print(f"   ✅ Deleted: {model_dir.name}")
            except Exception as e:
                print(f"   ❌ Failed to delete {model_dir.name}: {e}")
    else:
        print("\n⏭️  Skipping deletion")
else:
    print("\n✅ All models meet performance threshold!")

# ============================================================================
# CREATE COMBINED MODELS FOLDER
# ============================================================================

print("\n" + "=" * 80)
print("📦 COMBINING BEST MODELS")
print("=" * 80)

COMBINED_DIR = Path("models/combined_best_models")

# Get passing models
passing_models = [r for r in results if r.get('status') == 'PASS']

if passing_models:
    if COMBINED_DIR.exists():
        shutil.rmtree(COMBINED_DIR)
    COMBINED_DIR.mkdir(parents=True, exist_ok=True)
    
    print(f"\n📂 Copying {len(passing_models)} best models to: {COMBINED_DIR}\n")
    
    for result in passing_models:
        source_dir = Path(result['path']).parent
        dest_dir = COMBINED_DIR / source_dir.name
        
        try:
            shutil.copytree(source_dir, dest_dir)
            print(f"   ✅ Copied: {source_dir.name} ({result['accuracy']*100:.2f}%)")
        except Exception as e:
            print(f"   ❌ Failed: {source_dir.name} - {e}")
    
    # Save summary
    summary = {
        'created': datetime.now().isoformat(),
        'models_count': len(passing_models),
        'best_model': passing_models[0]['name'],
        'best_accuracy': passing_models[0]['accuracy'],
        'models': [
            {
                'name': m['name'],
                'accuracy': m['accuracy'],
                'type': m['type']
            } for m in passing_models
        ]
    }
    
    with open(COMBINED_DIR / 'summary.json', 'w') as f:
        json.dump(summary, f, indent=2)
    
    print(f"\n✅ Combined folder created with {len(passing_models)} models")
    print(f"🏆 Best model: {passing_models[0]['name']} ({passing_models[0]['accuracy']*100:.2f}%)")

# ============================================================================
# FINAL SUMMARY
# ============================================================================

print("\n" + "=" * 80)
print("✅ TESTING COMPLETE")
print("=" * 80)
print(f"📊 Models tested: {len(results)}")
print(f"✅ Passing models: {len(passing_models)}")
print(f"❌ Failed models: {len(models_to_delete)}")
print(f"🏆 Best accuracy: {results[0].get('accuracy', 0)*100:.2f}%")
print(f"📁 Best models: models/combined_best_models/")
print("=" * 80 + "\n")