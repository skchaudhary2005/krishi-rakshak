# Datasets Folder

This folder contains the training datasets for the crop disease detection model.

## Structure

```
datasets/
├── unified/           # PlantVillage dataset (26,172 images, 23 classes)
│   ├── train/
│   ├── val/
│   └── test/
├── indian_crops/      # Indian crops dataset (2,166 images, 35 classes)
│   ├── Rice__*/
│   ├── Wheat__*/
│   ├── Cotton__*/
│   ├── Maize__*/
│   ├── Sugarcane__*/
│   └── Chickpea__*/
└── combined_all/      # Combined dataset (auto-generated during training)
    └── train/
```

## Download Datasets

**Note:** Datasets are NOT included in the repository due to their large size.

### PlantVillage Dataset
- Download from: [PlantVillage on Kaggle](https://www.kaggle.com/datasets/emmarex/plantdisease)
- Extract to: `datasets/unified/`
- Size: ~500MB
- Classes: 23 (Tomato, Potato, Pepper diseases)

### Indian Crops Dataset
- Download from: [Indian Crops Dataset](https://www.kaggle.com/datasets/vipoooool/new-plant-diseases-dataset)
- Or use the included scraper scripts
- Extract to: `datasets/indian_crops/`
- Size: ~100MB
- Classes: 35 (Rice, Wheat, Cotton, Maize, Sugarcane, Chickpea diseases)

## Usage

After downloading, your datasets should be structured as shown above. The training scripts will automatically:
1. Validate images
2. Combine datasets
3. Split into train/validation sets
4. Generate class mappings

## Supported Crops

### From PlantVillage (23 classes)
- Tomato (10 diseases)
- Potato (3 diseases)
- Pepper/Bell (2 diseases)
- + Healthy variants

### From Indian Crops (35 classes)
- Rice (14 diseases)
- Wheat (5 diseases)
- Cotton (4 diseases)
- Sugarcane (4 diseases)
- Maize (4 diseases)
- Chickpea (3 diseases)
- + Healthy variants

## Total Dataset Statistics

- **Total Images**: ~28,000+ images
- **Total Classes**: 58 disease types
- **Image Format**: JPG, PNG
- **Recommended Size**: 96x96 to 224x224 pixels