# Models Folder

This folder contains trained TensorFlow/Keras models for crop disease detection.

## Structure

```
models/
├── crop_disease_real/        # Main production model (72.19% accuracy, 23 classes)
│   ├── best_model.h5
│   ├── classes.json
│   └── model_info.json
├── all_crops_model/          # Combined model (PlantVillage + Indian crops, 58 classes)
│   ├── best_model.h5
│   ├── classes.json
│   └── training_log.json
└── combined_best_models/     # Best performing models collection
    └── ...
```

## Trained Models

**Note:** Trained models (.h5 files) are NOT included in the repository due to their large size (50-200MB each).

### Download Pre-trained Models

You can download pre-trained models from:
- **Google Drive**: [Link to be added]
- **Hugging Face**: [Link to be added]
- **GitHub Releases**: Check the releases section

### Or Train Your Own

```bash
# Train on PlantVillage dataset only
python train_final.py

# Train on combined datasets (PlantVillage + Indian crops)
python train_combined.py
```

## Model Architecture

- **Base**: MobileNetV2 (ImageNet pre-trained)
- **Input Size**: 96x96 or 224x224 RGB
- **Parameters**: ~2.6M - 3M
- **Output**: Softmax classifier (23 or 58 classes)

## Model Performance

### Current Production Model (crop_disease_real)
- **Accuracy**: 72.19%
- **Classes**: 23 disease types
- **Image Size**: 224x224
- **Dataset**: PlantVillage (26,172 images)

### Combined Model (all_crops_model)
- **Accuracy**: TBD
- **Classes**: 58 disease types
- **Image Size**: 96x96
- **Dataset**: PlantVillage + Indian Crops (28,000+ images)

## Model Files

Each trained model directory contains:

1. **best_model.h5** - The trained Keras model (50-200MB)
2. **classes.json** - Class index to name mapping
3. **model_info.json** - Model metadata (accuracy, parameters, etc.)
4. **training_log.json** - Training history (loss, accuracy per epoch)

## Usage

### Load Model in Python

```python
from tensorflow import keras
import json

# Load model
model = keras.models.load_model('models/crop_disease_real/best_model.h5')

# Load class names
with open('models/crop_disease_real/classes.json') as f:
    classes = json.load(f)

# Make prediction
prediction = model.predict(image_array)
predicted_class = classes[prediction.argmax()]
```

### Use with API Server

```bash
# Model is automatically loaded by the API server
python api_server.py
```

## Model Deployment

Trained models are deployed to:
- `public/models/final_deployed_model/` - For production API use
- Flask API server at `http://localhost:5000`
- React frontend integration

## Training New Models

See `TRAINING_INSTRUCTIONS.txt` for detailed training guide.

Quick start:
```bash
# Install dependencies
pip install -r requirements.txt

# Train model
python train_combined.py

# Test model
python test_all_models.py
```