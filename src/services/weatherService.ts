import axios from 'axios';

// Open-Meteo Weather API (100% FREE, No API key needed, Unlimited requests!)
// Documentation: https://open-meteo.com/en/docs
// No signup required - completely free and open-source
const WEATHER_API_URL = 'https://api.open-meteo.com/v1';
const GEOCODING_API_URL = 'https://geocoding-api.open-meteo.com/v1';

export interface WeatherData {
  temp: number;
  feelsLike: number;
  condition: string;
  description: string;
  humidity: number;
  windSpeed: number;
  rainfall: number;
  pressure: number;
  visibility: number;
  icon: string;
  location: string;
  country: string;
  sunrise: number;
  sunset: number;
  clouds: number;
  uvIndex?: number;
}

export interface ForecastDay {
  date: string;
  temp: number;
  tempMin: number;
  tempMax: number;
  condition: string;
  icon: string;
  humidity: number;
  rainfall: number;
}

export interface LocationCoords {
  lat: number;
  lon: number;
}

// Get user's current location using browser geolocation
export const getUserLocation = (): Promise<LocationCoords> => {
  return new Promise((resolve, reject) => {
    if (!navigator.geolocation) {
      reject(new Error('Geolocation is not supported by your browser'));
      return;
    }

    navigator.geolocation.getCurrentPosition(
      (position) => {
        resolve({
          lat: position.coords.latitude,
          lon: position.coords.longitude,
        });
      },
      (error) => {
        console.error('Geolocation error:', error);
        // Fallback to default location (Delhi, India)
        resolve({
          lat: 28.6139,
          lon: 77.2090,
        });
      },
      {
        enableHighAccuracy: true,
        timeout: 5000,
        maximumAge: 0,
      }
    );
  });
};

// Map Open-Meteo weather codes to conditions
const getWeatherCondition = (code: number): { condition: string; description: string; icon: string } => {
  const weatherMap: { [key: number]: { condition: string; description: string; icon: string } } = {
    0: { condition: 'Clear', description: 'clear sky', icon: '01d' },
    1: { condition: 'Clear', description: 'mainly clear', icon: '01d' },
    2: { condition: 'Clouds', description: 'partly cloudy', icon: '02d' },
    3: { condition: 'Clouds', description: 'overcast', icon: '03d' },
    45: { condition: 'Mist', description: 'foggy', icon: '50d' },
    48: { condition: 'Mist', description: 'depositing rime fog', icon: '50d' },
    51: { condition: 'Drizzle', description: 'light drizzle', icon: '09d' },
    53: { condition: 'Drizzle', description: 'moderate drizzle', icon: '09d' },
    55: { condition: 'Drizzle', description: 'dense drizzle', icon: '09d' },
    61: { condition: 'Rain', description: 'slight rain', icon: '10d' },
    63: { condition: 'Rain', description: 'moderate rain', icon: '10d' },
    65: { condition: 'Rain', description: 'heavy rain', icon: '10d' },
    71: { condition: 'Snow', description: 'slight snow', icon: '13d' },
    73: { condition: 'Snow', description: 'moderate snow', icon: '13d' },
    75: { condition: 'Snow', description: 'heavy snow', icon: '13d' },
    77: { condition: 'Snow', description: 'snow grains', icon: '13d' },
    80: { condition: 'Rain', description: 'slight rain showers', icon: '09d' },
    81: { condition: 'Rain', description: 'moderate rain showers', icon: '09d' },
    82: { condition: 'Rain', description: 'violent rain showers', icon: '09d' },
    85: { condition: 'Snow', description: 'slight snow showers', icon: '13d' },
    86: { condition: 'Snow', description: 'heavy snow showers', icon: '13d' },
    95: { condition: 'Thunderstorm', description: 'thunderstorm', icon: '11d' },
    96: { condition: 'Thunderstorm', description: 'thunderstorm with hail', icon: '11d' },
    99: { condition: 'Thunderstorm', description: 'thunderstorm with heavy hail', icon: '11d' },
  };
  
  return weatherMap[code] || { condition: 'Clear', description: 'clear sky', icon: '01d' };
};

// Get current weather by coordinates
export const getCurrentWeather = async (coords: LocationCoords): Promise<WeatherData> => {
  try {
    // Get location name first
    const locationName = await getLocationName(coords);
    
    // Fetch weather data from Open-Meteo (FREE, no API key!)
    const response = await axios.get(`${WEATHER_API_URL}/forecast`, {
      params: {
        latitude: coords.lat,
        longitude: coords.lon,
        current: 'temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,cloud_cover,pressure_msl,wind_speed_10m',
        timezone: 'auto',
      },
    });

    const data = response.data.current;
    const weatherCode = data.weather_code;
    
    // Map weather codes to conditions
    const weatherCondition = getWeatherCondition(weatherCode);
    
    return {
      temp: Math.round(data.temperature_2m),
      feelsLike: Math.round(data.apparent_temperature),
      condition: weatherCondition.condition,
      description: weatherCondition.description,
      humidity: data.relative_humidity_2m,
      windSpeed: Math.round(data.wind_speed_10m * 3.6), // Convert m/s to km/h
      rainfall: data.precipitation || 0,
      pressure: Math.round(data.pressure_msl),
      visibility: 10, // Open-Meteo doesn't provide visibility, use default
      icon: weatherCondition.icon,
      location: locationName.split(',')[0].trim(),
      country: locationName.split(',')[1]?.trim() || '',
      sunrise: Date.now() / 1000,
      sunset: Date.now() / 1000,
      clouds: data.cloud_cover,
    };
  } catch (error: any) {
    console.error('Weather API Error:', error);
    
    // Return fallback data if API fails
    return {
      temp: 28,
      feelsLike: 30,
      condition: 'Clear',
      description: 'clear sky',
      humidity: 65,
      windSpeed: 12,
      rainfall: 0,
      pressure: 1013,
      visibility: 10,
      icon: '01d',
      location: 'Your Location',
      country: 'IN',
      sunrise: Date.now() / 1000,
      sunset: Date.now() / 1000,
      clouds: 20,
    };
  }
};

// Get 5-day weather forecast
export const getWeatherForecast = async (coords: LocationCoords): Promise<ForecastDay[]> => {
  try {
    const response = await axios.get(`${WEATHER_API_URL}/forecast`, {
      params: {
        latitude: coords.lat,
        longitude: coords.lon,
        daily: 'temperature_2m_max,temperature_2m_min,weather_code,precipitation_sum,relative_humidity_2m_mean',
        timezone: 'auto',
        forecast_days: 5,
      },
    });

    const forecast: ForecastDay[] = [];
    const daily = response.data.daily;

    for (let i = 0; i < 5; i++) {
      const weatherCode = daily.weather_code[i];
      const weatherCondition = getWeatherCondition(weatherCode);
      
      forecast.push({
        date: new Date(daily.time[i]).toLocaleDateString(),
        temp: Math.round((daily.temperature_2m_max[i] + daily.temperature_2m_min[i]) / 2),
        tempMin: Math.round(daily.temperature_2m_min[i]),
        tempMax: Math.round(daily.temperature_2m_max[i]),
        condition: weatherCondition.condition,
        icon: weatherCondition.icon,
        humidity: Math.round(daily.relative_humidity_2m_mean[i]),
        rainfall: Math.round(daily.precipitation_sum[i]),
      });
    }

    return forecast;
  } catch (error) {
    console.error('Forecast API Error:', error);
    return [];
  }
};

// Get weather-based farming advice
export const getWeatherAdviceForFarming = (weather: WeatherData): string[] => {
  const advice: string[] = [];

  // Temperature-based advice
  if (weather.temp > 35) {
    advice.push('🌡️ High temperature alert! Ensure adequate irrigation and avoid mid-day fieldwork.');
  } else if (weather.temp < 15) {
    advice.push('❄️ Cool weather! Consider frost protection for sensitive crops.');
  }

  // Rainfall advice
  if (weather.rainfall > 5) {
    advice.push('🌧️ Heavy rain expected! Ensure proper drainage and postpone fertilizer application.');
  } else if (weather.rainfall > 0) {
    advice.push('🌦️ Light rain expected. Good time for transplanting and sowing.');
  }

  // Humidity advice
  if (weather.humidity > 80) {
    advice.push('💧 High humidity! Monitor for fungal diseases and apply preventive fungicides.');
  } else if (weather.humidity < 40) {
    advice.push('🏜️ Low humidity. Increase irrigation frequency to prevent water stress.');
  }

  // Wind advice
  if (weather.windSpeed > 30) {
    advice.push('💨 Strong winds expected! Provide support to tall crops and avoid spraying.');
  }

  // Cloud cover advice
  if (weather.clouds > 70) {
    advice.push('☁️ Cloudy weather. Good for transplanting but may delay drying of harvested crops.');
  } else if (weather.clouds < 20) {
    advice.push('☀️ Clear skies. Ideal for harvesting and drying crops.');
  }

  // Default advice if no alerts
  if (advice.length === 0) {
    advice.push('✅ Weather conditions are favorable for normal farming activities.');
  }

  return advice;
};

// Get location name from coordinates (reverse geocoding)
export const getLocationName = async (coords: LocationCoords): Promise<string> => {
  try {
    const response = await axios.get(`${GEOCODING_API_URL}/reverse`, {
      params: {
        latitude: coords.lat,
        longitude: coords.lon,
        count: 1,
      },
    });
    
    if (response.data.results && response.data.results.length > 0) {
      const result = response.data.results[0];
      const city = result.name || result.admin3 || result.admin2 || result.admin1;
      const country = result.country_code?.toUpperCase() || '';
      return `${city}, ${country}`;
    }
    
    return 'Your Location';
  } catch (error) {
    console.error('Geocoding error:', error);
    return 'Your Location';
  }
};