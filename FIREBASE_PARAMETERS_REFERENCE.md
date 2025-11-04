# Firebase Remote Config Parameters - Quick Reference

## 📋 Copy-Paste Ready Parameters

Use this as a quick reference when adding parameters in Firebase Console.

---

## 🎨 COLORS (Type: String)

### primary_color
```
Key: primary_color
Type: String
Value: #E31E24
Description: Primary brand color (red)
```

### secondary_color
```
Key: secondary_color
Type: String
Value: #2C2C2C
Description: Secondary color (dark gray)
```

### background_color
```
Key: background_color
Type: String
Value: #FFFFFF
Description: Light mode background color
```

### text_primary_color
```
Key: text_primary_color
Type: String
Value: #2C2C2C
Description: Primary text color
```

### text_secondary_color
```
Key: text_secondary_color
Type: String
Value: #757575
Description: Secondary text color (gray)
```

### card_background_color
```
Key: card_background_color
Type: String
Value: #FFFFFF
Description: Card background color
```

### dark_background_color
```
Key: dark_background_color
Type: String
Value: #121212
Description: Dark mode background color
```

---

## 📝 TEXT CONTENT (Type: String)

### app_name
```
Key: app_name
Type: String
Value: NewsOn
Description: Application name
```

### splash_welcome_text
```
Key: splash_welcome_text
Type: String
Value: WELCOME TO
Description: Splash screen welcome text
```

### splash_app_name_text
```
Key: splash_app_name_text
Type: String
Value: NEWSON
Description: Splash screen app name
```

### splash_swipe_text
```
Key: splash_swipe_text
Type: String
Value: Swipe To Get Started
Description: Swipe button text on splash
```

### no_internet_error
```
Key: no_internet_error
Type: String
Value: No internet connection. Please check your network.
Description: Error message for no internet
```

### server_error
```
Key: server_error
Type: String
Value: Server error. Please try again later.
Description: Error message for server issues
```

### unknown_error
```
Key: unknown_error
Type: String
Value: An unknown error occurred.
Description: Generic error message
```

### no_data_error
```
Key: no_data_error
Type: String
Value: No data available.
Description: Error message for no data
```

### bookmark_added
```
Key: bookmark_added
Type: String
Value: Added to bookmarks
Description: Success message for bookmark added
```

### bookmark_removed
```
Key: bookmark_removed
Type: String
Value: Removed from bookmarks
Description: Success message for bookmark removed
```

---

## 📏 FONT SIZES (Type: Number)

### splash_welcome_font_size
```
Key: splash_welcome_font_size
Type: Number
Value: 32
Description: Font size for splash welcome text
```

### splash_app_name_font_size
```
Key: splash_app_name_font_size
Type: Number
Value: 36
Description: Font size for splash app name
```

### splash_swipe_font_size
```
Key: splash_swipe_font_size
Type: Number
Value: 16
Description: Font size for swipe button text
```

### display_large_font_size
```
Key: display_large_font_size
Type: Number
Value: 32
Description: Display large text size
```

### display_medium_font_size
```
Key: display_medium_font_size
Type: Number
Value: 28
Description: Display medium text size
```

### display_small_font_size
```
Key: display_small_font_size
Type: Number
Value: 24
Description: Display small text size
```

### headline_medium_font_size
```
Key: headline_medium_font_size
Type: Number
Value: 20
Description: Headline medium text size
```

### title_large_font_size
```
Key: title_large_font_size
Type: Number
Value: 18
Description: Title large text size
```

### title_medium_font_size
```
Key: title_medium_font_size
Type: Number
Value: 16
Description: Title medium text size
```

### body_large_font_size
```
Key: body_large_font_size
Type: Number
Value: 16
Description: Body large text size
```

### body_medium_font_size
```
Key: body_medium_font_size
Type: Number
Value: 14
Description: Body medium text size
```

### body_small_font_size
```
Key: body_small_font_size
Type: Number
Value: 12
Description: Body small text size
```

---

## 💪 FONT WEIGHTS (Type: Number, Range: 100-900)

### splash_welcome_font_weight
```
Key: splash_welcome_font_weight
Type: Number
Value: 700
Description: Font weight for welcome text (bold)
Valid values: 100, 200, 300, 400, 500, 600, 700, 800, 900
```

### splash_app_name_font_weight
```
Key: splash_app_name_font_weight
Type: Number
Value: 800
Description: Font weight for app name (extra bold)
Valid values: 100, 200, 300, 400, 500, 600, 700, 800, 900
```

### splash_swipe_font_weight
```
Key: splash_swipe_font_weight
Type: Number
Value: 500
Description: Font weight for swipe button (medium)
Valid values: 100, 200, 300, 400, 500, 600, 700, 800, 900
```

**Font Weight Reference:**
- 100 = Thin
- 200 = Extra Light
- 300 = Light
- 400 = Normal/Regular
- 500 = Medium
- 600 = Semi Bold
- 700 = Bold
- 800 = Extra Bold
- 900 = Black

---

## 📐 UI DIMENSIONS (Type: Number)

### default_padding
```
Key: default_padding
Type: Number
Value: 16
Description: Default padding in pixels
```

### small_padding
```
Key: small_padding
Type: Number
Value: 8
Description: Small padding in pixels
```

### large_padding
```
Key: large_padding
Type: Number
Value: 24
Description: Large padding in pixels
```

### border_radius
```
Key: border_radius
Type: Number
Value: 12
Description: Border radius for cards and buttons
```

### card_elevation
```
Key: card_elevation
Type: Number
Value: 2
Description: Card elevation/shadow depth
```

### splash_button_height
```
Key: splash_button_height
Type: Number
Value: 64
Description: Splash screen button height in pixels
```

### splash_button_border_radius
```
Key: splash_button_border_radius
Type: Number
Value: 40
Description: Splash button border radius
```

---

## ⏱️ ANIMATION DURATIONS (Type: Number, in milliseconds)

### short_animation_duration
```
Key: short_animation_duration
Type: Number
Value: 200
Description: Short animation duration in milliseconds
```

### medium_animation_duration
```
Key: medium_animation_duration
Type: Number
Value: 300
Description: Medium animation duration in milliseconds
```

### long_animation_duration
```
Key: long_animation_duration
Type: Number
Value: 500
Description: Long animation duration in milliseconds
```

---

## 🔤 LETTER SPACING (Type: Number)

### splash_welcome_letter_spacing
```
Key: splash_welcome_letter_spacing
Type: Number
Value: 1.0
Description: Letter spacing for welcome text
```

### splash_app_name_letter_spacing
```
Key: splash_app_name_letter_spacing
Type: Number
Value: 1.2
Description: Letter spacing for app name
```

---

## 🎨 Popular Color Schemes

### Red Theme (Default)
```
primary_color: #E31E24
secondary_color: #2C2C2C
```

### Blue Theme
```
primary_color: #2196F3
secondary_color: #1976D2
```

### Green Theme
```
primary_color: #4CAF50
secondary_color: #388E3C
```

### Purple Theme
```
primary_color: #9C27B0
secondary_color: #7B1FA2
```

### Orange Theme
```
primary_color: #FF5722
secondary_color: #E64A19
```

### Teal Theme
```
primary_color: #009688
secondary_color: #00796B
```

### Pink Theme
```
primary_color: #E91E63
secondary_color: #C2185B
```

### Indigo Theme
```
primary_color: #3F51B5
secondary_color: #303F9F
```

---

## 📊 Parameter Summary

| Category | Count | Type |
|----------|-------|------|
| Colors | 7 | String |
| Text Content | 10 | String |
| Font Sizes | 12 | Number |
| Font Weights | 3 | Number |
| UI Dimensions | 7 | Number |
| Animations | 3 | Number |
| Letter Spacing | 2 | Number |
| **TOTAL** | **44** | - |

---

## 🔍 Parameter Naming Convention

All parameters follow this pattern:
- **Snake case**: `parameter_name`
- **Descriptive**: Clear purpose
- **Consistent**: Similar parameters grouped together

---

## ⚠️ Important Notes

### For Colors (String):
- Must start with `#`
- Use 6-digit hex format: `#RRGGBB`
- Example: `#FF5722` ✅
- Not: `FF5722` ❌

### For Font Weights (Number):
- Only use: 100, 200, 300, 400, 500, 600, 700, 800, 900
- Other values will default to 400 (normal)

### For Numbers:
- No quotes needed
- Whole numbers or decimals
- Example: `16` or `16.5`

### For Strings:
- Use quotes in JSON
- Plain text in Firebase Console UI
- Example: `"NewsOn"` in JSON, `NewsOn` in UI

---

## 🚀 Quick Add Script

If you prefer to add parameters programmatically, here's the structure:

```json
{
  "parameters": {
    "primary_color": {
      "defaultValue": {"value": "#E31E24"},
      "valueType": "STRING"
    },
    "splash_welcome_font_size": {
      "defaultValue": {"value": "32"},
      "valueType": "NUMBER"
    }
    // ... add more parameters
  }
}
```

---

## 📱 Testing Checklist

After adding parameters:
- [ ] All 44 parameters added
- [ ] All values are correct
- [ ] Published changes
- [ ] App restarted
- [ ] Changes visible in app
- [ ] No crashes
- [ ] Colors display correctly
- [ ] Text displays correctly
- [ ] Sizes are appropriate

---

## 🎯 Most Commonly Changed Parameters

1. **primary_color** - Brand color changes
2. **splash_welcome_text** - Welcome message
3. **splash_app_name_text** - App branding
4. **splash_welcome_font_size** - Text size adjustments
5. **no_internet_error** - Error message customization

---

**Last Updated:** October 22, 2024  
**Total Parameters:** 44  
**Ready to Use:** ✅
