# Background Music Integration

## Overview
This feature adds mild, gentle background music that plays alongside speech audio in the NewsOn app. The background music starts and stops automatically with the speech audio, creating a pleasant listening experience.

## Features
- **Automatic Control**: Background music starts when speech audio starts and stops when speech stops
- **Mild Volume**: Default volume is set to 15% to ensure it remains in the background
- **Independent Volume Control**: Users can adjust background music volume separately from speech volume
- **Visual Indicators**: UI shows when background music is playing
- **Looping**: Background music loops continuously during playback

## Implementation Details

### Files Modified/Created

#### New Files
- `lib/data/services/background_music_service.dart` - Core background music service
- `test/services/background_music_service_test.dart` - Unit tests for the service
- `docs/background_music_integration.md` - This documentation

#### Modified Files
- `lib/providers/audio_player_provider.dart` - Integrated background music control
- `lib/core/screens/audio_player/audio_player_screen.dart` - Added UI controls and indicators

### Key Components

#### BackgroundMusicService
- Singleton service that manages background music playback
- Uses just_audio for audio playback
- Default volume: 15% (0.15)
- Music source: "True Patriot" from chosic.com
- Supports play, pause, stop, resume, and volume control

#### AudioPlayerProvider Integration
- Automatically starts background music when speech begins
- Pauses background music when speech is paused
- Stops background music when speech stops or completes
- Provides getters for background music state and volume
- Independent volume control methods

#### UI Enhancements
- Volume dialog now includes separate controls for speech and background music
- Visual indicator shows when background music is playing
- Green color scheme for background music controls

### Usage

#### Automatic Behavior
```dart
// When speech starts - background music automatically starts
await audioPlayer.playArticle(article);

// When speech pauses - background music automatically pauses  
await audioPlayer.pause();

// When speech resumes - background music automatically resumes
await audioPlayer.resume();

// When speech stops - background music automatically stops
await audioPlayer.stop();
```

#### Manual Volume Control
```dart
// Set background music volume (0.0 to 1.0)
await audioPlayer.setBackgroundMusicVolume(0.2);

// Get current background music volume
final volume = audioPlayer.backgroundMusicVolume;

// Check if background music is playing
final isPlaying = audioPlayer.isBackgroundMusicPlaying;
```

### Audio Source
- Primary URL: https://www.chosic.com/wp-content/uploads/2022/10/True-Patriot(chosic.com).mp3
- The service can be easily configured to use local files or different URLs
- Music is set to loop continuously during playback

### Testing
Run the background music service tests:
```bash
flutter test test/services/background_music_service_test.dart
```

## Future Enhancements
- Multiple background music tracks
- User-selectable background music
- Background music genre selection
- Fade in/out effects
- Different volume profiles for different content types

## Troubleshooting

### Common Issues
1. **Background music not playing**: Check internet connection for URL-based music
2. **Volume too loud/quiet**: Use the volume controls in the audio player screen
3. **Music not stopping**: Ensure the app properly calls stop() method

### Debug Logs
The service logs all state changes with music note emojis (🎵) for easy identification in debug output.

## Dependencies
- just_audio: ^0.9.36 (already included in the project)
- No additional dependencies required
