#!/usr/bin/env python3
"""
FINAL ULTRA FAST TRAINING - 5 EPOCHS WITH IMAGE VALIDATION
Combines all datasets and trains with maximum speed
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
from PIL import Image
from datetime import datetime

print("=" * 80)
print("⚡ FINAL ULTRA FAST TRAINING - 5 EPOCHS")
print("=" * 80)
print("🚀 Mode: MAXIMUM SPEED")

# ============================================================================
# CONFIGURATION - MAXIMUM SPEED
# ============================================================================

IMG_SIZE = 96        # Small size = FAST
BATCH_SIZE = 160     # Large batch = FAST
EPOCHS = 5           # Few epochs = FAST
LEARNING_RATE = 0.002
TARGET_ACCURACY = 0.80

print(f"📊 Image: {IMG_SIZE}x{IMG_SIZE} | Batch: {BATCH_SIZE} | Epochs: {EPOCHS}")
print(f"🎯 Target: {TARGET_ACCURACY*100}% accuracy")
print("=" * 80)

# ============================================================================
# STEP 1: CLEAN & COMBINE DATASETS
# ============================================================================

PLANTVILLAGE = Path("datasets/unified/train")
INDIAN = Path("datasets/indian_crops")
COMBINED = Path("datasets/combined_all/train")

print("\n📂 Combining and cleaning ALL datasets...")

if COMBINED.exists():
    print("   🗑️  Removing old data...")
    shutil.rmtree(COMBINED)
COMBINED.mkdir(parents=True, exist_ok=True)

def is_valid_image(img_path):
    """Check if image is valid and not corrupted"""
    try:
        with Image.open(img_path) as img:
            img.verify()
        with Image.open(img_path) as img:
            img.load()
        return True
    except:
        return False

def copy_valid_images(source_dir, dest_dir, label):
    """Copy only valid images from source to destination"""
    valid_count = 0
    corrupted_count = 0
    
    for img_file in source_dir.rglob("*"):
        if img_file.suffix.lower() in ['.jpg', '.jpeg', '.png', '.gif', '.bmp']:
            if is_valid_image(img_file):
                class_name = img_file.parent.name
                dest_class = dest_dir / class_name
                dest_class.mkdir(exist_ok=True)
                
                dest_file = dest_class / f"{label}_{img_file.name}"
                shutil.copy2(img_file, dest_file)
                valid_count += 1
            else:
                corrupted_count += 1
    
    return valid_count, corrupted_count

# Copy PlantVillage
print("   📁 PlantVillage data...")
pv_valid, pv_corrupt = copy_valid_images(PLANTVILLAGE, COMBINED, "pv")
print(f"   ✅ {pv_valid:,} images (skipped {pv_corrupt} corrupted)")

# Copy Indian crops
print("   📁 Indian crops data...")
ind_valid, ind_corrupt = copy_valid_images(INDIAN, COMBINED, "indian")
print(f"   ✅ {ind_valid:,} images (skipped {ind_corrupt} corrupted)")

# Count total
total_images = pv_valid + ind_valid
total_classes = len([d for d in COMBINED.iterdir() if d.is_dir()])
print(f"\n   🎯 TOTAL: {total_images:,} VALID images | {total_classes} classes")

# ============================================================================
# STEP 2: CREATE DATA GENERATORS - SPEED OPTIMIZED
# ============================================================================

print("\n📊 Loading data with SPEED optimization...")

# Minimal augmentation for speed
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
# STEP 3: BUILD MODEL - FAST ARCHITECTURE
# ============================================================================

print("\n🔨 Building ULTRA SPEED model...")

# MobileNetV2 base - optimized for speed
base_model = MobileNetV2(
    input_shape=(IMG_SIZE, IMG_SIZE, 3),
    include_top=False,
    weights='imagenet'
)
base_model.trainable = False  # Freeze for speed

# Simple head
x = base_model.output
x = GlobalAveragePooling2D()(x)
x = Dropout(0.2)(x)
x = Dense(256, activation='relu')(x)
x = Dropout(0.2)(x)
predictions = Dense(num_classes, activation='softmax')(x)

model = Model(inputs=base_model.input, outputs=predictions)

# Compile with speed optimizations
model.compile(
    optimizer=keras.optimizers.Adam(learning_rate=LEARNING_RATE),
    loss='categorical_crossentropy',
    metrics=['accuracy', keras.metrics.TopKCategoricalAccuracy(k=3, name='top3_acc')]
)

total_params = model.count_params()
trainable_params = sum([tf.size(w).numpy() for w in model.trainable_weights])
frozen_params = total_params - trainable_params

print(f"✅ Model built!")
print(f"   Total params: {total_params:,}")
print(f"   Trainable: {trainable_params:,}")
print(f"   Frozen: {frozen_params:,}")

# ============================================================================
# STEP 4: CALLBACKS
# ============================================================================

OUTPUT_DIR = Path("models/final_model")
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
# STEP 5: TRAIN
# ============================================================================

print("\n" + "=" * 80)
print("🚀 ULTRA FAST TRAINING STARTED")
print("=" * 80)
print(f"⏰ Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
print(f"🎯 Training for maximum {EPOCHS} epochs")
print(f"⚡ Speed mode: MAXIMUM")
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
    # SAVE EVERYTHING
    # ========================================================================
    
    print("\n" + "=" * 80)
    print("💾 SAVING MODEL AND RESULTS")
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
    
    # Save config
    config = {
        'image_size': IMG_SIZE,
        'batch_size': BATCH_SIZE,
        'epochs': EPOCHS,
        'num_classes': num_classes,
        'training_samples': train_generator.samples,
        'validation_samples': val_generator.samples,
        'total_images': total_images,
        'training_time_seconds': duration,
        'timestamp': datetime.now().isoformat()
    }
    
    with open(OUTPUT_DIR / 'config.json', 'w') as f:
        json.dump(config, f, indent=2)
    print("✅ Saved config.json")
    
    # ========================================================================
    # FINAL RESULTS
    # ========================================================================
    
    final_acc = history.history['val_accuracy'][-1] * 100
    best_acc = max(history.history['val_accuracy']) * 100
    
    print("\n" + "=" * 80)
    print("🎉 TRAINING COMPLETE!")
    print("=" * 80)
    print(f"⏱️  Duration: {int(duration // 60)}m {int(duration % 60)}s")
    print(f"📊 Final Validation Accuracy: {final_acc:.1f}%")
    print(f"🏆 Best Validation Accuracy: {best_acc:.1f}%")
    print(f"💾 Model saved: {OUTPUT_DIR / 'best_model.h5'}")
    print("=" * 80)
    
    if best_acc >= TARGET_ACCURACY * 100:
        print("✅ TARGET ACCURACY REACHED!")
    else:
        print(f"⚠️  Target was {TARGET_ACCURACY*100}%, consider training longer")
    
except KeyboardInterrupt:
    print("\n\n⚠️  Training interrupted by user!")
    print(f"💾 Best model saved in: {OUTPUT_DIR}")

except Exception as e:
    print(f"\n\n❌ Error during training: {e}")
    import traceback
    traceback.print_exc()

print("\n✅ Script completed!\n")