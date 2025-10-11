# NewsOn UI Features Guide

## Quick Reference Guide for New UI Features

### 🎯 Bottom Navigation Bar

The bottom bar now contains 5 interactive elements:

```
┌─────────────────────────────────────────────────────────────────┐
│  [Menu]  [Today]  [Categories]  [Search]  [Saved]              │
└─────────────────────────────────────────────────────────────────┘
```

#### 1. **Menu Button** (Left)
- **Icon:** Hamburger menu (☰)
- **Action:** Opens sidebar drawer
- **Label:** "Menu"

#### 2. **Today Button**
- **Icon:** Home icon
- **Action:** Shows today's news feed (main screen)
- **Label:** "Today"
- **State:** Highlighted in red when active

#### 3. **Categories Button** (Center)
- **Icon:** Category icon
- **Action:** Opens categories tab
- **Label:** "Categories"
- **State:** Highlighted in red when active

#### 4. **Search Button**
- **Icon:** Search icon
- **Action:** Opens search tab
- **Label:** "Search"
- **State:** Highlighted in red when active

#### 5. **Saved Button** (Right)
- **Icon:** Bookmark icon
- **Action:** Opens bookmarks/saved articles tab
- **Label:** "Saved"
- **State:** Highlighted in red when active

---

### 📱 Sidebar Menu

Access via the Menu button in the bottom bar.

**Contents:**
- **Header:** NewsOn branding with tagline
- **Navigation:**
  - 🏠 Home
  - 📂 Categories
  - 🔖 Bookmarks
  - 🌐 Language (shows current selection)
  - 🌓 Theme toggle (with switch)
  - ⚙️ Settings
  - ℹ️ About
- **Footer:** Version number

---

### 🌐 Language Selection

**Location:** Top-right corner of news feed

**Button Appearance:**
```
┌──────────────────────┐
│ 🌐 English ▼        │
└──────────────────────┘
```

**How to Use:**
1. Click the language button (red pill-shaped)
2. A dialog opens with language options
3. Select your preferred language (radio button)
4. Click "Submit" to confirm
5. Confirmation message appears

**Supported Languages:**
- English
- Hindi
- Spanish
- French
- German
- Chinese
- Japanese
- Arabic
- Portuguese
- Russian

**Features:**
- Selection persists across app restarts
- Accessible from sidebar menu as well
- Visual feedback with red highlighting

---

### 📅 Calendar Date Picker

**Access:** Click the date button in the top bar (to the left of language selector)

**Features:**
- Styled with app's red theme
- Date range: January 2020 to current date
- Shows selected date in top bar (e.g., "15 Jan")
- Black pill-shaped button with calendar icon
- Prepared for date-filtered news (future feature)

**Usage:**
1. Tap the date button in top bar
2. Calendar dialog opens
3. Select any date
4. Date updates in top bar
5. (Future: News will filter to selected date)

---

### 🎨 Top Bar Layout

**Left Side:** NewsOn logo
```
┌──────┐
│ NEWS │ ON
└──────┘
```

**Right Side:** Date selector + Language selector
```
┌────────────┐  ┌──────────────────┐
│ 📅 15 Jan  │  │ 🌐 English ▼    │
└────────────┘  └──────────────────┘
  (Black)           (Red)
```

**Date Selector (Black button):**
- Calendar icon + date text
- Opens calendar picker
- Updates when date selected

**Language Selector (Red button):**
- Globe icon + language name
- Opens language dialog
- Shows dropdown arrow

**Removed from Top Bar:**
- ❌ Search icon (moved to bottom bar)

---

## User Flow Examples

### Changing Language
1. Tap language button (top-right) or
2. Open sidebar → tap "Language" option
3. Select language from list
4. Tap "Submit"
5. See confirmation message

### Viewing News by Date
1. Tap date button in top bar (black button with calendar icon)
2. Select date from calendar
3. Date updates in top bar
4. (Future: News updates for that date)

### Accessing Saved Articles
1. Tap "Saved" in bottom bar
2. View all bookmarked articles

### Opening Menu
1. Tap "Menu" in bottom bar
2. Sidebar slides in from left
3. Access all app features

---

## Design Specifications

### Colors
- **Primary Red:** #E31E24
- **Active State:** Red highlight
- **Inactive State:** Grey (#757575)

### Typography
- **Bottom Bar Labels:** 10px
- **Language Button:** 12px, semi-bold
- **Active Items:** Bold weight

### Spacing
- Bottom bar padding: 8px vertical, 8px horizontal
- Item spacing: Evenly distributed
- Icon size: 24px

---

## Accessibility Features

- ✅ Clear visual feedback for active states
- ✅ Descriptive labels for all buttons
- ✅ High contrast colors
- ✅ Touch-friendly button sizes
- ✅ Consistent navigation patterns

---

## Notes for Developers

### State Management
- Language state: `LanguageProvider`
- Date selection: Local state in `HomeScreen`
- Navigation: `_currentIndex` in `HomeScreen`

### Persistence
- Language preference saved to Hive storage
- Survives app restarts

### Future Enhancements
- [ ] Implement date-filtered news API calls
- [ ] Add language-specific news sources
- [ ] Enhance sidebar navigation
- [ ] Add settings screen
