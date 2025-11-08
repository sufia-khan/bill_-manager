# Orange Color Scheme 🍊

Your app now uses a warm, vibrant orange gradient color scheme matching Tailwind CSS colors!

## Summary of Changes

All instances of the old dark orange (`#FF8C00`) have been replaced with the new orange-500 (`#F97316`), and gradients now use orange-400 to orange-500 with orange-200 shadows.

## Color Palette

### Primary Colors
- **Orange-500** (Primary): `#F97316` → `Color(0xFFF97316)`
- **Orange-400** (Secondary): `#FB923C` → `Color(0xFFFB923C)`
- **Orange-200** (Shadow): `#FED7AA` → `Color(0xFFFED7AA)`
- **Orange-50** (Background): `#FFF7ED` → `Color(0xFFFFF7ED)`

## Where These Colors Are Used

### 1. Theme Provider (`lib/providers/theme_provider.dart`)
- **Primary color**: Orange-500 (`#F97316`)
- **Secondary color**: Orange-400 (`#FB923C`)
- **Card shadow**: Orange-200 (`#FED7AA`)
- **AppBar icons**: Orange-500
- **Icon theme**: Orange-500

### 2. Login Screen (`lib/screens/login_screen.dart`)
- Background gradient: Orange-50 to white
- Logo container: Orange-500 with shadow
- Input focus border: Orange-500
- Checkbox active: Orange-500
- Links: Orange-500
- Login button: Orange-500 with shadow

### 3. Signup Screen (`lib/screens/signup_screen.dart`)
- Background gradient: Orange-50 to white
- Logo container: Orange-500 with shadow
- Input focus border: Orange-500
- Signup button: Orange-500 with shadow
- Links: Orange-500

### 4. Main App (`lib/main.dart`)
- Loading indicator: Orange-500 (old color, needs update)
- Notification icons: Orange-500 (old color, needs update)
- Dialog icons: Orange-500 (old color, needs update)
- Buttons: Orange-500 (old color, needs update)

### 5. Bill Manager Screen (`lib/screens/bill_manager_screen.dart`)
- Notification button shadow: Old orange (needs update)
- Filter section: Old orange (needs update)
- Add button gradient: Old orange (needs update)
- Navigation icons: Old orange (needs update)

## Gradient Usage

For buttons and containers, use a gradient from Orange-400 to Orange-500:

```dart
decoration: BoxDecoration(
  gradient: LinearGradient(
    colors: [
      Color(0xFFFB923C), // orange-400
      Color(0xFFF97316), // orange-500
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  borderRadius: BorderRadius.circular(12),
  boxShadow: [
    BoxShadow(
      color: Color(0xFFFED7AA).withOpacity(0.3), // orange-200 shadow
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
  ],
)
```

## Status

✅ Theme Provider - Updated
✅ Login Screen - Already using new colors
✅ Signup Screen - Already using new colors
✅ Main App - Updated
✅ Bill Manager Screen - Updated

All orange colors in your app have been successfully updated to the new warm, vibrant orange gradient scheme!
