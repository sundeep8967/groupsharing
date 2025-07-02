import 'dart:io';

void main() async {
  print('🔍 COMPREHENSIVE DART FILE USAGE ANALYSIS\n');
  
  final analyzer = DartUsageAnalyzer();
  await analyzer.analyze();
}

class DartUsageAnalyzer {
  final Map<String, Set<String>> _imports = {};
  final Map<String, String> _fileContents = {};
  final Set<String> _allFiles = {};
  final Set<String> _usedFiles = {};
  final Set<String> _unusedFiles = {};
  
  Future<void> analyze() async {
    // Step 1: Find all Dart files
    await _findAllDartFiles();
    print('📊 Found ${_allFiles.length} Dart files\n');
    
    // Step 2: Parse imports for each file
    await _parseAllImports();
    
    // Step 3: Trace usage starting from main.dart
    await _traceUsage();
    
    // Step 4: Generate report
    _generateReport();
  }
  
  Future<void> _findAllDartFiles() async {
    final libDir = Directory('lib');
    await for (final entity in libDir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        final relativePath = entity.path.replaceFirst('lib/', '');
        _allFiles.add(relativePath);
      }
    }
  }
  
  Future<void> _parseAllImports() async {
    for (final filePath in _allFiles) {
      try {
        final file = File('lib/$filePath');
        final content = await file.readAsString();
        _fileContents[filePath] = content;
        _imports[filePath] = _extractImports(content, filePath);
      } catch (e) {
        print('❌ Error reading $filePath: $e');
      }
    }
  }
  
  Set<String> _extractImports(String content, String currentFile) {
    final imports = <String>{};
    final lines = content.split('\n');
    
    for (final line in lines) {
      final trimmed = line.trim();
      
      // Look for relative imports
      if (trimmed.startsWith("import '") && 
          (trimmed.contains('../') || trimmed.contains('./'))) {
        
        final startQuote = trimmed.indexOf("'");
        final endQuote = trimmed.indexOf("'", startQuote + 1);
        
        if (startQuote != -1 && endQuote != -1) {
          final importPath = trimmed.substring(startQuote + 1, endQuote);
          final resolvedPath = _resolveImportPath(importPath, currentFile);
          if (resolvedPath != null && _allFiles.contains(resolvedPath)) {
            imports.add(resolvedPath);
          }
        }
      }
    }
    
    return imports;
  }
  
  String? _resolveImportPath(String importPath, String currentFile) {
    // Get the directory of the current file
    final currentDir = currentFile.contains('/') 
        ? currentFile.substring(0, currentFile.lastIndexOf('/'))
        : '';
    
    String resolved = importPath;
    String workingDir = currentDir;
    
    // Handle ../ (go up directories)
    while (resolved.startsWith('../')) {
      resolved = resolved.substring(3);
      if (workingDir.contains('/')) {
        workingDir = workingDir.substring(0, workingDir.lastIndexOf('/'));
      } else {
        workingDir = '';
      }
    }
    
    // Handle ./ (current directory)
    if (resolved.startsWith('./')) {
      resolved = resolved.substring(2);
    }
    
    // Combine working directory with resolved path
    if (workingDir.isNotEmpty) {
      resolved = '$workingDir/$resolved';
    }
    
    // Add .dart extension if missing
    if (!resolved.endsWith('.dart')) {
      resolved += '.dart';
    }
    
    return resolved;
  }
  
  Future<void> _traceUsage() async {
    // Start from main.dart and trace all dependencies
    final queue = <String>['main.dart'];
    final visited = <String>{};
    
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      
      if (visited.contains(current) || !_allFiles.contains(current)) {
        continue;
      }
      
      visited.add(current);
      _usedFiles.add(current);
      
      // Add all imports of current file to queue
      final imports = _imports[current] ?? {};
      for (final import in imports) {
        if (!visited.contains(import)) {
          queue.add(import);
        }
      }
    }
    
    // Find unused files
    _unusedFiles.addAll(_allFiles.where((file) => !_usedFiles.contains(file)));
  }
  
  void _generateReport() {
    print('✅ USED FILES (${_usedFiles.length}):');
    print('=' * 50);
    
    // Group by category
    final categories = _categorizeFiles(_usedFiles);
    for (final category in categories.keys) {
      print('\n📁 $category (${categories[category]!.length}):');
      for (final file in categories[category]!) {
        print('  ✅ $file');
      }
    }
    
    print('\n❌ UNUSED FILES (${_unusedFiles.length}):');
    print('=' * 50);
    
    final unusedCategories = _categorizeFiles(_unusedFiles);
    for (final category in unusedCategories.keys) {
      print('\n📁 $category (${unusedCategories[category]!.length}):');
      for (final file in unusedCategories[category]!) {
        print('  🗑️  $file');
      }
    }
    
    print('\n📈 SUMMARY:');
    print('=' * 50);
    print('Total files: ${_allFiles.length}');
    print('Used files: ${_usedFiles.length} (${(_usedFiles.length / _allFiles.length * 100).toStringAsFixed(1)}%)');
    print('Unused files: ${_unusedFiles.length} (${(_unusedFiles.length / _allFiles.length * 100).toStringAsFixed(1)}%)');
    
    print('\n💡 CLEANUP RECOMMENDATIONS:');
    print('=' * 50);
    
    if (_unusedFiles.isNotEmpty) {
      print('The following files can potentially be removed:');
      
      // High priority (safe to remove)
      final highPriority = _unusedFiles.where((f) => 
        f.contains('debug/') || 
        f.contains('_test') ||
        f.startsWith('providers/') && !f.contains('auth_provider') && !f.contains('location_provider') ||
        f.contains('alternative') ||
        f.contains('redundant')
      ).toList()..sort();
      
      if (highPriority.isNotEmpty) {
        print('\n🔴 HIGH PRIORITY (Safe to remove):');
        for (final file in highPriority) {
          print('  🗑️  $file');
        }
      }
      
      // Medium priority
      final mediumPriority = _unusedFiles.where((f) => 
        f.contains('services/') && !highPriority.contains(f) ||
        f.contains('models/') ||
        f.contains('widgets/') && !f.contains('smooth_modern_map') && !f.contains('emergency_fix_button')
      ).toList()..sort();
      
      if (mediumPriority.isNotEmpty) {
        print('\n🟡 MEDIUM PRIORITY (Verify before removing):');
        for (final file in mediumPriority) {
          print('  ⚠️  $file');
        }
      }
      
      // Low priority
      final lowPriority = _unusedFiles.where((f) => 
        !highPriority.contains(f) && !mediumPriority.contains(f)
      ).toList()..sort();
      
      if (lowPriority.isNotEmpty) {
        print('\n🟢 LOW PRIORITY (Keep for now):');
        for (final file in lowPriority) {
          print('  ⏸️  $file');
        }
      }
      
      print('\n📋 CLEANUP STEPS:');
      print('1. Remove HIGH PRIORITY files first');
      print('2. Test the app to ensure it still works');
      print('3. Remove MEDIUM PRIORITY files one by one, testing after each');
      print('4. Keep LOW PRIORITY files unless you\'re sure they\'re not needed');
      print('5. Always backup before deleting files');
    } else {
      print('🎉 All files are being used! No cleanup needed.');
    }
  }
  
  Map<String, List<String>> _categorizeFiles(Set<String> files) {
    final categories = <String, List<String>>{};
    
    for (final file in files) {
      String category;
      
      if (file == 'main.dart' || file == 'firebase_options.dart') {
        category = 'Core';
      } else if (file.startsWith('config/')) {
        category = 'Configuration';
      } else if (file.startsWith('providers/')) {
        category = 'Providers';
      } else if (file.startsWith('services/')) {
        category = 'Services';
      } else if (file.startsWith('screens/')) {
        category = 'Screens';
      } else if (file.startsWith('models/')) {
        category = 'Models';
      } else if (file.startsWith('widgets/')) {
        category = 'Widgets';
      } else if (file.startsWith('utils/')) {
        category = 'Utils';
      } else if (file.startsWith('constants/')) {
        category = 'Constants';
      } else {
        category = 'Other';
      }
      
      categories.putIfAbsent(category, () => []).add(file);
    }
    
    // Sort files within each category
    for (final category in categories.keys) {
      categories[category]!.sort();
    }
    
    return categories;
  }
}