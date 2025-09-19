#!/bin/bash

# Script to comment out problematic imports and code for APK build

echo "Fixing imports for APK build..."

# Comment out problematic imports
find lib -name "*.dart" -exec sed -i 's/^import.*flutter_blue_plus.*;/\/\/ &/' {} \;
find lib -name "*.dart" -exec sed -i 's/^import.*geolocator.*;/\/\/ &/' {} \;
find lib -name "*.dart" -exec sed -i 's/^import.*speech_to_text.*;/\/\/ &/' {} \;
find lib -name "*.dart" -exec sed -i 's/^import.*qr_code_scanner.*;/\/\/ &/' {} \;
find lib -name "*.dart" -exec sed -i 's/^import.*flutter_webrtc.*;/\/\/ &/' {} \;

echo "Import fixes completed!"
