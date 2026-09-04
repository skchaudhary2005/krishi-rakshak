// 🤖 Pre-Trained Models Service - Production Ready
// Manages loading and using multiple pre-trained deep learning models

import * as tf from '@tensorflow/tfjs';

export interface ModelConfig {
  name: string;
  url: string;
  accuracy: number;
  size: number; // MB
  speed: 'fast' | 'medium' | 'slow';
  inputSize: number;
  classes: number;
}

// Available pre-trained models with real TensorFlow Hub URLs
export const AVAILABLE_MODELS: ModelConfig[] = [
  {
    name: 'MobileNetV2',
    url: 'https://tfhub.dev/google/imagenet/mobilenet_v2_100_224/classification/5',
    accuracy: 0.89,
    size: 14,
    speed: 'fast',
    inputSize: 224,
    classes: 1000
  },
  {
    name: 'MobileNetV3',
    url: 'https://tfhub.dev/google/imagenet/mobilenet_v3_large_100_224/classification/5',
    accuracy: 0.92,
    size: 21,
    speed: 'fast',
    inputSize: 224,
    classes: 1000
  },
  {
    name: 'EfficientNet-B0',
    url: 'https://tfhub.dev/tensorflow/efficientnet/b0/classification/1',
    accuracy: 0.93,
    size: 29,
    speed: 'fast',
    inputSize: 224,
    classes: 1000
  },
  {
    name: 'EfficientNet-B3',
    url: 'https://tfhub.dev/tensorflow/efficientnet/b3/classification/1',
    accuracy: 0.96,
    size: 48,
    speed: 'medium',
    inputSize: 300,
    classes: 1000
  },
  {
    name: 'ResNet50V2',
    url: 'https://tfhub.dev/google/imagenet/resnet_v2_50/classification/5',
    accuracy: 0.94,
    size: 98,
    speed: 'medium',
    inputSize: 224,
    classes: 1000
  },
  {
    name: 'InceptionV3',
    url: 'https://tfhub.dev/google/imagenet/inception_v3/classification/5',
    accuracy: 0.95,
    size: 92,
    speed: 'medium',
    inputSize: 299,
    classes: 1000
  },
  {
    name: 'DenseNet121',
    url: 'https://tfhub.dev/tensorflow/densenet/121/classification/1',
    accuracy: 0.94,
    size: 33,
    speed: 'fast',
    inputSize: 224,
    classes: 1000
  }
];

export class PretrainedModelService {
  private loadedModels: Map<string, tf.GraphModel | tf.LayersModel> = new Map();
  private loadingPromises: Map<string, Promise<tf.GraphModel | tf.LayersModel>> = new Map();
  
  /**
   * Load a specific pre-trained model
   */
  async loadModel(modelName: string): Promise<tf.GraphModel | tf.LayersModel> {
    // Return if already loaded
    if (this.loadedModels.has(modelName)) {
      console.log(`✅ ${modelName} already loaded`);
      return this.loadedModels.get(modelName)!;
    }
    
    // Return existing promise if currently loading
    if (this.loadingPromises.has(modelName)) {
      console.log(`⏳ ${modelName} is loading...`);
      return this.loadingPromises.get(modelName)!;
    }
    
    const config = AVAILABLE_MODELS.find(m => m.name === modelName);
    if (!config) {
      throw new Error(`Model ${modelName} not found in available models`);
    }
    
    // Create loading promise
    const loadingPromise = this.loadModelFromHub(config);
    this.loadingPromises.set(modelName, loadingPromise);
    
    try {
      const model = await loadingPromise;
      this.loadedModels.set(modelName, model);
      this.loadingPromises.delete(modelName);
      
      console.log(`✅ ${modelName} loaded successfully (${config.size}MB)`);
      return model;
    } catch (error) {
      this.loadingPromises.delete(modelName);
      console.error(`❌ Failed to load ${modelName}:`, error);
      throw error;
    }
  }
  
  /**
   * Load model from TensorFlow Hub
   */
  private async loadModelFromHub(config: ModelConfig): Promise<tf.GraphModel | tf.LayersModel> {
    console.log(`🔄 Loading ${config.name} from TensorFlow Hub...`);
    
    try {
      // Try loading as GraphModel first (TF Hub format)
      const model = await tf.loadGraphModel(config.url, {
        fromTFHub: true
      });
      return model;
    } catch (error) {
      console.warn(`Could not load ${config.name} as GraphModel, trying LayersModel...`);
      
      // Fallback to LayersModel
      const model = await tf.loadLayersModel(config.url);
      return model;
    }
  }
  
  /**
   * Load multiple models in parallel
   */
  async loadModels(modelNames: string[]): Promise<void> {
    console.log(`🔄 Loading ${modelNames.length} models in parallel...`);
    await Promise.all(modelNames.map(name => this.loadModel(name)));
    console.log(`✅ All ${modelNames.length} models loaded!`);
  }
  
  /**
   * Load all available models
   */
  async loadAllModels(): Promise<void> {
    const modelNames = AVAILABLE_MODELS.map(m => m.name);
    await this.loadModels(modelNames);
  }
  
  /**
   * Get a loaded model
   */
  getModel(modelName: string): tf.GraphModel | tf.LayersModel | null {
    return this.loadedModels.get(modelName) || null;
  }
  
  /**
   * Check if model is loaded
   */
  isModelLoaded(modelName: string): boolean {
    return this.loadedModels.has(modelName);
  }
  
  /**
   * Get info about a model
   */
  getModelInfo(modelName: string): ModelConfig | undefined {
    return AVAILABLE_MODELS.find(m => m.name === modelName);
  }
  
  /**
   * List all available models
   */
  listAvailableModels(): ModelConfig[] {
    return AVAILABLE_MODELS;
  }
  
  /**
   * Get loaded models count
   */
  getLoadedModelsCount(): number {
    return this.loadedModels.size;
  }
  
  /**
   * Unload a specific model to free memory
   */
  unloadModel(modelName: string): void {
    const model = this.loadedModels.get(modelName);
    if (model) {
      if ('dispose' in model) {
        model.dispose();
      }
      this.loadedModels.delete(modelName);
      console.log(`🗑️ Unloaded ${modelName}`);
    }
  }
  
  /**
   * Unload all models
   */
  unloadAllModels(): void {
    this.loadedModels.forEach((_model, name) => {
      this.unloadModel(name);
    });
    console.log(`🗑️ All models unloaded`);
  }
  
  /**
   * Get memory usage info
   */
  getMemoryInfo(): {
    totalModelsLoaded: number;
    estimatedMemoryMB: number;
    models: { name: string; sizeMB: number }[];
  } {
    const models = Array.from(this.loadedModels.keys()).map(name => {
      const config = this.getModelInfo(name);
      return {
        name,
        sizeMB: config?.size || 0
      };
    });
    
    const estimatedMemoryMB = models.reduce((sum, m) => sum + m.sizeMB, 0);
    
    return {
      totalModelsLoaded: this.loadedModels.size,
      estimatedMemoryMB,
      models
    };
  }
  
  /**
   * Preprocess image for model input
   */
  preprocessImage(
    image: HTMLImageElement | HTMLCanvasElement | ImageData,
    config: ModelConfig
  ): tf.Tensor {
    let tensor = tf.browser.fromPixels(image);
    
    // Resize to model input size
    tensor = tf.image.resizeBilinear(tensor, [config.inputSize, config.inputSize]);
    
    // Normalize to [0, 1]
    tensor = tensor.toFloat().div(255.0);
    
    // Add batch dimension
    tensor = tensor.expandDims(0);
    
    return tensor;
  }
  
  /**
   * Run inference on a single model
   */
  async predict(
    modelName: string,
    image: HTMLImageElement | HTMLCanvasElement | ImageData
  ): Promise<{ predictions: number[]; topK: { index: number; score: number }[] }> {
    const model = await this.loadModel(modelName);
    const config = this.getModelInfo(modelName);
    
    if (!config) {
      throw new Error(`Model ${modelName} not found`);
    }
    
    // Preprocess image
    const tensor = this.preprocessImage(image, config);
    
    // Run prediction
    const predictions = model.predict(tensor) as tf.Tensor;
    const scoresArray = await predictions.data();
    
    // Get top 5 predictions
    const topK = this.getTopKPredictions(Array.from(scoresArray), 5);
    
    // Cleanup
    tensor.dispose();
    predictions.dispose();
    
    return {
      predictions: Array.from(scoresArray),
      topK
    };
  }
  
  /**
   * Get top K predictions with indices
   */
  private getTopKPredictions(scores: number[], k: number): { index: number; score: number }[] {
    const indexed = scores.map((score, index) => ({ score, index }));
    indexed.sort((a, b) => b.score - a.score);
    return indexed.slice(0, k);
  }
}

// Singleton instance
export const pretrainedModels = new PretrainedModelService();