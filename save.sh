#!/bin/bash
echo "Building..."
flutter build web --release
echo "Deploying..."
firebase deploy --only hosting
echo "Saving to GitHub..."
git add .
git commit -m "$1"
git push
echo "Done! https://hitlook-app.web.app"
