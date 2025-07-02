import 'dart:io';

void main() async {
  print('🔍 Analyzing Dart file usage...\n');
  
  // Get all dart files
  final allFiles = await _getAllDartFiles();
  print('📊 Found ${allFiles.length} Dart files\n');
  
  // Find imports
  final importMap = <String, Set<String>>{};
  for (final file in allFiles) {
    importMap[file] = await _getImports(file);
  }
  
  // Find used vs unused
  final used = <String>{};
  final queue = ['main.dart'];
  
  while (queue.isNotEmpty) {
    final current = queue.removeAt(0);
    if (used.contains(current)) continue;
    used.add(current);
    
    if (importMap.containsKey(current)) {
      queue.addAll(importMap[current]!);
    }
  }
  
  final unused = allFiles.where((f) => !used.contains(f)).toList()..sort();
  
  print('✅ USED FILES (${used.length}):');
  for (final file in used.toList()..sort()) {
    print('  $file');
  }
  
  print('\n❌ UNUSED FILES (${unused.length}):');
  for (final file in unused) {
    print('  🗑️  $file');
  }
  
  print('\n📈 SUMMARY:');
  print('  Total: ${allFiles.length}');
  print('  Used: ${used.length} (${(used.length / allFiles.length * 100).toStringAsFixed(1)}%)');
  print('  Unused: ${unused.length} (${(unused.length / allFiles.length * 100).toStringAsFixed(1)}%)');
}

Future<List<String>> _getAllDartFiles() async {
  final files = <String>[];
  final libDir = Directory('lib');
  
  await for (final entity in libDir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      files.add(entity.path.replaceFirst('lib/', ''));
    }
  }
  
  return files..sort();
}

Future<Set<String>> _getImports(String filePath) async {
  final imports = <String>{};
  final file = File('lib/$filePath');
  
  try {
    final content = await file.readAsString();
    final lines = content.split('\n');
    
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith("import '") && 
          (trimmed.contains('../') || trimmed.contains('./'))) {
        
        // Extract the import path
        final start = trimmed.indexOf("'") + 1;
        final end = trimmed.indexOf("'", start);
        if (end > start) {
          final importPath = trimmed.substring(start, end);
          final resolved = _resolveImport(importPath, filePath);
          if (resolved != null) {
            imports.add(resolved);
          }
        }
      }
    }
  } catch (e) {
    print('Error reading $filePath: $e');
  }
  
  return imports;
}

String? _resolveImport(String importPath, String currentFile) {
  final currentDir = currentFile.contains('/') 
      ? currentFile.substring(0, currentFile.lastIndexOf('/'))
      : '';
  
  String resolved = importPath;
  
  // Handle ../
  while (resolved.startsWith('../')) {
    resolved = resolved.substring(3);
    // Go up one directory
  }
  
  // Handle ./
  if (resolved.startsWith('./')) {
    resolved = resolved.substring(2);
    if (currentDir.isNotEmpty) {
      resolved = '$currentDir/$resolved';
    }
  }
  
  // Add .dart if missing
  if (!resolved.endsWith('.dart')) {
    resolved += '.dart';
  }
  
  return resolved;
}