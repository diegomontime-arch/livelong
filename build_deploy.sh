#!/bin/bash
echo "Building HitLook..."
flutter build web --release --dart-define=ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY
echo "Deploying to Firebase..."
firebase deploy --only hosting
echo "Done! https://hitlook-app.web.app"
