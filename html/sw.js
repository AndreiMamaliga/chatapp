// NeonChat Service Worker
// Cache minimal pentru PWA instalare

const CACHE_NAME = 'neonchat-v1';
const urlsToCache = [
  '/',
  '/index.html',
  '/manifest.json',
  '/icon-192.png',
  '/icon-512.png'
];

// Install — cache fișiere de bază
self.addEventListener('install', function(event){
  console.log('[SW] Installing...');
  event.waitUntil(
    caches.open(CACHE_NAME).then(function(cache){
      return cache.addAll(urlsToCache).catch(function(err){
        console.warn('[SW] Cache addAll warning:', err);
      });
    }).then(function(){
      return self.skipWaiting();
    })
  );
});

// Activate — curăță cache-uri vechi
self.addEventListener('activate', function(event){
  console.log('[SW] Activating...');
  event.waitUntil(
    caches.keys().then(function(cacheNames){
      return Promise.all(
        cacheNames.map(function(cacheName){
          if(cacheName !== CACHE_NAME){
            return caches.delete(cacheName);
          }
        })
      );
    }).then(function(){
      return self.clients.claim();
    })
  );
});

// Fetch — network first, fallback cache
self.addEventListener('fetch', function(event){
  // Nu cache API calls
  if(event.request.url.indexOf('/api.php') >= 0){
    return;
  }
  // Nu cache POST
  if(event.request.method !== 'GET'){
    return;
  }
  event.respondWith(
    fetch(event.request).then(function(response){
      // Cache reușit
      if(response && response.status === 200 && response.type === 'basic'){
        const responseClone = response.clone();
        caches.open(CACHE_NAME).then(function(cache){
          cache.put(event.request, responseClone).catch(function(){});
        });
      }
      return response;
    }).catch(function(){
      // Offline — încearcă cache
      return caches.match(event.request).then(function(cached){
        return cached || caches.match('/index.html');
      });
    })
  );
});
