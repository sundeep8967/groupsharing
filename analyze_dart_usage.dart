import 'dart:io';

void main() async {
  print('🔍 Analyzing Dart file usage in lib/ directory...\n');
  
  // Get all dart files
  final libDir = Directory('lib');
  final allDartFiles = await _getAllDartFiles(libDir);
  
  print('📊 Found ${allDartFiles.length} Dart files total\n');
  
  // Analyze imports and usage
  final usageAnalysis = await _analyzeUsage(allDartFiles);
  
  // Print results
  _printResults(usageAnalysis);
}

Future<List<String>> _getAllDartFiles(Directory dir) async {
  final files = <String>[];
  
  await for (final entity in dir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      files.add(entity.path.replaceFirst('lib/', ''));
    }
  }
  
  return files..sort();
}

Future<Map<String, dynamic>> _analyzeUsage(List<String> allFiles) async {
  final importedFiles = <String>{};
  final fileImports = <String, Set<String>>{};
  
  // Analyze each file for imports
  for (final filePath in allFiles) {
    final file = File('lib/$filePath');
    final content = await file.readAsString();
    final imports = _extractImports(content, filePath);
    
    fileImports[filePath] = imports;
    importedFiles.addAll(imports);
  }
  
  // Categorize files
  final entryPoints = ['main.dart'];
  final directlyUsed = <String>{};
  final indirectlyUsed = <String>{};
  final unused = <String>{};
  
  // Find directly used files (imported by entry points)
  for (final entryPoint in entryPoints) {
    if (fileImports.containsKey(entryPoint)) {
      directlyUsed.addAll(fileImports[entryPoint]!);
    }
  }
  
  // Find indirectly used files (imported by directly used files)
  final toCheck = List<String>.from(directlyUsed);
  final checked = <String>{};
  
  while (toCheck.isNotEmpty) {
    final current = toCheck.removeAt(0);
    if (checked.contains(current)) continue;
    checked.add(current);
    
    if (fileImports.containsKey(current)) {
      for (final imported in fileImports[current]!) {
        if (!directlyUsed.contains(imported) && !indirectlyUsed.contains(imported)) {
          indirectlyUsed.add(imported);
          toCheck.add(imported);
        }
      }
    }
  }
  
  // Find unused files
  for (final file in allFiles) {
    if (!entryPoints.contains(file) && 
        !directlyUsed.contains(file) && 
        !indirectlyUsed.contains(file)) {
      unused.add(file);
    }
  }
  
  return {
    'entryPoints': entryPoints,
    'directlyUsed': directlyUsed.toList()..sort(),
    'indirectlyUsed': indirectlyUsed.toList()..sort(),
    'unused': unused.toList()..sort(),
    'fileImports': fileImports,
  };
}

Set<String> _extractImports(String content, String currentFile) {
  final imports = <String>{};
  final lines = content.split('\n');
  
  for (final line in lines) {
    final trimmed = line.trim();
    
    // Look for relative imports (import '../' or import './')
    if (trimmed.startsWith("import '") && 
        (trimmed.contains('../') || trimmed.contains('./'))) {
      
      final match = RegExp(r"import\s+['\"]([^'\"]+)['\"]").firstMatch(trimmed);
      if (match != null) {
        final importPath = match.group(1)!;
        final resolvedPath = _resolveImportPath(importPath, currentFile);
        if (resolvedPath != null) {
          imports.add(resolvedPath);
        }
      }
    }
  }
  
  return imports;
}

String? _resolveImportPath(String importPath, String currentFile) {
  // Remove the current file's directory to get base path
  final currentDir = currentFile.contains('/') 
      ? currentFile.substring(0, currentFile.lastIndexOf('/'))
      : '';
  
  // Resolve relative path
  String resolvedPath = importPath;
  
  // Handle ../ (go up one directory)
  while (resolvedPath.startsWith('../')) {
    resolvedPath = resolvedPath.substring(3);
    if (currentDir.contains('/')) {
      final parentDir = currentDir.substring(0, currentDir.lastIndexOf('/'));
      resolvedPath = parentDir.isEmpty ? resolvedPath : '$parentDir/$resolvedPath';
    }
  }
  
  // Handle ./ (current directory)
  if (resolvedPath.startsWith('./')) {
    resolvedPath = resolvedPath.substring(2);
    resolvedPath = currentDir.isEmpty ? resolvedPath : '$currentDir/$resolvedPath';
  }
  
  // Add .dart extension if not present
  if (!resolvedPath.endsWith('.dart')) {
    resolvedPath += '.dart';
  }
  
  return resolvedPath;
}

void _printResults(Map<String, dynamic> analysis) {
  final entryPoints = analysis['entryPoints'] as List<String>;
  final directlyUsed = analysis['directlyUsed'] as List<String>;
  final indirectlyUsed = analysis['indirectlyUsed'] as List<String>;
  final unused = analysis['unused'] as List<String>;
  
  print('📌 ENTRY POINTS (${entryPoints.length}):');
  for (final file in entryPoints) {
    print('  ✅ $file');
  }
  
  print('\n🔗 DIRECTLY USED (${directlyUsed.length}):');
  for (final file in directlyUsed) {
    print('  ✅ $file');
  }
  
  print('\n🔗 INDIRECTLY USED (${indirectlyUsed.length}):');
  for (final file in indirectlyUsed) {
    print('  ✅ $file');
  }
  
  print('\n❌ UNUSED FILES (${unused.length}):');
  for (final file in unused) {
    print('  🗑️  $file');
  }
  
  final totalUsed = entryPoints.length + directlyUsed.length + indirectlyUsed.length;
  final totalFiles = totalUsed + unused.length;
  
  print('\n📈 SUMMARY:');
  print('  Total files: $totalFiles');
  print('  Used files: $totalUsed (${(totalUsed / totalFiles * 100).toStringAsFixed(1)}%)');
  print('  Unused files: ${unused.length} (${(unused.length / totalFiles * 100).toStringAsFixed(1)}%)');
  
  if (unused.isNotEmpty) {
    print('\n💡 RECOMMENDATIONS:');
    print('  Consider removing unused files to clean up the codebase.');
    print('  Before deleting, verify they are not used in:');
    print('    - Test files');
    print('    - Generated code');
    print('    - Dynamic imports');
    print('    - Platform-specific code');
  }
}