import os
import json
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers
from tensorflow.keras.applications import MobileNetV2

# =========================
# PATHS
# =========================

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

TRAIN_DIR = os.path.join(BASE_DIR, "datasets", "unified", "train")
VAL_DIR = os.path.join(BASE_DIR, "datasets", "unified", "val")

OUTPUT_DIR = os.path.join(
    BASE_DIR,
    "public",
    "models",
    "final_deployed_model"
)

MODEL_PATH = os.path.join(OUTPUT_DIR, "best_model.weights.h5")
CLASSES_PATH = os.path.join(OUTPUT_DIR, "classes.json")

os.makedirs(OUTPUT_DIR, exist_ok=True)

# =========================
# SETTINGS
# =========================

IMAGE_SIZE = (224, 224)
BATCH_SIZE = 32
EPOCHS = 5
SEED = 123

print("=" * 70)
print("🌾 PLANTVILLAGE CROP DISEASE MODEL")
print("=" * 70)

print("Train:", TRAIN_DIR)
print("Val  :", VAL_DIR)

# =========================
# LOAD DATA
# =========================

train_ds = tf.keras.utils.image_dataset_from_directory(
    TRAIN_DIR,
    labels="inferred",
    label_mode="int",
    image_size=IMAGE_SIZE,
    batch_size=BATCH_SIZE,
    shuffle=True,
    seed=SEED
)

val_ds = tf.keras.utils.image_dataset_from_directory(
    VAL_DIR,
    labels="inferred",
    label_mode="int",
    image_size=IMAGE_SIZE,
    batch_size=BATCH_SIZE,
    shuffle=False
)

# =========================
# CLASSES
# =========================

class_names = train_ds.class_names
num_classes = len(class_names)

print("\nNumber of classes:", num_classes)

if class_names != val_ds.class_names:
    raise ValueError(
        "TRAIN and VAL classes are different!"
    )

with open(CLASSES_PATH, "w", encoding="utf-8") as f:
    json.dump(class_names, f, indent=4)

print("Classes saved:", CLASSES_PATH)

# =========================
# PERFORMANCE
# =========================

AUTOTUNE = tf.data.AUTOTUNE

train_ds = train_ds.prefetch(AUTOTUNE)
val_ds = val_ds.prefetch(AUTOTUNE)

# =========================
# DATA AUGMENTATION
# =========================

augmentation = keras.Sequential([
    layers.RandomFlip("horizontal"),
    layers.RandomRotation(0.1),
    layers.RandomZoom(0.1),
])

# =========================
# BASE MODEL
# =========================

print("\n🤖 Loading MobileNetV2...")

base_model = MobileNetV2(
    input_shape=(224, 224, 3),
    include_top=False,
    weights="imagenet"
)

base_model.trainable = False

# =========================
# BUILD MODEL
# =========================

inputs = keras.Input(
    shape=(224, 224, 3)
)

x = augmentation(inputs)

x = tf.keras.applications.mobilenet_v2.preprocess_input(x)

x = base_model(
    x,
    training=False
)

x = layers.GlobalAveragePooling2D()(x)

x = layers.Dropout(0.3)(x)

outputs = layers.Dense(
    num_classes,
    activation="softmax"
)(x)

model = keras.Model(
    inputs,
    outputs
)

# =========================
# COMPILE
# =========================

model.compile(
    optimizer=keras.optimizers.Adam(
        learning_rate=0.001
    ),
    loss="sparse_categorical_crossentropy",
    metrics=["accuracy"]
)

model.summary()

# =========================
# CALLBACKS
# =========================

checkpoint = keras.callbacks.ModelCheckpoint(
    filepath=MODEL_PATH,
    monitor="val_accuracy",
    save_best_only=True,
    save_weights_only=True,   # ⭐ IMPORTANT
    mode="max",
    verbose=1
)

early_stop = keras.callbacks.EarlyStopping(
    monitor="val_accuracy",
    patience=2,
    restore_best_weights=True,
    verbose=1
)

reduce_lr = keras.callbacks.ReduceLROnPlateau(
    monitor="val_loss",
    factor=0.5,
    patience=1,
    verbose=1
)

# =========================
# TRAIN
# =========================

print("\n🚀 TRAINING STARTED")
print("=" * 70)

# history = model.fit(
#     train_ds,
#     validation_data=val_ds,
#     epochs=EPOCHS,
#     callbacks=[
#         checkpoint,
#         early_stop,
#         reduce_lr
#     ]
# )

# =========================
# LOAD BEST MODEL
# =========================

print("\n📦 Loading best model...")

OLD_MODEL_PATH = os.path.join(
    OUTPUT_DIR,
    "best_model.h5"
)

model.load_weights(OLD_MODEL_PATH)

best_model = model

print("✅ Best model weights loaded successfully!")

# =========================
# EVALUATE
# =========================

loss, accuracy = best_model.evaluate(
    val_ds,
    verbose=1
)

print("\n" + "=" * 70)
print("🎉 TRAINING COMPLETED")
print("=" * 70)

print(f"Validation Accuracy: {accuracy * 100:.2f}%")
print()
print("Model created:")
print(MODEL_PATH)
print()
print("Classes:")
print(CLASSES_PATH)
print("=" * 70)