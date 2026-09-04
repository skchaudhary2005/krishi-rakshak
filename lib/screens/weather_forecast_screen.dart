import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../language.dart';

class WeatherForecastScreen extends StatefulWidget {
  const WeatherForecastScreen({super.key});

  // Dashboard uses this without creating a screen instance.
  static String text(String language, String key) {
    return _WeatherI18n.value(language, key);
  }

  @override
  State<WeatherForecastScreen> createState() => _WeatherForecastScreenState();
}

class _WeatherForecastScreenState extends State<WeatherForecastScreen> {
  static const String _savedCityKey = 'weather_saved_city';
  static const String _savedLatitudeKey = 'weather_saved_latitude';
  static const String _savedLongitudeKey = 'weather_saved_longitude';
  static const String _savedCountryKey = 'weather_saved_country';

  static const Duration _networkTimeout = Duration(seconds: 12);

  final TextEditingController _cityController = TextEditingController();

  bool _loading = false;
  String _error = '';
  String _city = '';
  String _country = '';
  double? _latitude;
  double? _longitude;
  Map<String, dynamic>? _weather;

  String get _language => LanguageScope.of(context).value;

  @override
  void initState() {
    super.initState();
    _restoreLastLocation();
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _restoreLastLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final city = prefs.getString(_savedCityKey);
      final country = prefs.getString(_savedCountryKey);
      final latitude = prefs.getDouble(_savedLatitudeKey);
      final longitude = prefs.getDouble(_savedLongitudeKey);

      if (!mounted) return;

      if (city != null &&
          city.trim().isNotEmpty &&
          latitude != null &&
          longitude != null) {
        setState(() {
          _city = city;
          _country = country ?? '';
          _latitude = latitude;
          _longitude = longitude;
        });
        await _loadWeather();
      }
    } catch (e) {
      debugPrint('WEATHER RESTORE ERROR: $e');
    }
  }

  Future<void> _searchCity() async {
    final query = _cityController.text.trim();

    if (query.length < 2) {
      _showMessage(_WeatherI18n.value(_language, 'enterCity'));
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final result = await _geocodeWithFallback(query);

      final latitude = _asDouble(result['latitude']);
      final longitude = _asDouble(result['longitude']);
      final name = result['name']?.toString().trim() ?? query;
      final country = result['country']?.toString().trim() ?? '';

      if (latitude == null ||
          longitude == null ||
          !latitude.isFinite ||
          !longitude.isFinite) {
        throw Exception('Location coordinates are unavailable');
      }

      await _saveLocation(
        city: name,
        country: country,
        latitude: latitude,
        longitude: longitude,
      );

      if (!mounted) return;

      setState(() {
        _city = name;
        _country = country;
        _latitude = latitude;
        _longitude = longitude;
      });

      await _loadWeather();
    } catch (e) {
      debugPrint('WEATHER LOCATION ERROR: $e');

      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = _WeatherI18n.value(_language, 'locationSearchError');
      });
    }
  }

  Future<Map<String, dynamic>> _geocodeWithFallback(String query) async {
    Exception? firstError;

    // Primary: Open-Meteo geocoding.
    try {
      final uri = Uri.https(
        'geocoding-api.open-meteo.com',
        '/v1/search',
        <String, String>{
          'name': query,
          'count': '5',
          'language': 'en',
          'format': 'json',
        },
      );

      final response = await http.get(
        uri,
        headers: const {'Accept': 'application/json'},
      ).timeout(_networkTimeout);

      debugPrint('WEATHER OPEN_METEO LOCATION HTTP: ${response.statusCode}');
      debugPrint('WEATHER OPEN_METEO LOCATION RESPONSE: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['results'] is List) {
          final results = decoded['results'] as List;
          for (final item in results) {
            if (item is Map) {
              final map = Map<String, dynamic>.from(item);
              final lat = _asDouble(map['latitude']);
              final lon = _asDouble(map['longitude']);
              if (lat != null && lon != null && lat.isFinite && lon.isFinite) {
                return map;
              }
            }
          }
        }

        final reason = decoded is Map
            ? (decoded['reason'] ?? decoded['message'])?.toString()
            : null;
        firstError = Exception(
          reason == null || reason.trim().isEmpty
              ? 'Open-Meteo returned no usable location'
              : reason,
        );
      } else {
        firstError = Exception(
          'Open-Meteo location HTTP ${response.statusCode}',
        );
      }
    } catch (e) {
      firstError = Exception(e.toString());
      debugPrint('WEATHER OPEN_METEO LOCATION ERROR: $e');
    }

    // Fallback: Nominatim. This handles cases where Open-Meteo geocoding
    // returns an unexpected response while the weather API itself is fine.
    try {
      final uri = Uri.https(
        'nominatim.openstreetmap.org',
        '/search',
        <String, String>{
          'q': '$query, India',
          'format': 'jsonv2',
          'limit': '5',
          'countrycodes': 'in',
          'addressdetails': '1',
        },
      );

      final response = await http.get(
        uri,
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'KrishiRakshak/1.0 agriculture-weather-app',
        },
      ).timeout(_networkTimeout);

      debugPrint('WEATHER NOMINATIM HTTP: ${response.statusCode}');
      debugPrint('WEATHER NOMINATIM RESPONSE: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              final map = Map<String, dynamic>.from(item);
              final lat = _asDouble(map['lat']);
              final lon = _asDouble(map['lon']);

              if (lat != null && lon != null && lat.isFinite && lon.isFinite) {
                final address = map['address'] is Map
                    ? Map<String, dynamic>.from(map['address'] as Map)
                    : <String, dynamic>{};

                final displayName = map['name']?.toString().trim();
                final fallbackName = (displayName == null || displayName.isEmpty)
                    ? (address['village'] ??
                            address['town'] ??
                            address['city'] ??
                            address['municipality'] ??
                            query)
                        .toString()
                    : displayName;

                return <String, dynamic>{
                  'latitude': lat,
                  'longitude': lon,
                  'name': fallbackName,
                  'country':
                      address['country']?.toString().trim() ?? 'India',
                };
              }
            }
          }
        }
      } else {
        debugPrint(
          'WEATHER NOMINATIM HTTP ERROR: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('WEATHER NOMINATIM ERROR: $e');
    }

    throw firstError ?? Exception('Location not found');
  }

  Future<void> _saveLocation({
    required String city,
    required String country,
    required double latitude,
    required double longitude,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_savedCityKey, city);
    await prefs.setString(_savedCountryKey, country);
    await prefs.setDouble(_savedLatitudeKey, latitude);
    await prefs.setDouble(_savedLongitudeKey, longitude);
  }

  Future<void> _loadWeather() async {
    final latitude = _latitude;
    final longitude = _longitude;

    if (latitude == null || longitude == null) return;

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final uri = Uri.https(
        'api.open-meteo.com',
        '/v1/forecast',
        <String, String>{
          'latitude': latitude.toString(),
          'longitude': longitude.toString(),
          'current':
              'temperature_2m,relative_humidity_2m,apparent_temperature,'
              'precipitation,rain,weather_code,cloud_cover,wind_speed_10m',
          'daily':
              'weather_code,temperature_2m_max,temperature_2m_min,'
              'precipitation_probability_max,precipitation_sum,'
              'wind_speed_10m_max,sunrise,sunset',
          'forecast_days': '7',
          'timezone': 'auto',
          'temperature_unit': 'celsius',
          'wind_speed_unit': 'kmh',
          'precipitation_unit': 'mm',
        },
      );

      final response = await http.get(uri).timeout(_networkTimeout);

      if (response.statusCode != 200) {
        throw Exception('Weather HTTP ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map ||
          decoded['current'] is! Map ||
          decoded['daily'] is! Map) {
        throw Exception('Invalid weather response');
      }

      final current = Map<String, dynamic>.from(decoded['current'] as Map);
      final daily = Map<String, dynamic>.from(decoded['daily'] as Map);

      final currentTime = current['time']?.toString() ?? '';
      final dailyTimes = _stringList(daily['time']);

      if (currentTime.isEmpty || dailyTimes.isEmpty) {
        throw Exception('Weather data is incomplete');
      }

      final safeData = <String, dynamic>{
        'current': current,
        'daily': daily,
        'timezone': decoded['timezone']?.toString() ?? '',
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (!mounted) return;

      setState(() {
        _weather = safeData;
        _loading = false;
        _error = '';
      });
    } catch (e) {
      debugPrint('WEATHER LOAD ERROR: $e');

      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = _WeatherI18n.value(_language, 'networkError');
      });
    }
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) return <String>[];
    return value.map((e) => e.toString()).toList();
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  String _currentValue(String key) {
    final current = _weather?['current'];
    if (current is! Map) return '--';
    return current[key]?.toString() ?? '--';
  }

  String _dailyValue(String key, int index) {
    final daily = _weather?['daily'];
    if (daily is! Map) return '--';

    final value = daily[key];
    if (value is! List || index >= value.length) return '--';

    return value[index]?.toString() ?? '--';
  }

  int _weatherCode() {
    return int.tryParse(_currentValue('weather_code')) ?? -1;
  }

  String _condition(int code) {
    return _WeatherI18n.condition(_language, code);
  }

  IconData _weatherIcon(int code) {
    if (code == 0) return Icons.wb_sunny_rounded;
    if (code == 1 || code == 2) return Icons.cloud_queue_rounded;
    if (code == 3) return Icons.cloud_rounded;
    if (code >= 45 && code <= 48) return Icons.foggy;
    if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
      return Icons.grain_rounded;
    }
    if (code >= 71 && code <= 77) return Icons.ac_unit_rounded;
    if (code >= 85 && code <= 86) return Icons.ac_unit_rounded;
    if (code >= 95) return Icons.thunderstorm_rounded;
    return Icons.cloud_queue_rounded;
  }

  String _formatDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;

    const months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    return '${parsed.day} ${months[parsed.month - 1]}';
  }

  String _formatTime(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;

    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final code = _weatherCode();

    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF2),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        title: Text(_WeatherI18n.value(_language, 'title')),
        actions: [
          IconButton(
            tooltip: _WeatherI18n.value(_language, 'refresh'),
            onPressed: _loading || _latitude == null ? null : _loadWeather,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (_latitude != null) {
            await _loadWeather();
          }
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _buildLocationSearch(),
            const SizedBox(height: 14),
            if (_error.isNotEmpty) _buildError(),
            if (_weather == null && !_loading && _error.isEmpty)
              _buildEmptyState(),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 35),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_weather != null) ...[
              _buildCurrentWeather(code),
              const SizedBox(height: 14),
              _buildAgricultureSummary(code),
              const SizedBox(height: 14),
              _buildForecast(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSearch() {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _WeatherI18n.value(_language, 'location'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B5E20),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cityController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _searchCity(),
                    decoration: InputDecoration(
                      hintText: _WeatherI18n.value(_language, 'cityHint'),
                      prefixIcon: const Icon(Icons.location_on_outlined),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: _WeatherI18n.value(_language, 'search'),
                  onPressed: _loading ? null : _searchCity,
                  icon: const Icon(Icons.search_rounded),
                ),
              ],
            ),
            if (_city.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.place_rounded,
                    size: 18,
                    color: Color(0xFF2E7D32),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      _country.isEmpty ? _city : '$_city, $_country',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentWeather(int code) {
    final temperature = _currentValue('temperature_2m');
    final feelsLike = _currentValue('apparent_temperature');
    final humidity = _currentValue('relative_humidity_2m');
    final wind = _currentValue('wind_speed_10m');
    final rain = _currentValue('rain');
    final cloud = _currentValue('cloud_cover');

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              _weatherIcon(code),
              size: 64,
              color: const Color(0xFF1565C0),
            ),
            const SizedBox(height: 8),
            Text(
              _condition(code),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B5E20),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$temperature °C',
              style: const TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${_WeatherI18n.value(_language, 'feelsLike')}: $feelsLike °C',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _metric(
                    Icons.water_drop_outlined,
                    '$humidity%',
                    _WeatherI18n.value(_language, 'humidity'),
                  ),
                ),
                Expanded(
                  child: _metric(
                    Icons.air_rounded,
                    '$wind km/h',
                    _WeatherI18n.value(_language, 'wind'),
                  ),
                ),
                Expanded(
                  child: _metric(
                    Icons.water_drop_rounded,
                    '$rain mm',
                    _WeatherI18n.value(_language, 'rain'),
                  ),
                ),
                Expanded(
                  child: _metric(
                    Icons.cloud_outlined,
                    '$cloud%',
                    _WeatherI18n.value(_language, 'cloud'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF2E7D32)),
        const SizedBox(height: 5),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildAgricultureSummary(int code) {
    final rainProbability = _dailyValue('precipitation_probability_max', 0);
    final maxTemp = _dailyValue('temperature_2m_max', 0);
    final minTemp = _dailyValue('temperature_2m_min', 0);

    final message = _WeatherI18n.agricultureMessage(
      _language,
      code,
      maxTemp,
      minTemp,
      rainProbability,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.agriculture_rounded,
              color: Color(0xFF2E7D32),
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _WeatherI18n.value(_language, 'farmTip'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    message,
                    style: const TextStyle(height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForecast() {
    final dates = _weather?['daily']?['time'];
    if (dates is! List || dates.isEmpty) {
      return const SizedBox.shrink();
    }

    final count = dates.length > 7 ? 7 : dates.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                _WeatherI18n.value(_language, 'sevenDay'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B5E20),
                ),
              ),
            ),
            const SizedBox(height: 10),
            ...List.generate(count, (index) {
              final date = dates[index].toString();
              final code =
                  int.tryParse(_dailyValue('weather_code', index)) ?? -1;
              final max = _dailyValue('temperature_2m_max', index);
              final min = _dailyValue('temperature_2m_min', index);
              final rain =
                  _dailyValue('precipitation_probability_max', index);
              final rainTotal = _dailyValue('precipitation_sum', index);
              final wind = _dailyValue('wind_speed_10m_max', index);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7FBF6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE0EEDD),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 62,
                      child: Text(
                        index == 0
                            ? _WeatherI18n.value(_language, 'today')
                            : _formatDate(date),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(
                      _weatherIcon(code),
                      color: const Color(0xFF1565C0),
                      size: 27,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _condition(code),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_WeatherI18n.value(_language, 'rainChance')}: $rain%  •  ${_WeatherI18n.value(_language, 'rainTotal')}: $rainTotal mm',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 5),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$max° / $min°',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '$wind km/h',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 3),
            _buildSunInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildSunInfo() {
    final sunrise = _dailyValue('sunrise', 0);
    final sunset = _dailyValue('sunset', 0);

    return Row(
      children: [
        Expanded(
          child: _sunInfo(
            Icons.wb_twilight_rounded,
            _WeatherI18n.value(_language, 'sunrise'),
            _formatTime(sunrise),
          ),
        ),
        Expanded(
          child: _sunInfo(
            Icons.nightlight_round,
            _WeatherI18n.value(_language, 'sunset'),
            _formatTime(sunset),
          ),
        ),
      ],
    );
  }

  Widget _sunInfo(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 21, color: const Color(0xFF2E7D32)),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black54,
              ),
            ),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildError() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: Colors.orange,
              size: 28,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _error,
                style: const TextStyle(height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            const Icon(
              Icons.cloud_rounded,
              size: 70,
              color: Color(0xFF90CAF9),
            ),
            const SizedBox(height: 12),
            Text(
              _WeatherI18n.value(_language, 'chooseLocation'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              _WeatherI18n.value(_language, 'chooseLocationSub'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black54,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeatherI18n {
  static const Map<String, Map<String, String>> _strings = {
    'en': {
      'title': 'Weather Forecast',
      'subtitle': 'Current weather and 7-day forecast',
      'location': 'Farm Location',
      'cityHint': 'Enter village, town or city',
      'search': 'Search',
      'refresh': 'Refresh weather',
      'enterCity': 'Enter a location name.',
      'networkError': 'Weather could not be loaded. Check your internet connection and try again.',
      'locationSearchError': 'Location could not be found. Try the village/town/city name again.',
      'feelsLike': 'Feels like',
      'humidity': 'Humidity',
      'wind': 'Wind',
      'rain': 'Rain',
      'cloud': 'Cloud',
      'farmTip': 'Farming weather tip',
      'sevenDay': '7-Day Forecast',
      'today': 'Today',
      'rainChance': 'Rain chance',
      'rainTotal': 'Rain',
      'sunrise': 'Sunrise',
      'sunset': 'Sunset',
      'chooseLocation': 'Choose your farm location',
      'chooseLocationSub': 'Search for your village, town or city to see local weather and the 7-day forecast.',
    },
    'hi': {
      'title': 'मौसम पूर्वानुमान',
      'subtitle': 'वर्तमान मौसम और 7 दिन का पूर्वानुमान',
      'location': 'खेत का स्थान',
      'cityHint': 'गाँव, कस्बा या शहर लिखें',
      'search': 'खोजें',
      'refresh': 'मौसम रीफ्रेश करें',
      'enterCity': 'स्थान का नाम लिखें।',
      'networkError': 'मौसम की जानकारी नहीं मिल सकी। इंटरनेट जाँचकर फिर कोशिश करें।',
      'locationSearchError': 'स्थान नहीं मिला। गाँव, कस्बे या शहर का नाम फिर से लिखें।',
      'feelsLike': 'महसूस तापमान',
      'humidity': 'नमी',
      'wind': 'हवा',
      'rain': 'बारिश',
      'cloud': 'बादल',
      'farmTip': 'खेती के लिए मौसम सलाह',
      'sevenDay': '7 दिन का पूर्वानुमान',
      'today': 'आज',
      'rainChance': 'बारिश की संभावना',
      'rainTotal': 'बारिश',
      'sunrise': 'सूर्योदय',
      'sunset': 'सूर्यास्त',
      'chooseLocation': 'अपने खेत का स्थान चुनें',
      'chooseLocationSub': 'अपने गाँव, कस्बे या शहर का नाम खोजें और स्थानीय मौसम देखें।',
    },
    'pa': {
      'title': 'ਮੌਸਮ ਦੀ ਭਵਿੱਖਬਾਣੀ',
      'subtitle': 'ਮੌਜੂਦਾ ਮੌਸਮ ਅਤੇ 7 ਦਿਨਾਂ ਦੀ ਭਵਿੱਖਬਾਣੀ',
      'location': 'ਖੇਤ ਦਾ ਸਥਾਨ',
      'cityHint': 'ਪਿੰਡ, ਕਸਬਾ ਜਾਂ ਸ਼ਹਿਰ ਲਿਖੋ',
      'search': 'ਖੋਜੋ',
      'refresh': 'ਮੌਸਮ ਤਾਜ਼ਾ ਕਰੋ',
      'enterCity': 'ਸਥਾਨ ਦਾ ਨਾਮ ਲਿਖੋ।',
      'networkError': 'ਮੌਸਮ ਦੀ ਜਾਣਕਾਰੀ ਨਹੀਂ ਮਿਲੀ। ਇੰਟਰਨੈੱਟ ਜਾਂਚ ਕੇ ਦੁਬਾਰਾ ਕੋਸ਼ਿਸ਼ ਕਰੋ।',
      'feelsLike': 'ਮਹਿਸੂਸ ਤਾਪਮਾਨ',
      'humidity': 'ਨਮੀ',
      'wind': 'ਹਵਾ',
      'rain': 'ਮੀਂਹ',
      'cloud': 'ਬੱਦਲ',
      'farmTip': 'ਖੇਤੀ ਲਈ ਮੌਸਮ ਸਲਾਹ',
      'sevenDay': '7 ਦਿਨਾਂ ਦੀ ਭਵਿੱਖਬਾਣੀ',
      'today': 'ਅੱਜ',
      'rainChance': 'ਮੀਂਹ ਦੀ ਸੰਭਾਵਨਾ',
      'rainTotal': 'ਮੀਂਹ',
      'sunrise': 'ਸੂਰਜ ਚੜ੍ਹਨਾ',
      'sunset': 'ਸੂਰਜ ਡੁੱਬਣਾ',
      'chooseLocation': 'ਆਪਣੇ ਖੇਤ ਦਾ ਸਥਾਨ ਚੁਣੋ',
      'chooseLocationSub': 'ਆਪਣੇ ਪਿੰਡ, ਕਸਬੇ ਜਾਂ ਸ਼ਹਿਰ ਨੂੰ ਖੋਜੋ ਅਤੇ ਸਥਾਨਕ ਮੌਸਮ ਵੇਖੋ।',
    },
    'mr': {
      'title': 'हवामान अंदाज',
      'subtitle': 'सध्याचे हवामान आणि 7 दिवसांचा अंदाज',
      'location': 'शेताचे ठिकाण',
      'cityHint': 'गाव, तालुका किंवा शहर लिहा',
      'search': 'शोधा',
      'refresh': 'हवामान ताजे करा',
      'enterCity': 'ठिकाणाचे नाव लिहा.',
      'networkError': 'हवामानाची माहिती मिळाली नाही. इंटरनेट तपासून पुन्हा प्रयत्न करा.',
      'feelsLike': 'जाणवणारे तापमान',
      'humidity': 'आर्द्रता',
      'wind': 'वारा',
      'rain': 'पाऊस',
      'cloud': 'ढग',
      'farmTip': 'शेतीसाठी हवामान सल्ला',
      'sevenDay': '7 दिवसांचा अंदाज',
      'today': 'आज',
      'rainChance': 'पावसाची शक्यता',
      'rainTotal': 'पाऊस',
      'sunrise': 'सूर्योदय',
      'sunset': 'सूर्यास्त',
      'chooseLocation': 'तुमच्या शेताचे ठिकाण निवडा',
      'chooseLocationSub': 'गाव, तालुका किंवा शहर शोधा आणि स्थानिक हवामान पहा.',
    },
    'bn': {
      'title': 'আবহাওয়ার পূর্বাভাস',
      'subtitle': 'বর্তমান আবহাওয়া ও ৭ দিনের পূর্বাভাস',
      'location': 'খেতের অবস্থান',
      'cityHint': 'গ্রাম, শহর বা নগরের নাম লিখুন',
      'search': 'খুঁজুন',
      'refresh': 'আবহাওয়া রিফ্রেশ করুন',
      'enterCity': 'স্থানের নাম লিখুন।',
      'networkError': 'আবহাওয়ার তথ্য পাওয়া যায়নি। ইন্টারনেট পরীক্ষা করে আবার চেষ্টা করুন।',
      'feelsLike': 'অনুভূত তাপমাত্রা',
      'humidity': 'আর্দ্রতা',
      'wind': 'বাতাস',
      'rain': 'বৃষ্টি',
      'cloud': 'মেঘ',
      'farmTip': 'কৃষির জন্য আবহাওয়া পরামর্শ',
      'sevenDay': '৭ দিনের পূর্বাভাস',
      'today': 'আজ',
      'rainChance': 'বৃষ্টির সম্ভাবনা',
      'rainTotal': 'বৃষ্টি',
      'sunrise': 'সূর্যোদয়',
      'sunset': 'সূর্যাস্ত',
      'chooseLocation': 'আপনার খেতের অবস্থান বেছে নিন',
      'chooseLocationSub': 'গ্রাম বা শহরের নাম খুঁজে স্থানীয় আবহাওয়া দেখুন।',
    },
    'gu': {
      'title': 'હવામાન આગાહી',
      'subtitle': 'વર્તમાન હવામાન અને 7 દિવસની આગાહી',
      'location': 'ખેતરનું સ્થળ',
      'cityHint': 'ગામ, નગર અથવા શહેર લખો',
      'search': 'શોધો',
      'refresh': 'હવામાન રિફ્રેશ કરો',
      'enterCity': 'સ્થળનું નામ લખો.',
      'networkError': 'હવામાનની માહિતી મળી નથી. ઇન્ટરનેટ તપાસીને ફરી પ્રયાસ કરો.',
      'feelsLike': 'અનુભવાતું તાપમાન',
      'humidity': 'ભેજ',
      'wind': 'પવન',
      'rain': 'વરસાદ',
      'cloud': 'વાદળ',
      'farmTip': 'ખેતી માટે હવામાન સલાહ',
      'sevenDay': '7 દિવસની આગાહી',
      'today': 'આજે',
      'rainChance': 'વરસાદની શક્યતા',
      'rainTotal': 'વરસાદ',
      'sunrise': 'સૂર્યોદય',
      'sunset': 'સૂર્યાસ્ત',
      'chooseLocation': 'તમારા ખેતરનું સ્થળ પસંદ કરો',
      'chooseLocationSub': 'તમારા ગામ અથવા શહેરનું નામ શોધો અને સ્થાનિક હવામાન જુઓ.',
    },
    'ta': {
      'title': 'வானிலை முன்னறிவிப்பு',
      'subtitle': 'தற்போதைய வானிலை மற்றும் 7 நாள் முன்னறிவிப்பு',
      'location': 'வயல் இடம்',
      'cityHint': 'கிராமம், நகரம் அல்லது ஊர் பெயரை உள்ளிடவும்',
      'search': 'தேடு',
      'refresh': 'வானிலையைப் புதுப்பிக்கவும்',
      'enterCity': 'இடத்தின் பெயரை உள்ளிடவும்.',
      'networkError': 'வானிலை தகவலைப் பெற முடியவில்லை. இணையத்தைச் சரிபார்த்து மீண்டும் முயற்சிக்கவும்.',
      'feelsLike': 'உணரப்படும் வெப்பநிலை',
      'humidity': 'ஈரப்பதம்',
      'wind': 'காற்று',
      'rain': 'மழை',
      'cloud': 'மேகம்',
      'farmTip': 'விவசாய வானிலை ஆலோசனை',
      'sevenDay': '7 நாள் முன்னறிவிப்பு',
      'today': 'இன்று',
      'rainChance': 'மழை வாய்ப்பு',
      'rainTotal': 'மழை',
      'sunrise': 'சூரிய உதயம்',
      'sunset': 'சூரிய அஸ்தமனம்',
      'chooseLocation': 'உங்கள் வயல் இடத்தைத் தேர்ந்தெடுக்கவும்',
      'chooseLocationSub': 'உங்கள் கிராமம் அல்லது நகரத்தைத் தேடி உள்ளூர் வானிலையைப் பார்க்கவும்.',
    },
    'te': {
      'title': 'వాతావరణ సూచన',
      'subtitle': 'ప్రస్తుత వాతావరణం మరియు 7 రోజుల సూచన',
      'location': 'పొలం ప్రాంతం',
      'cityHint': 'గ్రామం, పట్టణం లేదా నగరం పేరు నమోదు చేయండి',
      'search': 'వెతుకు',
      'refresh': 'వాతావరణాన్ని రిఫ్రెష్ చేయండి',
      'enterCity': 'ప్రాంతం పేరు నమోదు చేయండి.',
      'networkError': 'వాతావరణ సమాచారం అందలేదు. ఇంటర్నెట్ తనిఖీ చేసి మళ్లీ ప్రయత్నించండి.',
      'feelsLike': 'అనిపించే ఉష్ణోగ్రత',
      'humidity': 'తేమ',
      'wind': 'గాలి',
      'rain': 'వర్షం',
      'cloud': 'మేఘాలు',
      'farmTip': 'వ్యవసాయ వాతావరణ సూచన',
      'sevenDay': '7 రోజుల సూచన',
      'today': 'ఈ రోజు',
      'rainChance': 'వర్షం అవకాశం',
      'rainTotal': 'వర్షం',
      'sunrise': 'సూర్యోదయం',
      'sunset': 'సూర్యాస్తమయం',
      'chooseLocation': 'మీ పొలం ప్రాంతాన్ని ఎంచుకోండి',
      'chooseLocationSub': 'మీ గ్రామం లేదా నగరాన్ని వెతికి స్థానిక వాతావరణాన్ని చూడండి.',
    },
    'kn': {
      'title': 'ಹವಾಮಾನ ಮುನ್ಸೂಚನೆ',
      'subtitle': 'ಪ್ರಸ್ತುತ ಹವಾಮಾನ ಮತ್ತು 7 ದಿನಗಳ ಮುನ್ಸೂಚನೆ',
      'location': 'ಹೊಲದ ಸ್ಥಳ',
      'cityHint': 'ಗ್ರಾಮ, ಪಟ್ಟಣ ಅಥವಾ ನಗರದ ಹೆಸರು ನಮೂದಿಸಿ',
      'search': 'ಹುಡುಕಿ',
      'refresh': 'ಹವಾಮಾನ ರಿಫ್ರೆಶ್ ಮಾಡಿ',
      'enterCity': 'ಸ್ಥಳದ ಹೆಸರು ನಮೂದಿಸಿ.',
      'networkError': 'ಹವಾಮಾನ ಮಾಹಿತಿ ಲಭ್ಯವಾಗಲಿಲ್ಲ. ಇಂಟರ್ನೆಟ್ ಪರಿಶೀಲಿಸಿ ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.',
      'feelsLike': 'ಅನುಭವವಾಗುವ ತಾಪಮಾನ',
      'humidity': 'ಆರ್ದ್ರತೆ',
      'wind': 'ಗಾಳಿ',
      'rain': 'ಮಳೆ',
      'cloud': 'ಮೋಡ',
      'farmTip': 'ಕೃಷಿಗೆ ಹವಾಮಾನ ಸಲಹೆ',
      'sevenDay': '7 ದಿನಗಳ ಮುನ್ಸೂಚನೆ',
      'today': 'ಇಂದು',
      'rainChance': 'ಮಳೆಯ ಸಾಧ್ಯತೆ',
      'rainTotal': 'ಮಳೆ',
      'sunrise': 'ಸೂರ್ಯೋದಯ',
      'sunset': 'ಸೂರ್ಯಾಸ್ತ',
      'chooseLocation': 'ನಿಮ್ಮ ಹೊಲದ ಸ್ಥಳವನ್ನು ಆಯ್ಕೆಮಾಡಿ',
      'chooseLocationSub': 'ನಿಮ್ಮ ಗ್ರಾಮ ಅಥವಾ ನಗರವನ್ನು ಹುಡುಕಿ ಸ್ಥಳೀಯ ಹವಾಮಾನವನ್ನು ನೋಡಿ.',
    },
    'ml': {
      'title': 'കാലാവസ്ഥാ പ്രവചനം',
      'subtitle': 'നിലവിലെ കാലാവസ്ഥയും 7 ദിവസത്തെ പ്രവചനവും',
      'location': 'കൃഷിയിടത്തിന്റെ സ്ഥലം',
      'cityHint': 'ഗ്രാമം, പട്ടണം അല്ലെങ്കിൽ നഗരം നൽകുക',
      'search': 'തിരയുക',
      'refresh': 'കാലാവസ്ഥ പുതുക്കുക',
      'enterCity': 'സ്ഥലത്തിന്റെ പേര് നൽകുക.',
      'networkError': 'കാലാവസ്ഥാ വിവരം ലഭ്യമല്ല. ഇന്റർനെറ്റ് പരിശോധിച്ച് വീണ്ടും ശ്രമിക്കുക.',
      'feelsLike': 'അനുഭവപ്പെടുന്ന താപനില',
      'humidity': 'ഈർപ്പം',
      'wind': 'കാറ്റ്',
      'rain': 'മഴ',
      'cloud': 'മേഘം',
      'farmTip': 'കൃഷിക്കുള്ള കാലാവസ്ഥാ നിർദ്ദേശം',
      'sevenDay': '7 ദിവസത്തെ പ്രവചനം',
      'today': 'ഇന്ന്',
      'rainChance': 'മഴയ്ക്കുള്ള സാധ്യത',
      'rainTotal': 'മഴ',
      'sunrise': 'സൂര്യോദയം',
      'sunset': 'സൂര്യാസ്തമയം',
      'chooseLocation': 'നിങ്ങളുടെ കൃഷിയിടത്തിന്റെ സ്ഥലം തിരഞ്ഞെടുക്കുക',
      'chooseLocationSub': 'നിങ്ങളുടെ ഗ്രാമമോ നഗരമോ തിരഞ്ഞ് പ്രാദേശിക കാലാവസ്ഥ കാണുക.',
    },
  };

  static String value(String language, String key) {
    return _strings[language]?[key] ?? _strings['en']![key]!;
  }

  static String condition(String language, int code) {
    final key = switch (code) {
      0 => 'clear',
      1 => 'mainlyClear',
      2 => 'partlyCloudy',
      3 => 'overcast',
      45 || 48 => 'fog',
      51 || 53 || 55 => 'drizzle',
      56 || 57 => 'freezingDrizzle',
      61 || 63 || 65 => 'rain',
      66 || 67 => 'freezingRain',
      71 || 73 || 75 || 77 => 'snow',
      80 || 81 || 82 => 'showers',
      85 || 86 => 'snowShowers',
      95 => 'thunderstorm',
      96 || 99 => 'thunderstormHail',
      _ => 'weather',
    };

    final localized = <String, Map<String, String>>{
      'en': {
        'clear': 'Clear sky',
        'mainlyClear': 'Mainly clear',
        'partlyCloudy': 'Partly cloudy',
        'overcast': 'Overcast',
        'fog': 'Fog',
        'drizzle': 'Drizzle',
        'freezingDrizzle': 'Freezing drizzle',
        'rain': 'Rain',
        'freezingRain': 'Freezing rain',
        'snow': 'Snow',
        'showers': 'Rain showers',
        'snowShowers': 'Snow showers',
        'thunderstorm': 'Thunderstorm',
        'thunderstormHail': 'Thunderstorm with hail',
        'weather': 'Weather',
      },
      'hi': {
        'clear': 'साफ आसमान',
        'mainlyClear': 'अधिकतर साफ',
        'partlyCloudy': 'आंशिक बादल',
        'overcast': 'बादल छाए हुए',
        'fog': 'कोहरा',
        'drizzle': 'बूंदाबांदी',
        'freezingDrizzle': 'ठंडी बूंदाबांदी',
        'rain': 'बारिश',
        'freezingRain': 'बर्फीली बारिश',
        'snow': 'बर्फबारी',
        'showers': 'बारिश की फुहार',
        'snowShowers': 'बर्फ की फुहार',
        'thunderstorm': 'आंधी-तूफान',
        'thunderstormHail': 'ओलों के साथ आंधी',
        'weather': 'मौसम',
      },
      'pa': {
        'clear': 'ਸਾਫ਼ ਅਸਮਾਨ',
        'mainlyClear': 'ਜ਼ਿਆਦਾਤਰ ਸਾਫ਼',
        'partlyCloudy': 'ਥੋੜ੍ਹੇ ਬੱਦਲ',
        'overcast': 'ਬੱਦਲ ਛਾਏ ਹੋਏ',
        'fog': 'ਧੁੰਦ',
        'drizzle': 'ਬੂੰਦਾਬਾਂਦੀ',
        'freezingDrizzle': 'ਠੰਡੀ ਬੂੰਦਾਬਾਂਦੀ',
        'rain': 'ਮੀਂਹ',
        'freezingRain': 'ਬਰਫ਼ੀਲੀ ਬਾਰਿਸ਼',
        'snow': 'ਬਰਫ਼ਬਾਰੀ',
        'showers': 'ਮੀਂਹ ਦੀਆਂ ਫੁਹਾਰਾਂ',
        'snowShowers': 'ਬਰਫ਼ ਦੀਆਂ ਫੁਹਾਰਾਂ',
        'thunderstorm': 'ਤੂਫ਼ਾਨ',
        'thunderstormHail': 'ਗੜਿਆਂ ਨਾਲ ਤੂਫ਼ਾਨ',
        'weather': 'ਮੌਸਮ',
      },
      'mr': {
        'clear': 'स्वच्छ आकाश',
        'mainlyClear': 'बहुतेक स्वच्छ',
        'partlyCloudy': 'अंशतः ढगाळ',
        'overcast': 'ढगाळ',
        'fog': 'धुके',
        'drizzle': 'रिमझिम पाऊस',
        'freezingDrizzle': 'गोठवणारी रिमझिम',
        'rain': 'पाऊस',
        'freezingRain': 'गोठणारा पाऊस',
        'snow': 'बर्फवृष्टी',
        'showers': 'पावसाच्या सरी',
        'snowShowers': 'बर्फाच्या सरी',
        'thunderstorm': 'वादळी पाऊस',
        'thunderstormHail': 'गारांसह वादळ',
        'weather': 'हवामान',
      },
      'bn': {
        'clear': 'পরিষ্কার আকাশ',
        'mainlyClear': 'বেশিরভাগ পরিষ্কার',
        'partlyCloudy': 'আংশিক মেঘলা',
        'overcast': 'মেঘাচ্ছন্ন',
        'fog': 'কুয়াশা',
        'drizzle': 'গুঁড়ি গুঁড়ি বৃষ্টি',
        'freezingDrizzle': 'হিমশীতল গুঁড়ি বৃষ্টি',
        'rain': 'বৃষ্টি',
        'freezingRain': 'বরফমিশ্রিত বৃষ্টি',
        'snow': 'তুষারপাত',
        'showers': 'বৃষ্টির ঝরনা',
        'snowShowers': 'তুষারের ঝরনা',
        'thunderstorm': 'বজ্রঝড়',
        'thunderstormHail': 'শিলাবৃষ্টিসহ বজ্রঝড়',
        'weather': 'আবহাওয়া',
      },
      'gu': {
        'clear': 'સ્વચ્છ આકાશ',
        'mainlyClear': 'મોટાભાગે સ્વચ્છ',
        'partlyCloudy': 'આંશિક વાદળછાયું',
        'overcast': 'વાદળછાયું',
        'fog': 'ધુમ્મસ',
        'drizzle': 'ઝરમર વરસાદ',
        'freezingDrizzle': 'ઠંડો ઝરમર વરસાદ',
        'rain': 'વરસાદ',
        'freezingRain': 'બરફીલો વરસાદ',
        'snow': 'હિમવર્ષા',
        'showers': 'વરસાદની ઝાપટાં',
        'snowShowers': 'હિમની ઝાપટાં',
        'thunderstorm': 'વાવાઝોડું',
        'thunderstormHail': 'કરા સાથે વાવાઝોડું',
        'weather': 'હવામાન',
      },
      'ta': {
        'clear': 'தெளிவான வானம்',
        'mainlyClear': 'பெரும்பாலும் தெளிவு',
        'partlyCloudy': 'பகுதி மேகமூட்டம்',
        'overcast': 'மேகமூட்டம்',
        'fog': 'மூடுபனி',
        'drizzle': 'தூறல்',
        'freezingDrizzle': 'உறையும் தூறல்',
        'rain': 'மழை',
        'freezingRain': 'உறையும் மழை',
        'snow': 'பனிப்பொழிவு',
        'showers': 'மழைத்தூறல்',
        'snowShowers': 'பனித்தூறல்',
        'thunderstorm': 'இடியுடன் கூடிய மழை',
        'thunderstormHail': 'ஆலங்கட்டியுடன் இடியுடன் கூடிய மழை',
        'weather': 'வானிலை',
      },
      'te': {
        'clear': 'స్పష్టమైన ఆకాశం',
        'mainlyClear': 'ఎక్కువగా స్పష్టంగా',
        'partlyCloudy': 'కొంత మేఘావృతం',
        'overcast': 'మేఘావృతం',
        'fog': 'పొగమంచు',
        'drizzle': 'చినుకులు',
        'freezingDrizzle': 'గడ్డకట్టే చినుకులు',
        'rain': 'వర్షం',
        'freezingRain': 'గడ్డకట్టే వర్షం',
        'snow': 'మంచు',
        'showers': 'వర్షపు జల్లులు',
        'snowShowers': 'మంచు జల్లులు',
        'thunderstorm': 'ఉరుములతో కూడిన వర్షం',
        'thunderstormHail': 'వడగళ్లతో ఉరుములు',
        'weather': 'వాతావరణం',
      },
      'kn': {
        'clear': 'ಸ್ಪಷ್ಟ ಆಕಾಶ',
        'mainlyClear': 'ಹೆಚ್ಚಾಗಿ ಸ್ಪಷ್ಟ',
        'partlyCloudy': 'ಭಾಗಶಃ ಮೋಡ',
        'overcast': 'ಮೋಡ ಕವಿದಿದೆ',
        'fog': 'ಮಂಜು',
        'drizzle': 'ತುಂತುರು ಮಳೆ',
        'freezingDrizzle': 'ಹಿಮದ ತುಂತುರು',
        'rain': 'ಮಳೆ',
        'freezingRain': 'ಹಿಮ ಮಳೆ',
        'snow': 'ಹಿಮಪಾತ',
        'showers': 'ಮಳೆಯ ತುಂತುರು',
        'snowShowers': 'ಹಿಮದ ತುಂತುರು',
        'thunderstorm': 'ಗುಡುಗು ಸಹಿತ ಮಳೆ',
        'thunderstormHail': 'ಆಲಿಕಲ್ಲಿನೊಂದಿಗೆ ಗುಡುಗು',
        'weather': 'ಹವಾಮಾನ',
      },
      'ml': {
        'clear': 'തെളിഞ്ഞ ആകാശം',
        'mainlyClear': 'മിക്കവാറും തെളിഞ്ഞത്',
        'partlyCloudy': 'ഭാഗികമായി മേഘാവൃതം',
        'overcast': 'മേഘാവൃതം',
        'fog': 'മൂടൽമഞ്ഞ്',
        'drizzle': 'ചാറ്റൽമഴ',
        'freezingDrizzle': 'തണുത്ത ചാറ്റൽമഴ',
        'rain': 'മഴ',
        'freezingRain': 'മഞ്ഞുമഴ',
        'snow': 'മഞ്ഞുവീഴ്ച',
        'showers': 'മഴച്ചാറ്റൽ',
        'snowShowers': 'മഞ്ഞുചാറ്റൽ',
        'thunderstorm': 'ഇടിമിന്നലോടുകൂടിയ മഴ',
        'thunderstormHail': 'ആലിപ്പഴത്തോടുകൂടിയ ഇടിമിന്നൽ',
        'weather': 'കാലാവസ്ഥ',
      },
    };

    return localized[language]?[key] ?? localized['en']![key]!;
  }

  static String agricultureMessage(
    String language,
    int code,
    String maxTemp,
    String minTemp,
    String rainProbability,
  ) {
    final rain = int.tryParse(rainProbability) ?? 0;

    if (language == 'hi') {
      if (rain >= 70) {
        return 'आज बारिश की संभावना अधिक है। खेत में पानी निकासी की जाँच करें और बारिश से पहले अनावश्यक सिंचाई या पत्तियों पर स्प्रे करने से बचें।';
      }
      if (code >= 95) {
        return 'आंधी-तूफान की संभावना होने पर खुले खेत में काम और रसायनों का छिड़काव रोकें तथा पौधों और सिंचाई व्यवस्था की सुरक्षा करें।';
      }
      return 'आज का अधिकतम तापमान लगभग $maxTemp°C और न्यूनतम $minTemp°C है। सिंचाई और खेत के काम का समय स्थानीय फसल की जरूरत के अनुसार तय करें।';
    }

    if (language == 'pa') {
      if (rain >= 70) {
        return 'ਅੱਜ ਮੀਂਹ ਦੀ ਸੰਭਾਵਨਾ ਵੱਧ ਹੈ। ਖੇਤ ਵਿੱਚ ਪਾਣੀ ਦੀ ਨਿਕਾਸੀ ਜਾਂਚੋ ਅਤੇ ਮੀਂਹ ਤੋਂ ਪਹਿਲਾਂ ਬੇਲੋੜੀ ਸਿੰਚਾਈ ਜਾਂ ਪੱਤਿਆਂ ਉੱਤੇ ਛਿੜਕਾਅ ਤੋਂ ਬਚੋ।';
      }
      return 'ਅੱਜ ਵੱਧ ਤੋਂ ਵੱਧ ਤਾਪਮਾਨ ਲਗਭਗ $maxTemp°C ਅਤੇ ਘੱਟੋ-ਘੱਟ $minTemp°C ਹੈ। ਸਿੰਚਾਈ ਅਤੇ ਖੇਤੀ ਕੰਮ ਫਸਲ ਦੀ ਲੋੜ ਮੁਤਾਬਕ ਕਰੋ।';
    }

    if (language == 'mr') {
      if (rain >= 70) {
        return 'आज पावसाची शक्यता जास्त आहे. शेतातील निचरा तपासा आणि पावसापूर्वी अनावश्यक सिंचन किंवा पानांवर फवारणी टाळा.';
      }
      return 'आज कमाल तापमान सुमारे $maxTemp°C आणि किमान $minTemp°C आहे. सिंचन व शेतातील कामे पिकाच्या गरजेनुसार ठरवा.';
    }

    if (language == 'bn') {
      if (rain >= 70) {
        return 'আজ বৃষ্টির সম্ভাবনা বেশি। জমির জল নিষ্কাশন পরীক্ষা করুন এবং বৃষ্টির আগে অপ্রয়োজনীয় সেচ বা পাতায় স্প্রে এড়িয়ে চলুন।';
      }
      return 'আজ সর্বোচ্চ তাপমাত্রা প্রায় $maxTemp°C এবং সর্বনিম্ন $minTemp°C। ফসলের প্রয়োজন অনুযায়ী সেচ ও মাঠের কাজের সময় ঠিক করুন।';
    }

    if (language == 'gu') {
      if (rain >= 70) {
        return 'આજે વરસાદની શક્યતા વધારે છે. ખેતરમાં પાણીના નિકાલની તપાસ કરો અને વરસાદ પહેલાં બિનજરૂરી સિંચાઈ અથવા પાંદડાં પર છંટકાવ ટાળો.';
      }
      return 'આજે મહત્તમ તાપમાન લગભગ $maxTemp°C અને લઘુત્તમ $minTemp°C છે. પાકની જરૂરિયાત મુજબ સિંચાઈ અને ખેતરનું કામ નક્કી કરો.';
    }

    if (language == 'ta') {
      if (rain >= 70) {
        return 'இன்று மழைக்கான வாய்ப்பு அதிகம். வயலில் நீர் வடிகால் சரியாக உள்ளதா பாருங்கள்; மழைக்கு முன் தேவையற்ற பாசனம் அல்லது இலைத் தெளிப்பைத் தவிர்க்கவும்.';
      }
      return 'இன்று அதிகபட்ச வெப்பநிலை சுமார் $maxTemp°C மற்றும் குறைந்தபட்சம் $minTemp°C. பயிரின் தேவைக்கேற்ப பாசனம் மற்றும் வயல் பணிகளை திட்டமிடுங்கள்.';
    }

    if (language == 'te') {
      if (rain >= 70) {
        return 'ఈ రోజు వర్షం వచ్చే అవకాశం ఎక్కువగా ఉంది. పొలంలో నీటి పారుదలను తనిఖీ చేసి, వర్షానికి ముందు అవసరం లేని నీటిపారుదల లేదా ఆకులపై పిచికారీని నివారించండి.';
      }
      return 'ఈ రోజు గరిష్ఠ ఉష్ణోగ్రత సుమారు $maxTemp°C మరియు కనిష్ఠం $minTemp°C. పంట అవసరానికి అనుగుణంగా నీటిపారుదల మరియు వ్యవసాయ పనులను నిర్ణయించండి.';
    }

    if (language == 'kn') {
      if (rain >= 70) {
        return 'ಇಂದು ಮಳೆಯ ಸಾಧ್ಯತೆ ಹೆಚ್ಚು. ಹೊಲದ ನೀರು ಹರಿಯುವ ವ್ಯವಸ್ಥೆಯನ್ನು ಪರಿಶೀಲಿಸಿ ಮತ್ತು ಮಳೆಯ ಮೊದಲು ಅನಗತ್ಯ ನೀರಾವರಿ ಅಥವಾ ಎಲೆಗಳ ಮೇಲೆ ಸಿಂಪಡಿಸುವುದನ್ನು ತಪ್ಪಿಸಿ.';
      }
      return 'ಇಂದು ಗರಿಷ್ಠ ತಾಪಮಾನ ಸುಮಾರು $maxTemp°C ಮತ್ತು ಕನಿಷ್ಠ $minTemp°C. ಬೆಳೆ ಅಗತ್ಯಕ್ಕೆ ಅನುಗುಣವಾಗಿ ನೀರಾವರಿ ಮತ್ತು ಹೊಲದ ಕೆಲಸಗಳನ್ನು ಯೋಜಿಸಿ.';
    }

    if (language == 'ml') {
      if (rain >= 70) {
        return 'ഇന്ന് മഴയ്ക്ക് സാധ്യത കൂടുതലാണ്. കൃഷിയിടത്തിലെ നീർവാർച്ച പരിശോധിക്കുകയും മഴയ്ക്ക് മുമ്പ് അനാവശ്യ ജലസേചനമോ ഇലകളിൽ തളിക്കലോ ഒഴിവാക്കുകയും ചെയ്യുക.';
      }
      return 'ഇന്ന് പരമാവധി താപനില ഏകദേശം $maxTemp°Cയും കുറഞ്ഞത് $minTemp°Cയും ആണ്. വിളയുടെ ആവശ്യത്തിന് അനുസരിച്ച് ജലസേചനവും കൃഷിപ്പണികളും ക്രമീകരിക്കുക.';
    }

    if (rain >= 70) {
      return 'Rain probability is high today. Check field drainage and avoid unnecessary irrigation or leaf spraying before rainfall.';
    }

    if (code >= 95) {
      return 'Thunderstorm conditions may be unsafe for field work. Avoid spraying during storms and protect equipment and plants where possible.';
    }

    return 'Today the expected high is about $maxTemp°C and low about $minTemp°C. Plan irrigation and field work according to your crop requirements.';
  }
}
