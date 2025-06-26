// Fixed version of _buildLocationInfo method

Widget _buildLocationInfo(LocationProvider locationProvider) {
  final currentLocation = locationProvider.currentLocation!;
  final lat = currentLocation.latitude.toStringAsFixed(6);
  final lng = currentLocation.longitude.toStringAsFixed(6);
  
  return AnimatedOpacity(
    opacity: _showLocationInfo ? 1.0 : 0.0,
    duration: const Duration(milliseconds: 300),
    child: Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.4,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Location Info',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => setState(() => _showLocationInfo = false),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Coordinates
            _buildInfoRow(
              Icons.gps_fixed,
              'Coordinates',
              'Lat: $lat\nLng: $lng',
            ),
            
            // Address information
            const SizedBox(height: 12),
            if (locationProvider.currentAddress != null) 
              _buildInfoRow(
                Icons.location_on,
                'Address',
                locationProvider.currentAddress!,
              )
            else
              const Text(
                'Getting address...',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                  color: Colors.grey,
                ),
              ),
            
            if (locationProvider.city != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.location_city,
                'City',
                locationProvider.city!,
                secondary: locationProvider.country,
              ),
            ],
            
            if (locationProvider.postalCode != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.local_post_office,
                'Postal Code',
                locationProvider.postalCode!,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}