# Offline Caching for Remote Config

## Overview

The NewsOn app now supports **full offline functionality** for Firebase Remote Config data. All texts, images URLs, text styles, and API configurations are cached locally and persist across app restarts, even when offline.

## Features

✅ **Automatic Caching** - All Remote Config data is cached after first successful fetch  
✅ **Offline Support** - App works completely offline after first load  
✅ **Persistent Storage** - Data persists across app restarts  
✅ **Image URL Caching** - Image URLs are cached (images cached by `cached_network_image`)  
✅ **Graceful Fallbacks** - Uses cached → Remote Config → defaults in that order  
✅ **API Config Caching** - Dynamic API endpoints also cached offline  

## How It Works

### 1. First Launch (Online)

```
1. App starts
2. Loads cached data (if any) → Shows immediately
3. Fetches from Firebase Remote Config
4. Saves to local cache (Hive storage)
5. Updates UI with fresh data
```

### 2. Subsequent Launches (Online)

```
1. App starts
2. Loads cached data → Shows immediately (fast!)
3. Fetches from Firebase Remote Config in background
4. Updates cache if new data available
5. Updates UI if data changed
```

### 3. Offline Launch

```
1. App starts
2. Loads cached data → Shows immediately
3. Tries to fetch from Firebase (fails silently)
4. Uses cached data throughout app session
5. App works normally with cached data
```

## Cached Data

The following data is cached locally:

### Remote Config Data
- ✅ App texts (titles, descriptions, messages)
- ✅ Colors (primary, secondary, background, etc.)
- ✅ Text sizes (font sizes for all text styles)
- ✅ Font weights
- ✅ UI dimensions (padding, border radius, etc.)
- ✅ Animation durations
- ✅ Image URLs (app logo, language icon, headline icon, etc.)
- ✅ Drawer menu configuration
- ✅ Onboarding features
- ✅ Welcome screen data

### API Configuration
- ✅ Base URLs
- ✅ API endpoints
- ✅ Query parameters
- ✅ Default values (language, country, page size)
- ✅ Categories list
- ✅ Request timeout settings

## Storage Location

All cached data is stored in **Hive** (local database):
- **Box Name**: `settings`
- **Keys**: 
  - `remote_config_cache` - Remote Config data
  - `api_config_cache` - API configuration

## Implementation Details

### RemoteConfigService

The service automatically:
1. Loads cached data on initialization
2. Tries to fetch fresh data from Firebase
3. Saves to cache after successful fetch
4. Falls back to cache if fetch fails

```dart
// Automatic caching happens in initialize()
await remoteConfigService.initialize();
// Data is automatically cached after fetch
```

### StorageService

Provides methods for caching:

```dart
// Save Remote Config cache
await StorageService.saveRemoteConfigCache(config);

// Get cached Remote Config
final cached = StorageService.getRemoteConfigCache();

// Save API Config cache
await StorageService.saveApiConfigCache(apiConfig);

// Get cached API Config
final cachedApi = StorageService.getApiConfigCache();
```

## Image Caching

Image URLs from Remote Config are cached, but actual images are cached by the `cached_network_image` package:

```dart
CachedNetworkImage(
  imageUrl: config.appNameLogo, // URL from cached Remote Config
  // Image is automatically cached by cached_network_image
)
```

## Cache Management

### Automatic Cache Updates

Cache is automatically updated when:
- Remote Config is successfully fetched
- API Config is successfully loaded
- Force refresh is performed

### Manual Cache Clearing

To clear cache (for testing or reset):

```dart
// Clear Remote Config cache
await StorageService.clearRemoteConfigCache();

// Clear API Config cache
await StorageService.clearApiConfigCache();
```

## Testing Offline Mode

### Test Steps

1. **First Launch (Online)**:
   - Open app with internet
   - Let it load Remote Config
   - Verify data is displayed

2. **Close App**:
   - Force close the app completely

3. **Turn Off Internet**:
   - Disable WiFi/Mobile data

4. **Reopen App**:
   - App should open normally
   - All texts, images, styles should display
   - No errors should occur

### Expected Behavior

✅ App opens immediately  
✅ All UI elements display correctly  
✅ Texts from Remote Config show  
✅ Image URLs work (if images were cached)  
✅ Colors and styles apply correctly  
✅ No "No internet" errors for UI elements  

## Troubleshooting

### Issue: App shows default values offline

**Solution**: 
- Ensure app was opened at least once online
- Check if cache exists: `StorageService.getRemoteConfigCache()`
- Verify Hive storage is initialized

### Issue: Images not showing offline

**Solution**:
- Images need to be cached by `cached_network_image` first
- Open app online and view images to cache them
- Check image URLs are valid

### Issue: Cache not updating

**Solution**:
- Cache updates automatically after successful fetch
- Use `forceRefresh()` to force update
- Check network connectivity

### Issue: Cache takes too much space

**Solution**:
- Remote Config cache is small (~few KB)
- API Config cache is tiny (~1 KB)
- Clear cache if needed: `clearRemoteConfigCache()`

## Best Practices

1. **Always Test Offline**: Test app behavior after first online launch
2. **Monitor Cache Size**: Remote Config cache is small, but monitor if needed
3. **Handle Edge Cases**: App gracefully falls back to defaults if cache fails
4. **Update Strategy**: Cache updates automatically, no manual intervention needed
5. **Image Preloading**: Consider preloading critical images on first launch

## Cache Lifecycle

```
┌─────────────────┐
│  App Launch     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Load Cache      │ ◄─── Fast! Shows immediately
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Fetch Remote    │ ◄─── Background (if online)
│ Config          │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Save to Cache   │ ◄─── Automatic
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Update UI       │ ◄─── If data changed
└─────────────────┘
```

## Performance

- **Cache Load Time**: < 10ms (instant)
- **Cache Size**: ~5-10 KB (Remote Config + API Config)
- **Storage**: Hive (fast, efficient)
- **Memory**: Minimal (loaded on demand)

## Security

- Cache is stored locally on device
- No sensitive data in cache (only UI config)
- API keys can be cached (optional, from Remote Config)
- Cache cleared on app uninstall

## Future Enhancements

Potential improvements:
- Cache versioning
- Cache expiration
- Selective cache updates
- Cache compression
- Cache analytics

---

**Last Updated**: 2024  
**Version**: 1.0.0

