# Testing Checklist for UI Changes

## ✅ Bottom Navigation Bar

### Menu Button
- [ ] Menu button is visible on the left
- [ ] Clicking menu opens the sidebar drawer
- [ ] Menu icon is clearly visible
- [ ] Label "Menu" appears below icon

### Today Button
- [ ] Today button shows home icon
- [ ] Clicking "Today" navigates to news feed
- [ ] Button highlights in red when active
- [ ] Label "Today" appears below icon
- [ ] Returns to home screen from other tabs

### Date Selector
- [ ] Date shows current date by default (e.g., "Jan 15")
- [ ] Calendar icon is visible
- [ ] Clicking date opens calendar picker
- [ ] Calendar shows correct current date selected
- [ ] Can select dates from 2020 to present
- [ ] Cannot select future dates
- [ ] Selected date updates in bottom bar
- [ ] Today's date is highlighted in red
- [ ] Non-today dates show in grey

### Search Button
- [ ] Search icon is visible
- [ ] Clicking "Search" navigates to search tab
- [ ] Button highlights in red when active
- [ ] Label "Search" appears below icon
- [ ] Search functionality works

### Saved Button
- [ ] Bookmark icon is visible on the right
- [ ] Clicking "Saved" navigates to bookmarks tab
- [ ] Button highlights in red when active
- [ ] Label "Saved" appears below icon
- [ ] Shows saved articles correctly

### General Bottom Bar
- [ ] All 5 items are evenly spaced
- [ ] Bar has subtle shadow on top
- [ ] Bar respects safe area (notch/home indicator)
- [ ] Works in portrait orientation
- [ ] Works in landscape orientation
- [ ] Adapts to light theme
- [ ] Adapts to dark theme

---

## ✅ Sidebar Drawer

### Opening/Closing
- [ ] Drawer opens when menu button clicked
- [ ] Drawer slides in from left
- [ ] Can close by tapping outside drawer
- [ ] Can close by swiping left
- [ ] Animation is smooth

### Header
- [ ] NewsOn logo displays correctly
- [ ] "NEWS" appears in red box
- [ ] "ON" appears next to it
- [ ] Tagline "Your personalized news app" visible
- [ ] Header has red background

### Menu Items
- [ ] Home item visible with icon
- [ ] Categories item visible with icon
- [ ] Bookmarks item visible with icon
- [ ] Language item shows current language
- [ ] Theme item has toggle switch
- [ ] Settings item visible with icon
- [ ] About item visible with icon
- [ ] Dividers separate sections appropriately

### Functionality
- [ ] Home item closes drawer
- [ ] Language item opens language dialog
- [ ] Theme toggle switches theme immediately
- [ ] About item shows about dialog
- [ ] All items are tappable
- [ ] Tap feedback is visible

### Footer
- [ ] Version number displays at bottom
- [ ] Footer text is grey/muted

---

## ✅ Language Selection

### Top Bar Button
- [ ] Language button visible in top-right
- [ ] Shows globe icon
- [ ] Shows current language name
- [ ] Shows dropdown arrow icon
- [ ] Button has red background
- [ ] Text is white and readable
- [ ] Button is pill-shaped (rounded)

### Language Dialog
- [ ] Dialog opens when button clicked
- [ ] Dialog has red header
- [ ] "Select Language" title visible
- [ ] Close button (X) works
- [ ] All 10 languages listed
- [ ] Current language is pre-selected
- [ ] Radio buttons work correctly
- [ ] Can select different language
- [ ] Selected language highlights in red
- [ ] Cancel button closes dialog without changes
- [ ] Submit button applies selection
- [ ] Dialog closes after submit
- [ ] Confirmation snackbar appears
- [ ] Language persists after app restart

### Supported Languages
- [ ] English
- [ ] Hindi
- [ ] Spanish
- [ ] French
- [ ] German
- [ ] Chinese
- [ ] Japanese
- [ ] Arabic
- [ ] Portuguese
- [ ] Russian

---

## ✅ Calendar Date Picker

### Opening
- [ ] Opens when date in bottom bar clicked
- [ ] Calendar dialog appears
- [ ] Current date is pre-selected
- [ ] Calendar styled with red theme

### Date Selection
- [ ] Can navigate between months
- [ ] Can navigate between years
- [ ] Can select any date from 2020 onwards
- [ ] Cannot select future dates
- [ ] Selected date highlights
- [ ] OK button confirms selection
- [ ] Cancel button dismisses without change
- [ ] Selected date updates in bottom bar

### Display
- [ ] Calendar is readable
- [ ] Month/year header clear
- [ ] Navigation arrows work
- [ ] Today's date is marked
- [ ] Weekday labels visible

---

## ✅ Top Bar

### Logo
- [ ] "NEWS" in red box visible
- [ ] "ON" text visible next to it
- [ ] Logo aligned to left
- [ ] Logo size appropriate

### Language Button
- [ ] Button aligned to right
- [ ] Doesn't overlap with logo
- [ ] Visible in all screen sizes
- [ ] Tappable area adequate

### Removed Elements
- [ ] ✅ Date display removed (moved to bottom)
- [ ] ✅ Search icon removed (moved to bottom)

---

## ✅ Theme Compatibility

### Light Theme
- [ ] Bottom bar is white
- [ ] Icons are grey when inactive
- [ ] Active items are red
- [ ] Text is readable
- [ ] Shadows are subtle

### Dark Theme
- [ ] Bottom bar is dark grey
- [ ] Icons are light grey when inactive
- [ ] Active items are red
- [ ] Text is readable
- [ ] Contrast is sufficient
- [ ] Drawer adapts to dark theme
- [ ] Language dialog adapts to dark theme

---

## ✅ Navigation Flow

### Tab Switching
- [ ] Can switch between all tabs
- [ ] Active tab stays highlighted
- [ ] Content loads correctly
- [ ] No lag or stutter
- [ ] Back button behavior correct

### State Persistence
- [ ] Tab selection persists during session
- [ ] Language selection persists across restarts
- [ ] Bookmarks persist
- [ ] Theme preference persists

---

## ✅ Responsive Design

### Different Screen Sizes
- [ ] Works on small phones (iPhone SE)
- [ ] Works on standard phones (iPhone 12)
- [ ] Works on large phones (iPhone Pro Max)
- [ ] Works on tablets
- [ ] Bottom bar items don't overlap
- [ ] Text remains readable
- [ ] Icons maintain size

### Orientation
- [ ] Portrait mode works correctly
- [ ] Landscape mode works correctly
- [ ] Layout adapts appropriately

---

## ✅ Performance

### Animations
- [ ] Drawer slide animation smooth
- [ ] Tab switching is instant
- [ ] Dialog animations smooth
- [ ] No frame drops

### Loading
- [ ] App launches without errors
- [ ] Initial screen loads quickly
- [ ] Language loads from storage quickly
- [ ] No blocking operations

---

## ✅ Error Handling

### Edge Cases
- [ ] Works without internet connection
- [ ] Handles missing language preference
- [ ] Handles invalid date selection gracefully
- [ ] No crashes when rapidly switching tabs
- [ ] No crashes when rapidly opening/closing drawer

---

## ✅ Accessibility

### Visual
- [ ] Sufficient color contrast
- [ ] Icons are recognizable
- [ ] Text is readable
- [ ] Active states are clear

### Interaction
- [ ] Touch targets are adequate size (44x44 minimum)
- [ ] Buttons have visual feedback
- [ ] Gestures work reliably
- [ ] No accidental taps

---

## 🐛 Known Issues to Watch For

- [ ] Check if date picker works on older iOS versions
- [ ] Verify drawer doesn't interfere with TTS controls
- [ ] Ensure language dialog doesn't get cut off on small screens
- [ ] Test rapid switching between tabs
- [ ] Verify theme changes don't break layout

---

## 📝 Testing Notes

**Date Tested:** _________________

**Tested By:** _________________

**Device/Simulator:** _________________

**OS Version:** _________________

**Issues Found:**
- 
- 
- 

**Additional Comments:**
