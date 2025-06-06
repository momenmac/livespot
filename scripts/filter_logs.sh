#!/bin/bash

# Flutter Log Filter Script
# This script filters out common Firebase/Firestore cleanup logs that are not actual errors
# Usage: flutter run --verbose | bash filter_logs.sh

# Read from stdin and filter out non-essential Firebase logs
while IFS= read -r line; do
  # Skip Firebase connectivity manager cleanup logs
  if [[ "$line" == *"D/ConnectivityManager"* && "$line" == *"StackLog:"* ]]; then
    continue
  fi
  
  # Skip Firebase firestore shutdown logs
  if [[ "$line" == *"FirestoreClient.lambda"* ]]; then
    continue
  fi
  
  # Skip grpc channel shutdown logs
  if [[ "$line" == *"AndroidChannelBuilder"* && "$line" == *"shutdown"* ]]; then
    continue
  fi
  
  # Skip firebase analytics logs (unless they're errors)
  if [[ "$line" == *"firebase.analytics"* && "$line" != *"ERROR"* && "$line" != *"FATAL"* ]]; then
    continue
  fi
  
  # Print all other lines
  echo "$line"
done
