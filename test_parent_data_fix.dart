import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ParentDataWidget Fix Test',
      home: TestScreen(),
    );
  }
}

class TestScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('ParentDataWidget Fix Test')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // This should work fine - Flexible inside Row
            Row(
              children: [
                Icon(Icons.people, size: 18),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Nearby Users: 5',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            
            // This should work fine - Text directly as label (FIXED)
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  print('Button pressed!');
                },
                icon: Icon(Icons.location_on, size: 20),
                label: Text(
                  'Start Sharing',
                  style: TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            
            // This would cause the error (commented out for reference)
            /*
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: Icon(Icons.location_on, size: 20),
                label: Flexible(  // <-- This is WRONG!
                  child: Text(
                    'This would cause ParentDataWidget error',
                    style: TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            */
            
            Text(
              'The fix removes Flexible from button labels.\nFlexible should only be used inside Flex widgets (Row, Column, etc.)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}