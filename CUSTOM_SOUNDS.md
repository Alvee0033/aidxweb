# Custom Notification Sounds Guide

## Overview
This guide explains how to add custom notification sounds to replace the default Google tuning sound in the MediGay app.

## Current Setup
The app is configured to use custom notification sounds instead of the default system sounds.

## Adding Custom Sounds

### 1. Sound File Requirements
- **Format**: MP3
- **Duration**: 1-3 seconds (recommended)
- **Size**: Under 100KB
- **Sample Rate**: 44.1kHz or 48kHz
- **Bitrate**: 128kbps or higher

### 2. File Placement
Place your sound files in the Android raw resources directory:
```
android/app/src/main/res/raw/
```

### 3. Naming Convention
- Use lowercase letters and underscores
- No spaces or special characters
- Example: `notification_sound.mp3`, `medication_reminder.mp3`, `emergency_alert.mp3`

### 4. Available Sound Types
You can create different sounds for different notification types:

#### Default Sound
- **File**: `notification_sound.mp3`
- **Used for**: General notifications

#### Medication Reminder Sound
- **File**: `medication_reminder.mp3`
- **Usage**: `showNotification(soundName: 'medication_reminder')`

#### Emergency Alert Sound
- **File**: `emergency_alert.mp3`
- **Usage**: `showNotification(soundName: 'emergency_alert')`

#### Health Tip Sound
- **File**: `health_tip.mp3`
- **Usage**: `showNotification(soundName: 'health_tip')`

## Recommended Sound Types

### For General Notifications
- Gentle chime or bell sound
- Soft beep or ping
- Calm and non-intrusive tone

### For Medication Reminders
- Gentle reminder chime
- Soft bell sound
- Medical-themed gentle tone

### For Emergency Alerts
- Attention-grabbing but not jarring
- Clear and distinct from other sounds
- Medical emergency tone

### For Health Tips
- Friendly and encouraging tone
- Light and positive sound
- Wellness-themed chime

## Where to Find Free Sounds

### Free Sound Resources
1. **Freesound.org** - Community-driven sound database
2. **Zapsplat.com** - Professional sound effects (free tier available)
3. **SoundBible.com** - Free sound effects
4. **OpenGameArt.org** - Free game assets including sounds

### Creating Your Own
- Use online tools like **Audacity** (free audio editor)
- Use **GarageBand** (Mac) or **FL Studio** (Windows)
- Use online sound generators

## Implementation Example

```dart
// Using default sound
notificationService.showNotification(
  title: 'Medication Reminder',
  body: 'Time to take your medicine',
);

// Using custom sound
notificationService.showNotification(
  title: 'Medication Reminder',
  body: 'Time to take your medicine',
  soundName: 'medication_reminder',
);
```

## Testing
1. Add your sound file to `android/app/src/main/res/raw/`
2. Rebuild the app: `flutter clean && flutter build apk`
3. Test notifications to hear your custom sound

## Troubleshooting

### Sound Not Playing
- Check file format (must be MP3)
- Verify file is in correct directory
- Ensure file name matches exactly (case-sensitive)
- Check file size (should be under 100KB)

### Sound Too Loud/Quiet
- Adjust the volume in your sound file
- Use audio editing software to normalize levels
- Test on different devices

### Multiple Sounds
- Each sound file should have a unique name
- Use descriptive names for easy identification
- Keep a list of available sounds for reference

## Current Sound Files
- `notification_sound.mp3` - Default notification sound (placeholder)
- Add more sounds as needed for different notification types

## Notes
- Sounds are only supported on Android
- iOS uses system sounds by default
- Test sounds on actual devices, not just emulators
- Consider user accessibility when choosing sounds 