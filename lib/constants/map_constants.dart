class MapConstants {
  static const String mapBoxAccessToken = 'YOUR_MAPBOX_ACCESS_TOKEN';
  
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
}
