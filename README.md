# LiveSpot 📍

A cross-platform Flutter application for location-based news tracking and social engagement. LiveSpot enables users to discover, share, and interact with news and events happening around them in real-time.

## 🌟 Features

### Core Features

- **Location-Based News Feed**: Track news and events happening around your current location
- **Real-Time Messaging**: Chat with other users and participate in conversations
- **AI-Powered Chat**: Integrated Gemini AI for intelligent conversations and content assistance
- **Smart Search**: Comprehensive search for users, posts, and content with recent search history
- **Interactive Map**: View posts and events on an interactive map interface
- **Media Sharing**: Share photos and videos with unified camera interface
- **Story Updates**: Share temporary story updates similar to social media platforms

### Social Features

- **User Profiles**: Customizable user profiles with posts and activity tracking
- **Follow System**: Follow other users and discover suggested connections
- **Post Interactions**: Upvote, comment, and share posts
- **User Verification**: Verified user badges and admin capabilities
- **Privacy Controls**: Comprehensive privacy settings and account security

### Technical Features

- **Cross-Platform**: Available on iOS, Android, Web, macOS, Linux, and Windows
- **Firebase Integration**: Authentication, Firestore database, and cloud storage
- **Push Notifications**: Real-time notifications for messages and updates
- **Offline Support**: Location caching and offline functionality
- **Google Sign-In**: Seamless authentication with Google accounts
- **Theme Support**: Light and dark theme options

## 🏗️ Architecture

### Frontend (Flutter)

- **Framework**: Flutter 3.6.2+ with Dart
- **State Management**: Provider pattern for state management
- **Navigation**: Custom route management with authentication guards
- **UI/UX**: Material Design with custom themes and responsive layouts

### Backend (Django)

- **Framework**: Django REST Framework
- **Database**: PostgreSQL with Django ORM
- **Authentication**: JWT tokens with Firebase integration
- **Media Storage**: Cloud storage for images and videos
- **Notifications**: Firebase Cloud Messaging integration

### External Services

- **Firebase**: Authentication, Firestore, Cloud Storage, Cloud Messaging
- **Google AI**: Gemini AI for chat assistance and content generation
- **Maps**: Location services and geocoding
- **Image Processing**: Video thumbnail generation and image optimization

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (3.6.2 or higher)
- Dart SDK
- Android Studio / Xcode for mobile development
- Python 3.8+ for backend server
- PostgreSQL database
- Firebase project with required services enabled

### Installation

1. **Clone the repository**

   ```bash
   git clone <repository-url>
   cd flutter_application
   ```

2. **Install Flutter dependencies**

   ```bash
   flutter pub get
   ```

3. **Setup Firebase**

   - Create a Firebase project
   - Enable Authentication, Firestore, Storage, and Cloud Messaging
   - Download configuration files:
     - `google-services.json` for Android
     - `GoogleService-Info.plist` for iOS
     - Update `firebase_options.dart` with web configuration

4. **Backend Setup**

   ```bash
   cd server
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   pip install -r requirements.txt
   python manage.py migrate
   python manage.py runserver
   ```

5. **Run the application**
   ```bash
   flutter run
   ```

### Configuration

#### Environment Variables

Create a `.env` file in the server directory:

```env
DEBUG=True
SECRET_KEY=your-secret-key
DATABASE_URL=your-database-url
FIREBASE_CREDENTIALS_PATH=path-to-firebase-service-account.json
```

#### Firebase Configuration

Update `lib/services/config/firebase_options.dart` with your Firebase project configuration.

## 📱 Supported Platforms

- ✅ **Android** (API 23+)
- ✅ **iOS** (iOS 12+)
- ✅ **Web** (Progressive Web App)
- ✅ **macOS** (macOS 10.14+)
- ✅ **Linux** (Ubuntu 18.04+)
- ✅ **Windows** (Windows 10+)

## 🛠️ Development

### Project Structure

```
lib/
├── constants/          # App constants and theme definitions
├── data/              # Data models and local storage
├── models/            # Data models (User, Post, etc.)
├── providers/         # State management providers
├── routes/            # Navigation and routing
├── services/          # Business logic and external APIs
├── ui/                # User interface components
│   ├── auth/          # Authentication screens
│   ├── pages/         # Main application pages
│   ├── profile/       # User profile management
│   ├── theme/         # Theme configurations
│   └── widgets/       # Reusable UI components
└── utils/             # Utility functions
```

### Key Dependencies

- **firebase_core** & **cloud_firestore**: Firebase integration
- **provider**: State management
- **http**: API communication
- **geolocator** & **geocoding**: Location services
- **image_picker**: Media capture
- **google_fonts**: Typography
- **shared_preferences**: Local storage

### Backend Structure

```
server/
├── accounts/          # User authentication and management
├── posts/             # Post and content management
├── notifications/     # Push notification handling
├── media_api/         # Media upload and processing
└── config/            # Django configuration
```

## 🧪 Testing

### Running Tests

```bash
# Flutter tests
flutter test

# Backend tests
cd server
python manage.py test
```

### Test Coverage

The project includes unit tests for:

- Authentication flows
- API endpoints
- UI components
- Location services
- Notification handling

## 🔧 Build & Deployment

### Mobile Apps

```bash
# Android
flutter build apk --release
flutter build appbundle --release

# iOS
flutter build ios --release
```

### Web Application

```bash
flutter build web --release
```

### Desktop Applications

```bash
# macOS
flutter build macos --release

# Linux
flutter build linux --release

# Windows
flutter build windows --release
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- Follow Flutter and Dart style guidelines
- Write unit tests for new features
- Update documentation for API changes
- Ensure cross-platform compatibility

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

For support and questions:

- Create an issue in the repository
- Check the documentation
- Review existing issues and discussions

## 🔮 Roadmap

### Upcoming Features

- [ ] Advanced AI content moderation
- [ ] Voice message support
- [ ] Enhanced location-based recommendations
- [ ] Integration with more social platforms
- [ ] Advanced analytics and insights
- [ ] Multi-language support

### Recent Updates

- ✅ Unified camera interface
- ✅ AI-powered chat assistance
- ✅ Enhanced privacy controls
- ✅ Cross-platform desktop support
- ✅ Improved notification system

---

**Built with ❤️ using Flutter and Firebase**
