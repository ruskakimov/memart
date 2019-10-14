import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audio_cache.dart';
import 'package:audioplayers/audioplayers.dart';
import 'sound_data.dart';
import 'package:esys_flutter_share/esys_flutter_share.dart';

class AppModel extends ChangeNotifier {
  static const String LIKED_SOUND_PATH_KEY = 'likedSoundPaths';
  static const String SELECTED_SOUND_PATH_KEY = 'selectedSoundPath';
  SharedPreferences _prefs;
  List<String> _likedSoundPaths = [];
  AudioCache _audioCache;
  AudioPlayer _player;
  String selectedSoundPath;
  bool isPlaying = false;
  List<Map<String, String>> sounds;

  String searchString = '';

  AppModel() {
    _audioCache = AudioCache(prefix: 'sounds/');
    sounds = soundData;
    loadPrefs().then((_) {
      _likedSoundPaths = _prefs.getStringList(LIKED_SOUND_PATH_KEY) ?? [];
      selectedSoundPath =
          _prefs.getString(SELECTED_SOUND_PATH_KEY) ?? sounds[0]['soundPath'];
      notifyListeners();
    });
  }

  Future<void> loadPrefs() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<bool> play([String newSoundPath]) async {
    if (newSoundPath == null) return play(selectedSoundPath);
    if (selectedSoundPath != null && _player != null) await _player.stop();
    selectedSoundPath = newSoundPath;
    isPlaying = true;
    notifyListeners();
    _player = await _audioCache.play(newSoundPath);
    _player.onPlayerCompletion.listen((_) {
      isPlaying = false;
      notifyListeners();
    });
    return _prefs.setString(SELECTED_SOUND_PATH_KEY, selectedSoundPath);
  }

  Future<int> stop() async {
    isPlaying = false;
    notifyListeners();
    return _player.stop();
  }

  Future<bool> like(String soundPath) async {
    if (_likedSoundPaths.contains(soundPath)) return false;
    _likedSoundPaths.add(soundPath);
    notifyListeners();
    return _prefs.setStringList(LIKED_SOUND_PATH_KEY, _likedSoundPaths);
  }

  Future<bool> unlike(String soundPath) async {
    if (!_likedSoundPaths.contains(soundPath)) return false;
    _likedSoundPaths.remove(soundPath);
    notifyListeners();
    return _prefs.setStringList(LIKED_SOUND_PATH_KEY, _likedSoundPaths);
  }

  bool isLiked(String soundPath) {
    return _likedSoundPaths.contains(soundPath);
  }

  List<Map<String, String>> getLikedSounds() {
    return sounds.where((sound) => isLiked(sound['soundPath'])).toList();
    // iterate over _likedSounds and return a list
    // make a soundMap soundPath -> soundObject
  }

  String getSelectedSoundTitle() {
    if (selectedSoundPath == null) return null;
    return sounds.firstWhere(
        (sound) => sound['soundPath'] == selectedSoundPath)['title'];
  }

  List<Map<String, String>> getSearchResults(String input) {
    searchString = input;
    if (input.length == 0) return null;
    Set<String> resultsFileNames = Set();
    List<Map<String, String>> results = [];
    [
      {
        'searchProperty': 'title',
        'regex': r'^' + input,
      },
      {
        'searchProperty': 'title',
        'regex': r'\W' + input,
      },
      {
        'searchProperty': 'searchString',
        'regex': r'(^|\W)' + input,
      },
    ].forEach((searchRules) {
      var regex = RegExp(
        searchRules['regex'],
        caseSensitive: false,
      );

      sounds.forEach((sound) {
        var searchProperty = sound[searchRules['searchProperty']] ?? '';

        if (resultsFileNames.contains(sound['soundPath']) == false &&
            regex.hasMatch(searchProperty)) {
          results.add(sound);
          resultsFileNames.add(sound['soundPath']);
        }
      });
    });
    return results;
  }

  Future<void> share() async {
    var title = getSelectedSoundTitle();
    final ByteData bytes =
        await rootBundle.load('assets/sounds/$selectedSoundPath');
    await Share.file('Share "$title"', selectedSoundPath,
        bytes.buffer.asUint8List(), 'audio/mpeg',
        text: 'Shared with Memart.');
  }
}
