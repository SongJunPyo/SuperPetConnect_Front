// Firebase Cloud Messaging Service Worker — 백그라운드/탭 닫힘 상태에서 OS 알림 표시.
//
// 안전 가드 (BE 협의 사항):
// - VAPID 키는 이 파일에 하드코딩 금지 — getToken(vapidKey: ...) dart 인자로만 전달
// - apiKey 등 firebaseConfig는 client-side 노출 정상 (공개키)
//
// 활성화 시점: BE [B] merge (POST /api/user/fcm-token이 platform 필드 수용) 후
// dart 측 web_fcm_init.dart의 _enabled 플래그를 true로 토글.

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

// 백그라운드 메시지 수신 (탭이 비활성/닫힘 상태)
// 포그라운드 메시지는 firebase_messaging 패키지의 onMessage 리스너가 처리.
messaging.onBackgroundMessage(function(payload) {
  const notificationTitle = (payload.notification && payload.notification.title) || '슈퍼펫커넥트';
  const notificationOptions = {
    body: (payload.notification && payload.notification.body) || '',
    icon: '/icons/Icon-192.png',
    // payload.data를 알림에 첨부 — notificationclick에서 라우팅에 사용
    data: payload.data || {},
  };
  return self.registration.showNotification(notificationTitle, notificationOptions);
});

// 사용자가 OS 알림 클릭 시 처리 — 앱 탭으로 포커스 이동 + URL 핸드오프
// 같은 origin 탭이 이미 열려있으면 그 탭으로 focus, 없으면 새 탭.
// data 필드는 dart 측에서 SharedPreferences/이벤트로 받아 dispatchByType 호출 가능.
self.addEventListener('notificationclick', function(event) {
  event.notification.close();
  const data = event.notification.data || {};
  // dart 측이 읽을 수 있도록 query string으로 type 전달 (data 채널 메인은 postMessage)
  const targetUrl = '/' + (data.type ? '?fcm_type=' + encodeURIComponent(data.type) : '');

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function(clientList) {
      // 이미 열린 탭이 있으면 focus + postMessage로 dispatch 정보 전달
      for (const client of clientList) {
        if ('focus' in client) {
          client.postMessage({ source: 'fcm-sw', type: 'notification-click', data: data });
          return client.focus();
        }
      }
      // 열린 탭 없으면 새 창
      if (clients.openWindow) {
        return clients.openWindow(targetUrl);
      }
    })
  );
});
