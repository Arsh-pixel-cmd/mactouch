/// Profile storage service for MacTouch.
///
/// Stores calibration profiles as versioned local JSON.
/// No network service or telemetry. Profiles are stored per-user
/// in a local file.
library;

import 'dart:convert';
import 'dart:io';
import '../models/calibration_profile.dart';

/// Current schema version for the profile store.
const int profileStoreVersion = 1;

/// Serializable store document.
class ProfileStoreDocument {
  final int version;
  final List<CalibrationProfile> profiles;

  const ProfileStoreDocument({
    required this.version,
    required this.profiles,
  });

  Map<String, dynamic> toJson() => {
        'version': version,
        'profiles': profiles.map((p) => p.toJson()).toList(),
      };

  factory ProfileStoreDocument.fromJson(Map<String, dynamic> json) {
    final version = json['version'] as int? ?? 1;
    final profilesJson = json['profiles'] as List<dynamic>? ?? [];
    return ProfileStoreDocument(
      version: version,
      profiles: profilesJson
          .map((p) => CalibrationProfile.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }

  factory ProfileStoreDocument.empty() =>
      const ProfileStoreDocument(version: profileStoreVersion, profiles: []);
}

/// Manages calibration profile persistence using local JSON files.
class ProfileStore {
  final String filePath;

  List<CalibrationProfile> _profiles = [];
  bool _loaded = false;

  ProfileStore(this.filePath);

  /// All stored profiles.
  List<CalibrationProfile> get profiles => List.unmodifiable(_profiles);

  /// Whether the store has been loaded from disk.
  bool get isLoaded => _loaded;

  /// Load profiles from the JSON file.
  ///
  /// Creates an empty store if the file doesn't exist.
  /// Returns error message if the file exists but can't be parsed.
  Future<String?> load() async {
    final file = File(filePath);
    if (!await file.exists()) {
      _profiles = [];
      _loaded = true;
      return null;
    }

    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final doc = ProfileStoreDocument.fromJson(json);

      // Version check — in future, migrate if needed.
      if (doc.version > profileStoreVersion) {
        return 'Profile store version ${doc.version} is newer than supported '
            'version $profileStoreVersion. Data may be incompatible.';
      }

      _profiles = doc.profiles.toList();
      _loaded = true;
      return null;
    } catch (e) {
      return 'Failed to load profiles: $e';
    }
  }

  /// Save all profiles to the JSON file.
  Future<String?> save() async {
    try {
      final doc = ProfileStoreDocument(
        version: profileStoreVersion,
        profiles: _profiles,
      );
      final file = File(filePath);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(doc.toJson()),
      );
      return null;
    } catch (e) {
      return 'Failed to save profiles: $e';
    }
  }

  /// Add a profile. Returns error if ID already exists.
  String? addProfile(CalibrationProfile profile) {
    if (_profiles.any((p) => p.id == profile.id)) {
      return 'Profile with ID "${profile.id}" already exists.';
    }
    _profiles.add(profile);
    return null;
  }

  /// Update an existing profile by ID. Returns error if not found.
  String? updateProfile(CalibrationProfile profile) {
    final index = _profiles.indexWhere((p) => p.id == profile.id);
    if (index < 0) {
      return 'Profile with ID "${profile.id}" not found.';
    }
    _profiles[index] = profile;
    return null;
  }

  /// Remove a profile by ID. Returns error if not found.
  String? removeProfile(String id) {
    final index = _profiles.indexWhere((p) => p.id == id);
    if (index < 0) {
      return 'Profile with ID "$id" not found.';
    }
    _profiles.removeAt(index);
    return null;
  }

  /// Get a profile by ID.
  CalibrationProfile? getProfile(String id) =>
      _profiles.where((p) => p.id == id).firstOrNull;

  /// Get profiles for a specific display.
  List<CalibrationProfile> profilesForDisplay(String displayId) =>
      _profiles.where((p) => p.displayId == displayId).toList();

  /// Remove all profiles and save.
  Future<String?> reset() async {
    _profiles = [];
    return save();
  }
}
