// Import the Firebase scripts for v9+ modular SDK
importScripts(
  "https://www.gstatic.com/firebasejs/11.7.0/firebase-app-compat.js"
);
importScripts(
  "https://www.gstatic.com/firebasejs/11.7.0/firebase-messaging-compat.js"
);

// Initialize Firebase in the service worker
const firebaseConfig = {
  apiKey: "AIzaSyBX9NWqWe-gn51e-Hh69617rBUXK9Q38Bs",
  authDomain: "livespot-b1eb4.firebaseapp.com",
  projectId: "livespot-b1eb4",
  storageBucket: "livespot-b1eb4.firebasestorage.app",
  messagingSenderId: "813529293309",
  appId: "1:813529293309:web:46f5d27446a52292583994",
  measurementId: "G-TR331VFEQ6",
};

firebase.initializeApp(firebaseConfig);

// Initialize Firebase Messaging
const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage(function (payload) {
  console.log(
    "[firebase-messaging-sw.js] Received background message ",
    payload
  );

  // Customize notification here
  const notificationTitle = payload.notification.title || "LiveSpot";
  const notificationOptions = {
    body: payload.notification.body || "You have a new message!",
    icon: "/icons/Icon-192.png",
    badge: "/icons/Icon-192.png",
    tag: "livespot-notification",
    requireInteraction: true,
    data: payload.data,
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});

// Handle notification clicks
self.addEventListener("notificationclick", function (event) {
  console.log("[firebase-messaging-sw.js] Notification click received.");

  event.notification.close();

  // Handle the click action
  event.waitUntil(clients.openWindow("/"));
});
