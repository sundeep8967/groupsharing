import 'package:flutter/material.dart';
import 'lib/widgets/emergency_fix_button.dart';

/// Demo app to showcase the Emergency Fix Button
void main() {
  runApp(const EmergencyFixButtonDemo());
}

class EmergencyFixButtonDemo extends StatelessWidget {
  const EmergencyFixButtonDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Emergency Fix Button Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const DemoScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DemoScreen extends StatefulWidget {
  const DemoScreen({super.key});

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> {
  bool _showEmergencyButton = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Fix Button Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.location_on,
                  size: 64,
                  color: Colors.blue,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Location Sharing Demo',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _showEmergencyButton 
                      ? 'Location sharing is NOT working!'
                      : 'Location sharing is working fine',
                  style: TextStyle(
                    fontSize: 16,
                    color: _showEmergencyButton ? Colors.red : Colors.green,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _showEmergencyButton = !_showEmergencyButton;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _showEmergencyButton ? Colors.green : Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    _showEmergencyButton 
                        ? 'Fix Location Issues'
                        : 'Simulate Location Issues',
                  ),
                ),
                const SizedBox(height: 16),
                if (_showEmergencyButton)
                  const Text(
                    'Look for the red "FIX NOW" button in the bottom right!',
                    style: TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
          
          // Emergency Fix Button
          EmergencyFixButton(
            showButton: _showEmergencyButton,
          ),
        ],
      ),
    );
  }
}