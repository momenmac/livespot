// import 'package:flutter/foundation.dart';

// class MainProvider extends ChangeNotifier {
//   int _unreadNotifications = 0;
//   int _unreadMessages = 0;

//   int get unreadNotifications => _unreadNotifications;
//   int get unreadMessages => _unreadMessages;

//   void setUnreadNotifications(int count) {
//     _unreadNotifications = count;
//     notifyListeners();
//   }

//   void setUnreadMessages(int count) {
//     _unreadMessages = count;
//     notifyListeners();
//   }

//   void decrementNotifications() {
//     if (_unreadNotifications > 0) {
//       _unreadNotifications--;
//       notifyListeners();
//     }
//   }

//   void decrementMessages() {
//     if (_unreadMessages > 0) {
//       _unreadMessages--;
//       notifyListeners();
//     }
//   }
// }
