import '../config/api_keys.dart';

class MapConstants {
  // Use API key from environment configuration
  static String get mapBoxAccessToken => ApiKeys.mapboxAccessToken;
  static String get googleMapsApiKey => ApiKeys.googleMapsApiKey;
  
  // Different map styles available
  static const String streetStyle = 'mapbox/streets-v12';
  static const String navigationDayStyle = 'mapbox/navigation-day-v1';
  static const String navigationNightStyle = 'mapbox/navigation-night-v1';
  static const String satelliteStyle = 'mapbox/satellite-streets-v12';
  
  // Default map style
  static const String defaultStyle = navigationNightStyle;
  
  // Get map style URL
  static String getMapStyleUrl(String style) {
    return 'https://api.mapbox.com/styles/v1/$style/tiles/{z}/{x}/{y}?access_token=$mapBoxAccessToken';
  }
  
  // Google Maps URLs
  static String getGoogleMapsUrl(String type) {
    switch (type) {
      case 'satellite':
        return 'https://maps.googleapis.com/maps/api/staticmap?maptype=satellite&key=$googleMapsApiKey';
      case 'terrain':
        return 'https://maps.googleapis.com/maps/api/staticmap?maptype=terrain&key=$googleMapsApiKey';
      case 'hybrid':
        return 'https://maps.googleapis.com/maps/api/staticmap?maptype=hybrid&key=$googleMapsApiKey';
      default:
        return 'https://maps.googleapis.com/maps/api/staticmap?maptype=roadmap&key=$googleMapsApiKey';
    }
  }
  
}
