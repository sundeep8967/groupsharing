# KrutrimMapWidget

A Flutter widget that provides a map interface using the Krutrim Maps SDK with support for markers and user location.

## Features

- Display a map centered on a specific location
- Add and manage markers on the map
- Show user location (if enabled)
- Handle map initialization and error states
- Efficient marker updates and cleanup

## Usage

### Basic Usage

```dart
KrutrimMapWidget(
  initialPosition: const latlong.LatLng(12.9716, 77.5946), // Initial map center
  markers: {
    MapMarker(
      id: 'marker1',
      position: const latlong.LatLng(12.9716, 77.5946),
      title: 'Marker Title',
      snippet: 'Additional information',
    ),
  },
  showUserLocation: true,
)
```

### Adding Markers

```dart
final markers = {
  MapMarker(
    id: 'unique_marker_id',
    position: const latlong.LatLng(latitude, longitude),
    title: 'Marker Title',
    snippet: 'Additional information',
    color: Colors.blue, // Optional: Custom marker color
    // icon: 'path/to/icon.png', // Optional: Custom marker icon
  ),
};

// Use in widget
KrutrimMapWidget(
  initialPosition: const latlong.LatLng(latitude, longitude),
  markers: markers,
)
```

### Handling Map Events

```dart
// The widget currently supports basic map initialization events
// Additional event handling can be added as needed
```

## API Reference

### KrutrimMapWidget Properties

| Property | Type | Description | Required |
|----------|------|-------------|----------|
| `initialPosition` | `latlong.LatLng` | The initial position to center the map on | Yes |
| `markers` | `Set<MapMarker>` | Set of markers to display on the map | No (default: empty) |
| `showUserLocation` | `bool` | Whether to show the user's location on the map | No (default: true) |

### MapMarker Properties

| Property | Type | Description | Required |
|----------|------|-------------|----------|
| `id` | `String` | Unique identifier for the marker | Yes |
| `position` | `latlong.LatLng` | Geographical coordinates of the marker | Yes |
| `title` | `String?` | Title displayed in the info window | No |
| `snippet` | `String?` | Additional text displayed in the info window | No |
| `color` | `Color?` | Color of the marker | No |
| `icon` | `String?` | URL or asset path to a custom icon | No |
| `extra` | `Map<String, dynamic>?` | Additional data associated with the marker | No |

## Setup

1. Add the required dependencies to your `pubspec.yaml`:

```yaml
dependencies:
  krutrim_maps_flutter:
    path: ./plugins/krutrim_maps_flutter
  latlong2: ^0.9.0
```

2. Make sure to set up the required permissions in your `AndroidManifest.xml` and `Info.plist` files.

## Troubleshooting

### Map Not Loading
- Ensure you have a valid API key set in the native platform code
- Check that internet permissions are properly configured
- Verify that the map container has a non-zero size

### Markers Not Showing
- Check that marker IDs are unique
- Verify that marker positions are valid coordinates
- Ensure the map is fully initialized before adding markers

## License

This widget is part of the GroupSharing app and is available under the MIT License.
