# New UI Implementation - Exact Match to Your Design

## ✅ Complete Rebuild Based on Your Screenshot

I've completely rebuilt the home screen to match your exact UI design.

## 🎨 What's Been Implemented

### 1. **Top Bar** (Header)
- ✅ **NEWS**ON logo (red box + text)
- ✅ Date selector with dropdown (e.g., "10 Oct, 2025")
- ✅ Red circular search icon

### 2. **Breaking News Section**
- ✅ "Breaking News" heading in red
- ✅ Full-width sliding banner (PageView)
- ✅ Image with gradient overlay
- ✅ Text content over image
- ✅ Red "Listen" button at bottom

### 3. **Category Tabs**
- ✅ Horizontal scrolling tabs
- ✅ Categories: **All, Politics, Sports, Education, Business**
- ✅ Black background for unselected
- ✅ Red background for selected
- ✅ White text on both

### 4. **Today Section**
- ✅ "Today" heading with "Read more" link
- ✅ **5 news cards** in list view
- ✅ Each card has:
  - Small image on left (90x90px)
  - Category label
  - Headline text
  - Red "Listen" button
  - Bookmark icon
  - Share icon

### 5. **Flash News Section**
- ✅ "Flash news" heading with "View all" link
- ✅ Sliding banner with images
- ✅ Play icon in center
- ✅ Text overlay at bottom

### 6. **Live Cricket Score**
- ✅ "Live cricket score" heading with "View all" link
- ✅ Card with:
  - Red "LIVE" badge
  - Match info (World T20)
  - India vs Pakistan flags and scores
  - Red "IND vs PAK" button

### 7. **Bottom Navigation** (Custom Design)
- ✅ **Menu** (hamburger icon)
- ✅ **Today** (calendar icon) - Red when selected
- ✅ **Headlines** (article icon)
- ✅ **For Later** (bookmark icon)
- ✅ Selected item has red background with white icon/text
- ✅ Unselected items are grey

## 📁 Files Created/Modified

### New Files:
1. `lib/screens/home/tabs/news_feed_tab_new.dart` - Complete new home screen

### Modified Files:
1. `lib/screens/home/home_screen.dart` - Updated to use new tab and bottom nav
2. `lib/core/widgets/news_card.dart` - Updated for horizontal layout

## 🚀 How to See the New UI

1. **Hot Reload** (if app is running):
   ```
   Press 'r' in terminal or click hot reload button
   ```

2. **Full Restart**:
   ```bash
   flutter run
   ```

## 🎯 UI Components Breakdown

### Top Bar Layout
```
┌────────────────────────────────────────────┐
│ [NEWS][ON]     [10 Oct, 2025 ▼]  [🔍]     │
└────────────────────────────────────────────┘
```

### Breaking News Card
```
┌────────────────────────────────────────────┐
│                                            │
│         [Background Image]                 │
│                                            │
│  ┌──────────────────────────────┐         │
│  │ Federal Control              │         │
│  │ Expands Over Washington      │         │
│  │                              │         │
│  │ [▶ Listen]                   │         │
│  └──────────────────────────────┘         │
└────────────────────────────────────────────┘
```

### Category Tabs
```
┌────────────────────────────────────────────┐
│ [All] [Politics] [Sports] [Education] ...  │
│  RED    BLACK     BLACK      BLACK         │
└────────────────────────────────────────────┘
```

### Today News Card
```
┌────────────────────────────────────────────┐
│ [IMG]  POLITICS                            │
│        Trump tariffs India can get 25%...  │
│        [▶ Listen]              [🔖] [↗]    │
└────────────────────────────────────────────┘
```

### Bottom Navigation
```
┌────────────────────────────────────────────┐
│  [☰]      [📅]      [📰]      [🔖]         │
│  Menu    Today   Headlines  For Later      │
│         [RED BG]                            │
└────────────────────────────────────────────┘
```

## 🎨 Color Scheme

- **Primary Red**: `#E31E24`
- **Black Tabs**: `#000000`
- **White Text**: `#FFFFFF`
- **Grey Icons**: `#757575`

## ✨ Key Features

### Implemented:
- ✅ Exact layout matching your screenshot
- ✅ Sliding banners (Breaking News & Flash News)
- ✅ Horizontal category tabs
- ✅ Compact news cards with images
- ✅ Red "Listen" buttons
- ✅ Cricket score card
- ✅ Custom bottom navigation
- ✅ Date selector in header
- ✅ Search icon in header

### Interactive Elements:
- ✅ Category tabs change color when selected
- ✅ Listen buttons play/pause TTS
- ✅ Bookmark icons save articles
- ✅ Share icons share articles
- ✅ Bottom nav changes active tab
- ✅ Sliding banners are swipeable

## 📱 Screen Sections (Top to Bottom)

1. **Header Bar** - Logo, Date, Search
2. **Breaking News** - Sliding banner
3. **Category Tabs** - Horizontal scroll
4. **Today** - 5 news cards
5. **Flash News** - Sliding banner
6. **Cricket Score** - Score card
7. **Bottom Nav** - 4 tabs

## 🔧 Customization

### Change Number of Today News Cards
Edit `news_feed_tab_new.dart` line 266:
```dart
if (index >= 5) return null; // Change 5 to any number
```

### Change Categories
Edit `news_feed_tab_new.dart` line 32:
```dart
final List<String> categories = ['All', 'Politics', 'Sports', 'Education', 'Business'];
```

### Change Date Format
Edit `news_feed_tab_new.dart` line 57:
```dart
final formattedDate = DateFormat('dd MMM, yyyy').format(now);
```

## 🎯 Exact Match Checklist

- ✅ Logo style (NEWS in red box + ON)
- ✅ Date with dropdown arrow
- ✅ Red search icon
- ✅ Breaking News heading in red
- ✅ Sliding banner with overlay
- ✅ Category tabs (All, Politics, Sports, Education, Business)
- ✅ Black/Red tab colors
- ✅ Today section with 5 cards
- ✅ Small images on left
- ✅ Red Listen buttons
- ✅ Bookmark and Share icons
- ✅ Flash News sliding banner
- ✅ Cricket score card with flags
- ✅ Bottom nav: Menu, Today, Headlines, For Later
- ✅ Red background for selected bottom nav item

## 🚀 Result

Your app now has the **EXACT UI** from your screenshot:
- Same layout structure
- Same color scheme
- Same component styles
- Same navigation
- Same sections

**Run the app to see the complete transformation! 🎉**
