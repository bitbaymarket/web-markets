// Service Worker

// Install Event
self.addEventListener('install', function(event) {
    console.log("[SW] Install event");
    // No caching during install
});

// Activate Event
self.addEventListener('activate', function(event) {
    console.log("[SW] Activate event");
    // No action needed, but you can clear old caches if they exist
    event.waitUntil(
        caches.keys().then(function(cacheNames) {
            return Promise.all(
                cacheNames.map(function(cacheName) {
                    return caches.delete(cacheName);
                })
            );
        })
    );
});

// Fetch Event
self.addEventListener('fetch', function(event) {
    console.log("[SW] Fetch event: ", event.request.url);
    // Just pass through the request without caching
    event.respondWith(fetch(event.request));
});

