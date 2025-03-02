# Firebase Integration Guide

This document outlines the steps needed to integrate Firebase into the messaging application.

## Prerequisites

1. Create a Firebase project in the [Firebase Console](https://console.firebase.google.com/)
2. Register your app with Firebase
3. Download and add the Firebase configuration files:
   - For Android: `google-services.json` to `android/app/`
   - For iOS: `GoogleService-Info.plist` to the iOS project using Xcode

## Dependencies to Add

Add these dependencies to your `pubspec.yaml`:
