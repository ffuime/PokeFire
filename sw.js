const CACHE = "pokefire-20261018190112";
const CORE = [
    "./",
    "./index.html",
    "./style.css",
    "./app.min.js",
    "./pokemons.json",
    "./moves.json",
    "./abilities.json",
    "./items.json",
    "./aliases.json",
    "./usage_names.json",
    "./sprite/scarf.png",
    "./favicon/favicon.ico",
    "./favicon/favicon-32x32.png",
    "./site.webmanifest",
];
const RUNTIME_HOSTS = ["pokesol.app", "fonts.googleapis.com", "fonts.gstatic.com"];

self.addEventListener("install", (event) => {
    event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll(CORE)).then(() => self.skipWaiting()));
});

self.addEventListener("activate", (event) => {
    event.waitUntil(
        caches.keys()
            .then((keys) => Promise.all(keys.filter((key) => key !== CACHE).map((key) => caches.delete(key))))
            .then(() => self.clients.claim()),
    );
});

const putCache = async (request, response) => {
    if (response && (response.ok || response.type === "opaque")) {
        const cache = await caches.open(CACHE);
        await cache.put(request, response.clone());
    }
    return response;
};

const fromCache = async (request) => (await caches.match(request)) ?? (new URL(request.url).origin === location.origin ? await caches.match(request, { ignoreSearch: true }) : undefined);

const networkFirst = async (request) => {
    try {
        return await putCache(request, await fetch(request));
    } catch {
        return (await fromCache(request)) ?? Response.error();
    }
};

const staleWhileRevalidate = async (request) => {
    const cached = await caches.match(request);
    const network = fetch(request).then((response) => putCache(request, response)).catch(() => null);
    return cached ?? (await network) ?? (await fromCache(request)) ?? Response.error();
};

const cacheFirst = async (request) => {
    const cached = await caches.match(request);
    if (cached) return cached;
    try {
        return await putCache(request, await fetch(request));
    } catch {
        return (await fromCache(request)) ?? Response.error();
    }
};

self.addEventListener("fetch", (event) => {
    const { request } = event;
    if (request.method !== "GET") return;
    const url = new URL(request.url);
    if (request.mode === "navigate") {
        event.respondWith(networkFirst(request));
        return;
    }
    if (url.origin === location.origin) {
        event.respondWith(url.search.includes("v=") ? cacheFirst(request) : staleWhileRevalidate(request));
        return;
    }
    if (RUNTIME_HOSTS.includes(url.hostname)) event.respondWith(staleWhileRevalidate(request));
});
