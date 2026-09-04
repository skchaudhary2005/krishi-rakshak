/**
 * Real Trained Model Service
 * Uses Python backend API with trained crop disease model.
 *
 * Optimized:
 * - Does NOT repeatedly check the backend
 * - Caches API health status
 * - Has request timeout
 * - Uses VITE_API_URL from .env
 * - Prediction automatically checks API if required
 */

interface RealModelPrediction {
  disease: string;
  confidence: number;
  crop: string;
  isHealthy: boolean;
  topPredictions: Array<{
    disease: string;
    crop: string;
    confidence: number;
  }>;
}

interface HealthResponse {
  status?: string;
  classes?: number;
}

interface PredictionResponse {
  success?: boolean;
  error?: string;
  prediction?: {
    disease: string;
    crop: string;
    confidence: number;
    isHealthy: boolean;
    topPredictions: Array<{
      disease: string;
      crop: string;
      confidence: number;
    }>;
  };
}

class RealModelService {
  /**
   * Python backend URL.
   *
   * .env:
   * VITE_API_URL=http://localhost:5000
   */
  private apiUrl =
    import.meta.env.VITE_API_URL ||
    'http://localhost:5000';

  private modelReady = false;

  /**
   * Prevent multiple health requests at the same time.
   */
  private loadingPromise: Promise<void> | null = null;

  /**
   * Request timeout.
   */
  private readonly REQUEST_TIMEOUT = 5000;

  /**
   * Create AbortSignal with timeout.
   */
  private createTimeoutSignal(): AbortSignal {
    return AbortSignal.timeout(
      this.REQUEST_TIMEOUT
    );
  }

  /**
   * Check if API server is running.
   *
   * This is lightweight and cached.
   */
  async loadModel(): Promise<void> {
    // Already ready → don't make another request
    if (this.modelReady) {
      return;
    }

    // If another load request is already running,
    // wait for the same request instead of creating another.
    if (this.loadingPromise) {
      return this.loadingPromise;
    }

    this.loadingPromise = this.checkHealth();

    try {
      await this.loadingPromise;
    } finally {
      this.loadingPromise = null;
    }
  }

  /**
   * Actual health check.
   */
  private async checkHealth(): Promise<void> {
    try {
      console.log(
        '🔬 Checking Krishi Rakshak model API...'
      );

      const response = await fetch(
        `${this.apiUrl}/api/health`,
        {
          method: 'GET',
          signal: this.createTimeoutSignal(),
          headers: {
            Accept: 'application/json',
          },
        }
      );

      if (!response.ok) {
        throw new Error(
          `Model API returned ${response.status}`
        );
      }

      const data: HealthResponse =
        await response.json();

      if (data.status !== 'healthy') {
        throw new Error(
          'Model API is not healthy'
        );
      }

      this.modelReady = true;

      console.log(
        '✅ Krishi Rakshak model API ready'
      );

      if (data.classes !== undefined) {
        console.log(
          `🌱 Model classes: ${data.classes}`
        );
      }

    } catch (error) {
      this.modelReady = false;

      console.error(
        '❌ Model API connection failed:',
        error
      );

      throw new Error(
        'Crop disease model API is not available. Make sure api_server.py is running.'
      );
    }
  }

  /**
   * Check if model API is ready.
   */
  isLoaded(): boolean {
    return this.modelReady;
  }

  /**
   * Predict disease from image.
   */
  async predict(
    imageFile: File
  ): Promise<RealModelPrediction> {

    /*
     * If API isn't ready, check it now.
     *
     * This means normal page loading does NOT
     * have to wait for the model.
     */
    if (!this.modelReady) {
      await this.loadModel();
    }

    try {
      const formData = new FormData();

      formData.append(
        'image',
        imageFile
      );

      console.log(
        '📤 Sending crop image to ML model...'
      );

      const response = await fetch(
        `${this.apiUrl}/api/predict`,
        {
          method: 'POST',
          body: formData,
          signal: this.createTimeoutSignal(),
        }
      );

      if (!response.ok) {
        throw new Error(
          `Prediction API error: ${response.status} ${response.statusText}`
        );
      }

      const data: PredictionResponse =
        await response.json();

      if (!data.success) {
        throw new Error(
          data.error ||
            'Prediction failed'
        );
      }

      if (!data.prediction) {
        throw new Error(
          'Prediction data missing from API response'
        );
      }

      console.log(
        '✅ Prediction received:',
        data.prediction.disease
      );

      return {
        disease:
          data.prediction.disease,

        crop:
          data.prediction.crop,

        confidence:
          data.prediction.confidence,

        isHealthy:
          data.prediction.isHealthy,

        topPredictions:
          data.prediction.topPredictions,
      };

    } catch (error) {

      console.error(
        '❌ Crop prediction error:',
        error
      );

      throw error;
    }
  }

  /**
   * Get available disease/crop classes.
   */
  async getClasses(): Promise<any[]> {
    try {

      const response = await fetch(
        `${this.apiUrl}/api/classes`,
        {
          method: 'GET',
          signal: this.createTimeoutSignal(),
          headers: {
            Accept: 'application/json',
          },
        }
      );

      if (!response.ok) {
        throw new Error(
          `Classes API error: ${response.status}`
        );
      }

      const data = await response.json();

      return Array.isArray(data.classes)
        ? data.classes
        : [];

    } catch (error) {

      console.error(
        '❌ Error fetching classes:',
        error
      );

      return [];
    }
  }

  /**
   * Reset connection status.
   *
   * Useful if Python backend is restarted.
   */
  unload(): void {
    this.modelReady = false;
    this.loadingPromise = null;

    console.log(
      '🔌 Model API status reset'
    );
  }

  /**
   * Get backend URL.
   */
  getApiUrl(): string {
    return this.apiUrl;
  }
}

/**
 * Export one shared instance.
 */
export const realModelService =
  new RealModelService();