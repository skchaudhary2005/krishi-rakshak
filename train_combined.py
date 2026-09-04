#!/usr/bin/env python3
"""
FAST TRAINING - Train on PlantVillage + Indian Crops
Uses combined data generator without copying files
"""

import os
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '2'
os.environ['TF_ENABLE_ONEDNN_OPTS'] = '0'

import tensorflow as tf
from tensorflow import keras
from tensorflow.keras.preprocessing.image import ImageDataGenerator
from tensorflow.keras.applications import MobileNetV2
from tensorflow.keras.layers import Dense, GlobalAveragePooling2D, Dropout
from tensorflow.keras.models import Model
from tensorflow.keras.callbacks import EarlyStopping, ReduceLROnPlateau, ModelCheckpoint
from pathlib import Path
import json
import shutil
from datetime import datetime
import numpy as np

print("=" * 80)
print("⚡ TRAINING ALL CROPS - PlantVillage + Indian Crops")
print("=" * 80)

# ============================================================================
# CONFIGURATION
# ============================================================================

IMG_SIZE = 96
BATCH_SIZE = 160
EPOCHS = 5
LEARNING_RATE = 0.002

print(f"📊 Image: {IMG_SIZE}x{IMG_SIZE} | Batch: {BATCH_SIZE} | Epochs: {EPOCHS}")
print("=" * 80)

# ============================================================================
# COMBINE DATASETS
# ============================================================================

PLANTVILLAGE = Path("datasets/unified/train")
INDIAN = Path("datasets/indian_crops")
COMBINED = Path("datasets/combined_all/train")

print("\n📂 Creating combined dataset structure...")

if COMBINED.exists():
    print("   🗑️  Removing old combined folder...")
    try:
        shutil.rmtree(COMBINED)
    except:
        pass

COMBINED.mkdir(parents=True, exist_ok=True)

# Create class folders and use junctions (Windows symlinks)
print("   📁 Linking PlantVillage classes...")
pv_classes = [d for d in PLANTVILLAGE.iterdir() if d.is_dir()]
for class_dir in pv_classes:
    dest = COMBINED / class_dir.name
    if not dest.exists():
        try:
            # Try creating junction (faster than copying)
            import subprocess
            subprocess.run(['mklink', '/J', str(dest), str(class_dir)], 
                         shell=True, capture_output=True)
            if not dest.exists():
                # Fallback to copying if junction fails
                shutil.copytree(class_dir, dest)
        except:
            shutil.copytree(class_dir, dest)

print("   📁 Linking Indian crops classes...")
indian_classes = [d for d in INDIAN.iterdir() if d.is_dir()]
for class_dir in indian_classes:
    # Rename to avoid conflicts
    class_name = class_dir.name.replace('__', ' - ')
    dest = COMBINED / class_name
    if not dest.exists():
        try:
            import subprocess
            subprocess.run(['mklink', '/J', str(dest), str(class_dir)], 
                         shell=True, capture_output=True)
            if not dest.exists():
                shutil.copytree(class_dir, dest)
        except:
            shutil.copytree(class_dir, dest)

# Count total
total_classes = len([d for d in COMBINED.iterdir() if d.is_dir()])
print(f"\n   🎯 Total classes: {total_classes}")

# ============================================================================
# DATA GENERATORS
# ============================================================================

print("\n📊 Loading data...")

train_datagen = ImageDataGenerator(
    rescale=1./255,
    validation_split=0.15,
    rotation_range=10,
    horizontal_flip=True,
    fill_mode='nearest'
)

val_datagen = ImageDataGenerator(
    rescale=1./255,
    validation_split=0.15
)

train_generator = train_datagen.flow_from_directory(
    COMBINED,
    target_size=(IMG_SIZE, IMG_SIZE),
    batch_size=BATCH_SIZE,
    class_mode='categorical',
    subset='training',
    shuffle=True
)

val_generator = val_datagen.flow_from_directory(
    COMBINED,
    target_size=(IMG_SIZE, IMG_SIZE),
    batch_size=BATCH_SIZE,
    class_mode='categorical',
    subset='validation',
    shuffle=False
)

num_classes = len(train_generator.class_indices)
print(f"✅ Training: {train_generator.samples:,} images")
print(f"✅ Validation: {val_generator.samples:,} images")
print(f"✅ Classes: {num_classes}")

# ============================================================================
# BUILD MODEL
# ============================================================================

print("\n🔨 Building model...")

base_model = MobileNetV2(
    input_shape=(IMG_SIZE, IMG_SIZE, 3),
    include_top=False,
    weights='imagenet'
)
base_model.trainable = False

x = base_model.output
x = GlobalAveragePooling2D()(x)
x = Dropout(0.2)(x)
x = Dense(256, activation='relu')(x)
x = Dropout(0.2)(x)
predictions = Dense(num_classes, activation='softmax')(x)

model = Model(inputs=base_model.input, outputs=predictions)

model.compile(
    optimizer=keras.optimizers.Adam(learning_rate=LEARNING_RATE),
    loss='categorical_crossentropy',
    metrics=['accuracy', keras.metrics.TopKCategoricalAccuracy(k=3, name='top3_acc')]
)

total_params = model.count_params()
print(f"✅ Model: {total_params:,} parameters")

# ============================================================================
# CALLBACKS
# ============================================================================

OUTPUT_DIR = Path("models/all_crops_model")
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

callbacks = [
    EarlyStopping(
        monitor='val_accuracy',
        patience=2,
        restore_best_weights=True,
        verbose=1
    ),
    ReduceLROnPlateau(
        monitor='val_accuracy',
        factor=0.5,
        patience=1,
        min_lr=0.00001,
        verbose=1
    ),
    ModelCheckpoint(
        OUTPUT_DIR / 'best_model.h5',
        monitor='val_accuracy',
        save_best_only=True,
        verbose=1
    )
]

# ============================================================================
# TRAIN
# ============================================================================

print("\n" + "=" * 80)
print("🚀 TRAINING STARTED")
print("=" * 80)
print(f"⏰ Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
print("=" * 80 + "\n")

start_time = datetime.now()

try:
    history = model.fit(
        train_generator,
        validation_data=val_generator,
        epochs=EPOCHS,
        callbacks=callbacks,
        verbose=1
    )
    
    end_time = datetime.now()
    duration = (end_time - start_time).total_seconds()
    
    # ========================================================================
    # SAVE RESULTS
    # ========================================================================
    
    print("\n" + "=" * 80)
    print("💾 SAVING MODEL")
    print("=" * 80)
    
    # Save class names
    with open(OUTPUT_DIR / 'classes.json', 'w') as f:
        json.dump(train_generator.class_indices, f, indent=2)
    print("✅ Saved classes.json")
    
    # Save training history
    history_data = {
        'accuracy': [float(x) for x in history.history.get('accuracy', [])],
        'val_accuracy': [float(x) for x in history.history.get('val_accuracy', [])],
        'loss': [float(x) for x in history.history.get('loss', [])],
        'val_loss': [float(x) for x in history.history.get('val_loss', [])]
    }
    
    with open(OUTPUT_DIR / 'training_log.json', 'w') as f:
        json.dump(history_data, f, indent=2)
    print("✅ Saved training_log.json")
    
    # Save model info
    final_acc = history.history['val_accuracy'][-1] * 100
    best_acc = max(history.history['val_accuracy']) * 100
    
    model_info = {
        'classes': num_classes,
        'parameters': total_params,
        'image_size': IMG_SIZE,
        'accuracy': best_acc,
        'training_samples': train_generator.samples,
        'validation_samples': val_generator.samples,
        'epochs_trained': len(history.history['accuracy']),
        'training_time_seconds': duration,
        'timestamp': datetime.now().isoformat()
    }
    
    with open(OUTPUT_DIR / 'model_info.json', 'w') as f:
        json.dump(model_info, f, indent=2)
    print("✅ Saved model_info.json")
    
    # ========================================================================
    # RESULTS
    # ========================================================================
    
    print("\n" + "=" * 80)
    print("🎉 TRAINING COMPLETE!")
    print("=" * 80)
    print(f"⏱️  Duration: {int(duration // 60)}m {int(duration % 60)}s")
    print(f"📊 Final Accuracy: {final_acc:.1f}%")
    print(f"🏆 Best Accuracy: {best_acc:.1f}%")
    print(f"📁 Classes: {num_classes} disease types")
    print(f"💾 Saved: {OUTPUT_DIR / 'best_model.h5'}")
    print("=" * 80)
    
except KeyboardInterrupt:
    print("\n\n⚠️  Training interrupted!")
    
except Exception as e:
    print(f"\n\n❌ Error: {e}")
    import traceback
    traceback.print_exc()

print("\n✅ Done!\n")