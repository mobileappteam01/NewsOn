# ElevenLabs Audio Player Setup Guide

## Overview

The NewsOn app now includes a **Spotify-like audio player** powered by **ElevenLabs Text-to-Speech API**. This allows users to listen to news articles with high-quality, natural-sounding voices.

## Features

✅ **ElevenLabs TTS Integration** - High-quality text-to-speech conversion  
✅ **Spotify-like UI** - Beautiful mini player and full player screen  
✅ **Playback Controls** - Play, pause, seek, speed control, volume control  
✅ **Progress Tracking** - Real-time position and duration display  
✅ **Background Playback** - Continue listening while using other apps (coming soon)  
✅ **Multiple Voices** - Support for different ElevenLabs voices  

## Architecture

### Components

1. **ElevenLabsService** (`lib/data/services/elevenlabs_service.dart`)
   - Handles API calls to ElevenLabs TTS
   - Converts text to audio bytes
   - Manages voice selection

2. **AudioPlayerService** (`lib/data/services/audio_player_service.dart`)
   - Wraps `just_audio` for playback
   - Handles audio file management
   - Provides position/duration streams

3. **AudioPlayerProvider** (`lib/providers/audio_player_provider.dart`)
   - State management for audio playback
   - Coordinates between ElevenLabs and audio player
   - Manages current article and playback state

4. **AudioMiniPlayer** (`lib/core/widgets/audio_mini_player.dart`)
   - Bottom bar mini player (Spotify-like)
   - Shows current article info
   - Quick play/pause controls

5. **AudioPlayerScreen** (`lib/core/screens/audio_player/audio_player_screen.dart`)
   - Full-screen player with all controls
   - Progress bar with seeking
   - Speed and volume controls

## Setup Instructions

### 1. Get ElevenLabs API Key

1. Visit [ElevenLabs](https://elevenlabs.io/)
2. Sign up for an account
3. Go to your profile settings
4. Copy your API key

### 2. Configure API Key

You have two options:

#### Option A: Set in Code (Quick Start)

Edit `lib/main.dart` and update the AudioPlayerProvider initialization:

```dart
ChangeNotifierProvider(
  create: (_) => AudioPlayerProvider(
    elevenLabsApiKey: 'YOUR_ELEVENLABS_API_KEY_HERE',
  ),
),
```

#### Option B: Use Remote Config (Recommended)

1. Add to Firebase Remote Config:
   - Parameter: `elevenlabs_api_key`
   - Value: Your ElevenLabs API key

2. Update `lib/main.dart` to read from Remote Config:

```dart
// After Remote Config is initialized
final elevenLabsApiKey = remoteConfigProvider.remoteConfig.getString('elevenlabs_api_key');

ChangeNotifierProvider(
  create: (_) => AudioPlayerProvider(
    elevenLabsApiKey: elevenLabsApiKey.isNotEmpty ? elevenLabsApiKey : null,
  ),
),
```

### 3. Install Dependencies

The required packages are already added to `pubspec.yaml`:

- `just_audio: ^0.9.36` - Audio playback
- `audio_service: ^0.18.11` - Background playback support

Run:
```bash
flutter pub get
```

### 4. Update News Screens

Replace TTS provider calls with Audio Player provider:

**Before:**
```dart
context.read<TtsProvider>().playArticle(article);
```

**After:**
```dart
context.read<AudioPlayerProvider>().playArticle(article);
```

## Usage

### Playing an Article

```dart
final audioProvider = Provider.of<AudioPlayerProvider>(context);
await audioProvider.playArticle(article);
```

### Checking Playback State

```dart
if (audioProvider.isPlaying) {
  // Audio is playing
}

if (audioProvider.isArticlePlaying(article)) {
  // This specific article is playing
}
```

### Controlling Playback

```dart
// Play/Pause toggle
await audioProvider.togglePlayPause();

// Pause
await audioProvider.pause();

// Resume
await audioProvider.resume();

// Stop
await audioProvider.stop();

// Seek to position
await audioProvider.seek(Duration(seconds: 30));

// Set playback speed (0.25x to 2.0x)
await audioProvider.setPlaybackSpeed(1.5);

// Set volume (0.0 to 1.0)
await audioProvider.setVolume(0.8);
```

## UI Components

### Mini Player

The mini player automatically appears at the bottom of the screen when audio is playing. It shows:
- Article thumbnail
- Article title
- Source name
- Play/pause button
- Stop button

Tap the mini player to open the full player screen.

### Full Player Screen

The full player screen includes:
- Large article image
- Article title and source
- Progress bar with seeking
- Playback controls (play, pause, skip back/forward 10s)
- Speed control (0.5x to 2.0x)
- Volume control
- Share and bookmark buttons

## Customization

### Change Default Voice

Edit `lib/data/services/elevenlabs_service.dart`:

```dart
String _defaultVoiceId = 'YOUR_VOICE_ID'; // Change this
```

Or set dynamically:
```dart
audioProvider.setVoiceId('voice_id_here');
```

### Get Available Voices

```dart
final voices = await elevenLabsService.getVoices();
// voices is a list of ElevenLabsVoice objects
```

### Adjust Voice Settings

When calling `textToSpeech`, you can customize:

```dart
await _elevenLabsService.textToSpeech(
  text: text,
  stability: 0.5,        // Voice stability (0.0 to 1.0)
  similarityBoost: 0.75,  // Similarity to original voice
  style: 0.0,            // Style exaggeration
  useSpeakerBoost: true, // Enhance clarity
);
```

## Background Playback

Background playback support is planned. To enable it:

1. Configure `audio_service` for your platform
2. Update `AudioPlayerService` to use `AudioService` instead of direct `just_audio`
3. Add platform-specific configurations

## Troubleshooting

### Audio Not Playing

1. **Check API Key**: Ensure your ElevenLabs API key is correctly set
2. **Check Internet**: ElevenLabs requires internet connection
3. **Check API Quota**: Verify you haven't exceeded your API quota
4. **Check Logs**: Look for error messages in debug console

### Audio Cuts Off

- Check your ElevenLabs subscription tier (free tier has limits)
- Verify the article text isn't too long
- Check network connection stability

### Mini Player Not Showing

- Ensure `AudioMiniPlayer` is added to your screen's widget tree
- Check that `audioProvider.hasCurrentArticle` is true
- Verify the provider is properly initialized

## API Costs

ElevenLabs offers:
- **Free Tier**: 10,000 characters/month
- **Starter**: $5/month - 30,000 characters
- **Creator**: $22/month - 100,000 characters
- **Pro**: $99/month - 500,000 characters

Monitor your usage in the ElevenLabs dashboard.

## Next Steps

1. ✅ Add API key configuration
2. ✅ Test audio playback
3. ✅ Customize voice settings
4. ⏳ Add background playback support
5. ⏳ Add voice selection UI
6. ⏳ Add playback history
7. ⏳ Add download for offline playback

## Support

For issues or questions:
- Check ElevenLabs API documentation: https://elevenlabs.io/docs
- Check just_audio documentation: https://pub.dev/packages/just_audio
- Review app logs for error messages

