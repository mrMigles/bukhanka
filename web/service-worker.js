const VERSION = '__BUILD_VERSION__';
const CACHE_PREFIX = 'bukhanka-web-';
const CACHE_NAME = CACHE_PREFIX + VERSION;
const LEGACY_PREFIX = 'Буханка • Выше о-sw-cache-';
const SHELL = ['index.html', 'loading-__BUILD_VERSION__.js', 'poster-__BUILD_VERSION__.webp', 'pwa-update-__BUILD_VERSION__.js', 'index.manifest.json', 'icon-192.png', 'icon-512.png'];
const GAME = ['game-__BUILD_VERSION__.js', 'game-__BUILD_VERSION__.wasm', 'game-__BUILD_VERSION__.pck', 'game-__BUILD_VERSION__.audio.worklet.js', 'game-__BUILD_VERSION__.audio.position.worklet.js'];
const CACHEABLE = new Set([...SHELL, ...GAME]);

self.addEventListener('install', event => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE_NAME);
    await cache.addAll(SHELL);
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    for (const key of await caches.keys()) {
      if ((key.startsWith(CACHE_PREFIX) && key !== CACHE_NAME) || key.startsWith(LEGACY_PREFIX)) {
        await caches.delete(key);
      }
    }
    await self.clients.claim();
  })());
});

self.addEventListener('message', event => {
  if (event.data === 'PRIME') {
    event.waitUntil((async () => {
      const cache = await caches.open(CACHE_NAME);
      await cache.addAll(GAME);
    })());
  }
});

self.addEventListener('fetch', event => {
  if (event.request.method !== 'GET') return;
  const url = new URL(event.request.url);
  if (url.origin !== self.location.origin) return;
  const name = url.pathname.split('/').pop() || 'index.html';
  const navigation = event.request.mode === 'navigate';
  if (navigation && name !== 'index.html') return;
  if (!navigation && !CACHEABLE.has(name)) return;

  event.respondWith((async () => {
    const cache = await caches.open(CACHE_NAME);
    if (!navigation) {
      const cached = await cache.match(event.request);
      if (cached) return cached;
    }
    try {
      const response = await fetch(event.request, navigation ? { cache: 'no-store' } : undefined);
      if (response.ok) event.waitUntil(cache.put(navigation ? new URL('index.html', self.registration.scope) : event.request, response.clone()).catch(() => {}));
      return response;
    } catch (error) {
      const fallback = await cache.match(navigation ? new URL('index.html', self.registration.scope) : event.request);
      if (fallback) return fallback;
      if (navigation) return new Response('Для запуска игры нужно подключение к сети.', { status: 503, headers: { 'Content-Type': 'text/plain; charset=utf-8' } });
      throw error;
    }
  })());
});
