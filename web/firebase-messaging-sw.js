importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyBdO-LjFNK3TDE0C0UfivNCe4_Xs-CVGj8",
  authDomain: "super-pet-connect.firebaseapp.com",
  projectId: "super-pet-connect",
  storageBucket: "super-pet-connect.firebasestorage.app",
  messagingSenderId: "74105196603",
  appId: "1:74105196603:web:0f7d19c56f42229d4e0c1e"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/firebase-logo.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});