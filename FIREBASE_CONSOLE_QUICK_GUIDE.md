# Firebase Console Quick Setup Guide

## 🎯 Quick Steps to Configure Remote Config

### Step 1: Access Remote Config
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your **NewsOn** project
3. Click **"Remote Config"** in the left sidebar
4. Click **"Create configuration"** or **"Get started"**

### Step 2: Import Configuration Template

**Option A: Import JSON File (Fastest)**
1. Click the **three dots menu** (⋮) in the top right
2. Select **"Download current config"** to see the format
3. Click **"Publish from file"** or **"Import from file"**
4. Select the `firebase_remote_config_template.json` file from your project
5. Review the parameters
6. Click **"Publish changes"**

**Option B: Add Parameters Manually**

Click **"Add parameter"** for each of the following:

---

## 📝 Parameters to Add

### 🎨 **Color Parameters** (Type: String)

```
Parameter: primary_color
Value: #E31E24
Description: Primary app color
```

```
Parameter: secondary_color
Value: #2C2C2C
Description: Secondary color
```

```
Parameter: background_color
Value: #FFFFFF
Description: Background color
```

```
Parameter: text_primary_color
Value: #2C2C2C
Description: Primary text color
```

```
Parameter: text_secondary_color
Value: #757575
Description: Secondary text color
```

```
Parameter: card_background_color
Value: #FFFFFF
Description: Card background
```

```
Parameter: dark_background_color
Value: #121212
Description: Dark mode background
```

---

### 📱 **Splash Screen Text** (Type: String)

```
Parameter: app_name
Value: NewsOn
Description: App name
```

```
Parameter: splash_welcome_text
Value: WELCOME TO
Description: Splash welcome text
```

```
Parameter: splash_app_name_text
Value: NEWSON
Description: Splash app name
```

```
Parameter: splash_swipe_text
Value: Swipe To Get Started
Description: Swipe button text
```

---

### 📏 **Font Sizes** (Type: Number)

```
Parameter: splash_welcome_font_size
Value: 32
Description: Splash welcome size
```

```
Parameter: splash_app_name_font_size
Value: 36
Description: Splash app name size
```

```
Parameter: splash_swipe_font_size
Value: 16
Description: Swipe button size
```

```
Parameter: display_large_font_size
Value: 32
```

```
Parameter: display_medium_font_size
Value: 28
```

```
Parameter: display_small_font_size
Value: 24
```

```
Parameter: headline_medium_font_size
Value: 20
```

```
Parameter: title_large_font_size
Value: 18
```

```
Parameter: title_medium_font_size
Value: 16
```

```
Parameter: body_large_font_size
Value: 16
```

```
Parameter: body_medium_font_size
Value: 14
```

```
Parameter: body_small_font_size
Value: 12
```

---

### 💪 **Font Weights** (Type: Number, Range: 100-900)

```
Parameter: splash_welcome_font_weight
Value: 700
Description: Bold
```

```
Parameter: splash_app_name_font_weight
Value: 800
Description: Extra bold
```

```
Parameter: splash_swipe_font_weight
Value: 500
Description: Medium
```

---

### 📐 **UI Dimensions** (Type: Number)

```
Parameter: default_padding
Value: 16
```

```
Parameter: small_padding
Value: 8
```

```
Parameter: large_padding
Value: 24
```

```
Parameter: border_radius
Value: 12
```

```
Parameter: card_elevation
Value: 2
```

```
Parameter: splash_button_height
Value: 64
```

```
Parameter: splash_button_border_radius
Value: 40
```

---

### 💬 **Messages** (Type: String)

```
Parameter: no_internet_error
Value: No internet connection. Please check your network.
```

```
Parameter: server_error
Value: Server error. Please try again later.
```

```
Parameter: unknown_error
Value: An unknown error occurred.
```

```
Parameter: no_data_error
Value: No data available.
```

```
Parameter: bookmark_added
Value: Added to bookmarks
```

```
Parameter: bookmark_removed
Value: Removed from bookmarks
```

---

### ⏱️ **Animation Durations** (Type: Number, in milliseconds)

```
Parameter: short_animation_duration
Value: 200
```

```
Parameter: medium_animation_duration
Value: 300
```

```
Parameter: long_animation_duration
Value: 500
```

---

### 🔤 **Letter Spacing** (Type: Number)

```
Parameter: splash_welcome_letter_spacing
Value: 1.0
```

```
Parameter: splash_app_name_letter_spacing
Value: 1.2
```

---

## 🎨 Example Customizations

### Change to Blue Theme:
```
primary_color: #2196F3
secondary_color: #1976D2
```

### Change to Green Theme:
```
primary_color: #4CAF50
secondary_color: #388E3C
```

### Change to Purple Theme:
```
primary_color: #9C27B0
secondary_color: #7B1FA2
```

### Make Text Larger:
```
splash_welcome_font_size: 40
splash_app_name_font_size: 44
```

### Change Welcome Message:
```
splash_welcome_text: HELLO FROM
splash_app_name_text: NEWS APP
```

---

## 🚀 After Adding Parameters

1. Click **"Publish changes"** button (top right)
2. Confirm the publication
3. Your app will fetch these values on next launch

---

## 🔄 Testing Changes

1. Make a change in Firebase Console
2. Click **"Publish changes"**
3. **Force close** your app completely
4. **Reopen** the app
5. Changes should appear!

**Note:** By default, the app fetches new config every 1 hour. For immediate testing, restart the app.

---

## 📊 Monitoring

In Firebase Console, you can see:
- **Active config**: Currently published values
- **Draft config**: Unpublished changes
- **Version history**: Previous configurations
- **Fetch metrics**: How many users fetched config

---

## 🎯 Pro Tips

### 1. Use Conditions for A/B Testing
- Create different values for different user segments
- Test different color schemes
- Try different messaging

### 2. Gradual Rollout
- Roll out changes to 10% of users first
- Monitor feedback
- Gradually increase to 100%

### 3. Platform-Specific Values
- Set different colors for Android vs iOS
- Customize text per platform

### 4. Version Targeting
- Show different content for different app versions
- Promote updates to old versions

---

## ⚠️ Important Notes

- **String values**: Use quotes for text
- **Number values**: No quotes needed
- **Hex colors**: Must start with # (e.g., #FF5722)
- **Font weights**: Use values 100-900 (100, 200, 300, 400, 500, 600, 700, 800, 900)
- **Always publish**: Changes won't take effect until published

---

## 🆘 Troubleshooting

**Changes not showing?**
- Did you click "Publish changes"?
- Did you restart the app?
- Check internet connection
- Wait for fetch interval (1 hour default)

**App crashes?**
- Verify all number values are valid numbers
- Check hex colors have # prefix
- Ensure font weights are 100-900

**Colors look wrong?**
- Use 6-digit hex format: #RRGGBB
- Example: #FF5722 (not FF5722)

---

## 📱 Quick Test Checklist

- [ ] All parameters added
- [ ] Published changes
- [ ] App restarted
- [ ] Changes visible in app
- [ ] No crashes
- [ ] Colors look correct
- [ ] Text displays properly
- [ ] Sizes are appropriate

---

**Ready to go!** 🎉 Your app is now fully dynamic and controlled from Firebase Console.
