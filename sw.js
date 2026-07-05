const CACHE_NAME = 'tailors-erp-r3-cache-v1';
const ASSETS = ['./', './index.html', './styles.css', './app.js', './manifest.json'];
self.addEventListener('install', event => {
  event.waitUntil(caches.open(CACHE_NAME).then(cache => cache.addAll(ASSETS)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', event => {
  event.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', event => {
  if (event.request.method !== 'GET') return;
  event.respondWith(fetch(event.request).then(resp => {
    const clone = resp.clone();
    caches.open(CACHE_NAME).then(cache => cache.put(event.request, clone)).catch(() => null);
    return resp;
  }).catch(() => caches.match(event.request).then(match => match || caches.match('./index.html'))));
});
