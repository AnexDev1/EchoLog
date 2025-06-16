import 'dart:convert'; // For jsonEncode and jsonDecode
import 'dart:io'; // For File operations
import 'dart:typed_data'; // For Uint8List

import 'package:archive/archive_io.dart'; // For ZipFileEncoder and ZipDecoder
import 'package:echolog/models/custom_category.dart';
import 'package:echolog/models/recording_entry.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p; // For path joining
import 'package:path_provider/path_provider.dart';

// Ensure this path is correct for your project structure
// Assuming HiveBoxNames is correctly defined and imported
import '../hive_box_names.dart'; // Adjust if your HiveBoxNames import is different

class DataExporter {
  // --- EXPORT DATA ---
  Future<void> exportData() async {
    Directory? tempDir;
    String? tempZipFilePath;
    Directory? stagingDir;

    try {
      tempDir = await getTemporaryDirectory();
      final stagingDirPath = p.join(tempDir.path, 'export_staging');
      stagingDir = Directory(stagingDirPath);
      if (await stagingDir.exists()) {
        await stagingDir.delete(recursive: true);
      }
      await stagingDir.create(recursive: true);

      // Directory for all audio files
      final audioFilesDir = Directory(p.join(stagingDirPath, 'audio_files'));
      await audioFilesDir.create();

      // Recordings
      final recordingsBox = Hive.box<RecordingEntry>(
        HiveBoxNames.recordingsBoxName,
      );
      if (recordingsBox.isOpen) {
        List<Map<String, dynamic>> recordingsJsonList = recordingsBox.values
            .map((entry) {
              final Map<String, dynamic> json = entry.toJson();
              if (entry.filePath.isNotEmpty) {
                json['filePath'] = p.basename(entry.filePath);
              }
              return json;
            })
            .toList();
        File recordingsJsonFile = File(
          p.join(stagingDirPath, 'recordings.json'),
        );
        await recordingsJsonFile.writeAsString(jsonEncode(recordingsJsonList));

        for (RecordingEntry entry in recordingsBox.values) {
          if (entry.filePath.isNotEmpty) {
            File sourceAudioFile = File(entry.filePath);
            if (await sourceAudioFile.exists()) {
              String targetFileName = p.basename(entry.filePath);
              await sourceAudioFile.copy(
                p.join(audioFilesDir.path, targetFileName),
              );
            } else {
              print(
                'Audio file not found for export ${entry.displayName}: ${entry.filePath}',
              );
            }
          }
        }
      }

      // Custom Categories
      final categoriesBox = Hive.box<CustomCategory>(
        HiveBoxNames.customCategoriesBoxName,
      );
      if (categoriesBox.isOpen) {
        List<Map<String, dynamic>> categoriesJsonList = categoriesBox.values
            .map((category) => category.toJson())
            .toList();
        File categoriesJsonFile = File(
          p.join(stagingDirPath, 'categories.json'),
        );
        await categoriesJsonFile.writeAsString(jsonEncode(categoriesJsonList));
      }

      // App Settings
      final appSettingsBox = Hive.box<String>(HiveBoxNames.appSettingsBoxName);
      if (appSettingsBox.isOpen && appSettingsBox.isNotEmpty) {
        File appSettingsJsonFile = File(
          p.join(stagingDirPath, 'app_settings.json'),
        );
        Map<String, String> settingsMap = {};
        appSettingsBox.toMap().forEach((key, value) {
          settingsMap[key.toString()] = value;
        });
        await appSettingsJsonFile.writeAsString(jsonEncode(settingsMap));
      }

      // Hidden Recordings
      final hiddenRecordingsBox = Hive.box<RecordingEntry>(
        HiveBoxNames.hiddenRecordingsBoxName,
      );
      if (hiddenRecordingsBox.isOpen) {
        List<Map<String, dynamic>> hiddenRecordingsJsonList =
            hiddenRecordingsBox.values.map((entry) {
              final Map<String, dynamic> json = entry.toJson();
              if (entry.filePath.isNotEmpty) {
                json['filePath'] = p.basename(entry.filePath);
              }
              return json;
            }).toList();
        File hiddenRecordingsJsonFile = File(
          p.join(stagingDirPath, 'hidden_recordings.json'),
        );
        await hiddenRecordingsJsonFile.writeAsString(
          jsonEncode(hiddenRecordingsJsonList),
        );

        for (RecordingEntry entry in hiddenRecordingsBox.values) {
          if (entry.filePath.isNotEmpty) {
            File sourceAudioFile = File(entry.filePath);
            if (await sourceAudioFile.exists()) {
              String targetFileName = p.basename(entry.filePath);
              // Check if file with same basename already exists from normal recordings to avoid error
              // This assumes if basenames collide, they are the same file or overwrite is acceptable.
              // For true safety, filenames in staging should be unique (e.g., using entry.id).
              File targetFile = File(
                p.join(audioFilesDir.path, targetFileName),
              );
              if (!await targetFile.exists() ||
                  (await targetFile.length()) !=
                      (await sourceAudioFile.length())) {
                await sourceAudioFile.copy(targetFile.path);
              }
            } else {
              print(
                'Audio file not found for export (hidden) ${entry.displayName}: ${entry.filePath}',
              );
            }
          }
        }
      }

      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final zipFileName = 'echolog_backup_$timestamp.zip';
      tempZipFilePath = p.join(tempDir.path, zipFileName);

      var encoder = ZipFileEncoder();
      encoder.create(tempZipFilePath);
      await encoder.addDirectory(stagingDir, includeDirName: false);
      encoder.close();

      final File tempZipFile = File(tempZipFilePath);
      if (!await tempZipFile.exists()) {
        throw Exception('Temporary ZIP file was not created.');
      }
      final Uint8List zipBytes = await tempZipFile.readAsBytes();

      String? finalOutputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Echolog Backup',
        fileName: zipFileName,
        bytes:
            zipBytes, // Pass bytes directly if API supports it, otherwise use path
        // For older file_picker versions, you might need to write to a temp file first
        // and pass the path, but `bytes` is preferred if available.
      );

      if (finalOutputPath == null) {
        // User cancelled picker
        print('Export cancelled by user.');
        // No need to throw an exception if user cancellation is an acceptable outcome
        return; // Or throw if it must be treated as an error
      }
      // If saveFile doesn't write the bytes directly and returns a path where to save:
      // await File(finalOutputPath).writeAsBytes(zipBytes); // Uncomment if finalOutputPath is a target path

      print('Export successful! Data saved to $finalOutputPath');
    } catch (e, s) {
      print('Export failed: $e');
      print('Stack trace: $s');
      throw Exception('Data export failed: ${e.toString()}');
    } finally {
      try {
        if (stagingDir != null && await stagingDir.exists()) {
          await stagingDir.delete(recursive: true);
        }
        if (tempZipFilePath != null) {
          final tempFile = File(tempZipFilePath);
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        }
      } catch (e) {
        print('Error during export cleanup: $e');
      }
    }
  }

  // --- IMPORT DATA ---
  Future<String> importData() async {
    Directory? tempExtractDir;
    int importedRecordingsCount = 0;
    int duplicateRecordingsCount = 0;
    int importedCategoriesCount = 0;
    int duplicateCategoriesCount = 0;
    int importedHiddenRecordingsCount = 0;
    int duplicateHiddenRecordingsCount = 0;
    int appSettingsProcessedCount = 0;

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result == null ||
          result.files.single.path == null ||
          result.files.single.path!.isEmpty) {
        return 'Import cancelled: No file selected.';
      }
      File zipFile = File(result.files.single.path!);

      final Directory tempDir = await getTemporaryDirectory();
      tempExtractDir = Directory(
        p.join(tempDir.path, 'import_extract_staging'),
      );
      if (await tempExtractDir.exists()) {
        await tempExtractDir.delete(recursive: true);
      }
      await tempExtractDir.create(recursive: true);

      final archive = ZipDecoder().decodeBytes(await zipFile.readAsBytes());
      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final data = file.content as List<int>;
          final extractedFile = File(p.join(tempExtractDir.path, filename));
          await extractedFile.parent.create(recursive: true);
          await extractedFile.writeAsBytes(data);
        } else {
          await Directory(
            p.join(tempExtractDir.path, filename),
          ).create(recursive: true);
        }
      }
      print('ZIP file extracted to temporary directory.');

      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final Directory importedAudioTargetDir = Directory(
        p.join(appDocDir.path, 'imported_audio_recordings'),
      );
      if (!await importedAudioTargetDir.exists()) {
        await importedAudioTargetDir.create(recursive: true);
      }

      // Process recordings.json
      final recordingsJsonFile = File(
        p.join(tempExtractDir.path, 'recordings.json'),
      );
      if (await recordingsJsonFile.exists()) {
        final recordingsBox = Hive.box<RecordingEntry>(
          HiveBoxNames.recordingsBoxName,
        );
        final List<dynamic> recordingsJsonList = jsonDecode(
          await recordingsJsonFile.readAsString(),
        );

        for (var itemJson in recordingsJsonList) {
          if (itemJson is Map<String, dynamic>) {
            final RecordingEntry newEntry = RecordingEntry.fromJson(itemJson);
            bool isDuplicate = recordingsBox.values.any(
              (e) => e.id == newEntry.id,
            );

            if (isDuplicate) {
              duplicateRecordingsCount++;
            } else {
              if (newEntry.filePath.isNotEmpty) {
                final String audioFileName = p.basename(
                  newEntry.filePath,
                ); // Ensure it's a basename
                final File sourceAudioFile = File(
                  p.join(tempExtractDir.path, 'audio_files', audioFileName),
                );

                if (await sourceAudioFile.exists()) {
                  final String targetAudioPath = p.join(
                    importedAudioTargetDir.path,
                    audioFileName,
                  );
                  try {
                    await sourceAudioFile.copy(targetAudioPath);
                    newEntry.filePath = targetAudioPath;
                  } catch (e) {
                    print(
                      'Error copying audio file $audioFileName for recording ${newEntry.id}: $e',
                    );
                    newEntry.filePath = ''; // Clear path on copy error
                  }
                } else {
                  print(
                    'Warning: Audio file $audioFileName for recording ${newEntry.id} not found in zip.',
                  );
                  newEntry.filePath = '';
                }
              }
              await recordingsBox.put(newEntry.id, newEntry);
              importedRecordingsCount++;
            }
          }
        }
      } else {
        print('recordings.json not found in the backup.');
      }

      // Process categories.json
      final categoriesJsonFile = File(
        p.join(tempExtractDir.path, 'categories.json'),
      );
      if (await categoriesJsonFile.exists()) {
        final categoriesBox = Hive.box<CustomCategory>(
          HiveBoxNames.customCategoriesBoxName,
        );
        final List<dynamic> categoriesJsonList = jsonDecode(
          await categoriesJsonFile.readAsString(),
        );

        for (var itemJson in categoriesJsonList) {
          if (itemJson is Map<String, dynamic>) {
            final CustomCategory newCategory = CustomCategory.fromJson(
              itemJson,
            );
            bool isDuplicate = categoriesBox.values.any(
              (c) => c.id == newCategory.id,
            ); // Assuming 'id' is the unique key

            if (isDuplicate) {
              duplicateCategoriesCount++;
            } else {
              await categoriesBox.put(newCategory.id, newCategory);
              importedCategoriesCount++;
            }
          }
        }
      } else {
        print('categories.json not found in the backup.');
      }

      // Process app_settings.json
      final appSettingsJsonFile = File(
        p.join(tempExtractDir.path, 'app_settings.json'),
      );
      if (await appSettingsJsonFile.exists()) {
        final appSettingsBox = Hive.box<String>(
          HiveBoxNames.appSettingsBoxName,
        );
        final Map<String, dynamic> settingsMap = jsonDecode(
          await appSettingsJsonFile.readAsString(),
        );
        settingsMap.forEach((key, value) {
          if (value is String) {
            appSettingsBox.put(key, value);
            appSettingsProcessedCount++;
          }
        });
        print('$appSettingsProcessedCount app settings processed.');
      } else {
        print('app_settings.json not found in the backup.');
      }

      // Process hidden_recordings.json
      final hiddenRecordingsJsonFile = File(
        p.join(tempExtractDir.path, 'hidden_recordings.json'),
      );
      if (await hiddenRecordingsJsonFile.exists()) {
        final hiddenRecordingsBox = Hive.box<RecordingEntry>(
          HiveBoxNames.hiddenRecordingsBoxName,
        );
        final List<dynamic> hiddenRecordingsJsonList = jsonDecode(
          await hiddenRecordingsJsonFile.readAsString(),
        );

        for (var itemJson in hiddenRecordingsJsonList) {
          if (itemJson is Map<String, dynamic>) {
            final RecordingEntry newEntry = RecordingEntry.fromJson(itemJson);
            bool isDuplicate = hiddenRecordingsBox.values.any(
              (e) => e.id == newEntry.id,
            );

            if (isDuplicate) {
              duplicateHiddenRecordingsCount++;
            } else {
              if (newEntry.filePath.isNotEmpty) {
                final String audioFileName = p.basename(newEntry.filePath);
                final File sourceAudioFile = File(
                  p.join(tempExtractDir.path, 'audio_files', audioFileName),
                );

                if (await sourceAudioFile.exists()) {
                  final String targetAudioPath = p.join(
                    importedAudioTargetDir.path,
                    audioFileName,
                  );
                  try {
                    // Avoid re-copy if file already exists from normal recordings import
                    if (!await File(targetAudioPath).exists()) {
                      await sourceAudioFile.copy(targetAudioPath);
                    }
                    newEntry.filePath = targetAudioPath;
                  } catch (e) {
                    print(
                      'Error copying audio file $audioFileName for hidden recording ${newEntry.id}: $e',
                    );
                    newEntry.filePath = '';
                  }
                } else {
                  print(
                    'Warning: Audio file $audioFileName for hidden recording ${newEntry.id} not found in zip.',
                  );
                  newEntry.filePath = '';
                }
              }
              await hiddenRecordingsBox.put(newEntry.id, newEntry);
              importedHiddenRecordingsCount++;
            }
          }
        }
      } else {
        print('hidden_recordings.json not found in the backup.');
      }

      String summary =
          'Import completed.\n'
          'Recordings: $importedRecordingsCount imported, $duplicateRecordingsCount duplicates skipped.\n'
          'Categories: $importedCategoriesCount imported, $duplicateCategoriesCount duplicates skipped.\n'
          'Hidden Recordings: $importedHiddenRecordingsCount imported, $duplicateHiddenRecordingsCount duplicates skipped.\n'
          'App Settings: $appSettingsProcessedCount processed.';
      print(summary);
      return summary;
    } catch (e, s) {
      print('Import failed: $e');
      print('Stack trace: $s');
      // It's better to throw a specific exception or return an error message
      // that can be displayed to the user.
      return 'Import failed: ${e.toString()}';
    } finally {
      try {
        if (tempExtractDir != null && await tempExtractDir.exists()) {
          await tempExtractDir.delete(recursive: true);
          print('Cleaned up temporary import extraction directory.');
        }
      } catch (e) {
        print('Error during import cleanup: $e');
      }
    }
  }
}
