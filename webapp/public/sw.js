const CACHE_NAME = 'planetplant-v1';
const STATIC_ASSETS = [
  '/',
  '/index.html',
  '/manifest.json',
  '/icons/icon-192x192.png',
  '/icons/icon-512x512.png'
];

// API cache configuration
const API_CACHE_NAME = 'planetplant-api-v1';
const API_CACHE_DURATION = 5 * 60 * 1000; // 5 minutes

// Install event
self.addEventListener('install', (event) => {
  console.log('Service Worker: Installing...');
  
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => {
        console.log('Service Worker: Caching static assets');
        return cache.addAll(STATIC_ASSETS);
      })
      .then(() => {
        console.log('Service Worker: Installation complete');
        // Force the new service worker to become active immediately
        return self.skipWaiting();
      })
      .catch((error) => {
        console.error('Service Worker: Installation failed', error);
      })
  );
});

// Activate event
self.addEventListener('activate', (event) => {
  console.log('Service Worker: Activating...');
  
  event.waitUntil(
    caches.keys()
      .then((cacheNames) => {
        return Promise.all(
          cacheNames.map((cacheName) => {
            if (cacheName !== CACHE_NAME && cacheName !== API_CACHE_NAME) {
              console.log('Service Worker: Deleting old cache', cacheName);
              return caches.delete(cacheName);
            }
          })
        );
      })
      .then(() => {
        console.log('Service Worker: Activation complete');
        // Take control of all pages immediately
        return self.clients.claim();
      })
  );
});

// Fetch event
self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);
  
  // Handle API requests
  if (url.pathname.startsWith('/api/')) {
    event.respondWith(handleApiRequest(request));
    return;
  }
  
  // Handle static assets
  event.respondWith(handleStaticRequest(request));
});

// Handle static asset requests with cache-first strategy
async function handleStaticRequest(request) {
  try {
    // Try to get the resource from cache first
    const cachedResponse = await caches.match(request);
    if (cachedResponse) {
      return cachedResponse;
    }
    
    // If not in cache, fetch from network
    const networkResponse = await fetch(request);
    
    // Cache the response if it's a GET request and successful
    if (request.method === 'GET' && networkResponse.status === 200) {
      const cache = await caches.open(CACHE_NAME);
      cache.put(request, networkResponse.clone());
    }
    
    return networkResponse;
  } catch (error) {
    console.error('Service Worker: Static request failed', error);
    
    // Return offline page for navigation requests
    if (request.mode === 'navigate') {
      return caches.match('/index.html');
    }
    
    // Return a basic error response for other requests
    return new Response('Offline', {
      status: 503,
      statusText: 'Service Unavailable',
    });
  }
}

// Handle API requests with network-first strategy and intelligent caching
async function handleApiRequest(request) {
  const url = new URL(request.url);
  const isReadOnlyRequest = request.method === 'GET';
  
  try {
    // Try network first for fresh data
    const networkResponse = await fetch(request);
    
    if (networkResponse.ok && isReadOnlyRequest) {
      // Cache successful read-only API responses
      const cache = await caches.open(API_CACHE_NAME);
      const responseToCache = networkResponse.clone();
      
      // Add timestamp for cache invalidation
      const headers = new Headers(responseToCache.headers);
      headers.set('sw-cached-at', Date.now().toString());
      
      const cachedResponse = new Response(responseToCache.body, {
        status: responseToCache.status,
        statusText: responseToCache.statusText,
        headers: headers
      });
      
      cache.put(request, cachedResponse);
    }
    
    return networkResponse;
  } catch (error) {
    console.log('Service Worker: Network request failed, trying cache', error);
    
    // For read-only requests, try to serve from cache
    if (isReadOnlyRequest) {
      const cachedResponse = await caches.match(request);
      
      if (cachedResponse) {
        // Check if cached response is still fresh
        const cachedAt = cachedResponse.headers.get('sw-cached-at');
        if (cachedAt && (Date.now() - parseInt(cachedAt)) < API_CACHE_DURATION) {
          console.log('Service Worker: Serving fresh cached API response');
          return cachedResponse;
        }
        
        // Cached response is stale but better than nothing when offline
        console.log('Service Worker: Serving stale cached API response');
        const headers = new Headers(cachedResponse.headers);
        headers.set('sw-cache-status', 'stale');
        
        return new Response(cachedResponse.body, {
          status: cachedResponse.status,
          statusText: cachedResponse.statusText,
          headers: headers
        });
      }
    }
    
    // Return appropriate offline response
    return new Response(
      JSON.stringify({
        error: 'Offline',
        message: 'This feature requires an internet connection'
      }),
      {
        status: 503,
        statusText: 'Service Unavailable',
        headers: {
          'Content-Type': 'application/json'
        }
      }
    );
  }
}

// Background sync for plant data updates
self.addEventListener('sync', (event) => {
  if (event.tag === 'plant-data-sync') {
    event.waitUntil(syncPlantData());
  }
});

// Sync plant data when connection is restored
async function syncPlantData() {
  try {
    console.log('Service Worker: Syncing plant data...');
    
    // Get all plant IDs from cache to update their data
    const cache = await caches.open(API_CACHE_NAME);
    const requests = await cache.keys();
    
    const plantRequests = requests.filter(req => 
      req.url.includes('/api/plants/') && req.method === 'GET'
    );
    
    // Refresh cached plant data
    for (const request of plantRequests) {
      try {
        const response = await fetch(request);
        if (response.ok) {
          await cache.put(request, response);
        }
      } catch (error) {
        console.error('Service Worker: Failed to sync plant data', error);
      }
    }
    
    console.log('Service Worker: Plant data sync complete');
  } catch (error) {
    console.error('Service Worker: Sync failed', error);
  }
}

// Push notification handler
self.addEventListener('push', (event) => {
  if (!event.data) return;
  
  try {
    const data = event.data.json();
    const options = {
      body: data.body || 'PlanetPlant notification',
      icon: '/icons/icon-192x192.png',
      badge: '/icons/badge-72x72.png',
      tag: data.tag || 'planetplant-notification',
      data: data.data || {},
      actions: data.actions || [],
      requireInteraction: data.requireInteraction || false,
      silent: data.silent || false
    };
    
    event.waitUntil(
      self.registration.showNotification(data.title || 'PlanetPlant', options)
    );
  } catch (error) {
    console.error('Service Worker: Failed to show notification', error);
  }
});

// Notification click handler
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  
  const data = event.notification.data;
  let targetUrl = '/';
  
  // Determine where to navigate based on notification type
  if (data.plantId) {
    targetUrl = `/plant/${data.plantId}`;
  } else if (data.type === 'system') {
    targetUrl = '/system';
  } else if (data.type === 'settings') {
    targetUrl = '/settings';
  }
  
  // Handle action clicks
  if (event.action) {
    switch (event.action) {
      case 'water-now':
        // This would need to be handled by posting a message to the client
        // or making a direct API call to water the plant
        break;
      case 'view-plant':
        targetUrl = `/plant/${data.plantId}`;
        break;
      case 'dismiss':
        return; // Just close, don't navigate
    }
  }
  
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true })
      .then((clientList) => {
        // Check if there's already a window open
        const existingClient = clientList.find(client => {
          const clientUrl = new URL(client.url);
          return clientUrl.origin === self.location.origin;
        });
        
        if (existingClient) {
          // Focus existing window and navigate
          return existingClient.focus().then(() => {
            return existingClient.navigate(targetUrl);
          });
        }
        
        // Open new window
        return clients.openWindow(targetUrl);
      })
  );
});

// Message handler for communication with main app
self.addEventListener('message', (event) => {
  if (event.data && event.data.type) {
    switch (event.data.type) {
      case 'SKIP_WAITING':
        self.skipWaiting();
        break;
      case 'CACHE_PLANT_DATA':
        // Cache specific plant data
        cacheSpecificData(event.data.payload);
        break;
      case 'CLEAR_CACHE':
        // Clear all caches
        clearAllCaches();
        break;
    }
  }
});

// Utility function to cache specific data
async function cacheSpecificData(data) {
  try {
    const cache = await caches.open(API_CACHE_NAME);
    const response = new Response(JSON.stringify(data), {
      headers: {
        'Content-Type': 'application/json',
        'sw-cached-at': Date.now().toString()
      }
    });
    
    await cache.put(data.url, response);
  } catch (error) {
    console.error('Service Worker: Failed to cache specific data', error);
  }
}

// Utility function to clear all caches
async function clearAllCaches() {
  try {
    const cacheNames = await caches.keys();
    await Promise.all(
      cacheNames.map(cacheName => caches.delete(cacheName))
    );
    console.log('Service Worker: All caches cleared');
  } catch (error) {
    console.error('Service Worker: Failed to clear caches', error);
  }
}

// Periodic background sync for critical plant data
self.addEventListener('periodicsync', (event) => {
  if (event.tag === 'plant-health-check') {
    event.waitUntil(performHealthCheck());
  }
});

// Perform health check for plants
async function performHealthCheck() {
  try {
    const response = await fetch('/api/plants?quick=true');
    if (response.ok) {
      const plants = await response.json();
      
      // Check for plants that need attention
      const plantsNeedingAttention = plants.data.filter(plant => 
        !plant.status?.isOnline || 
        plant.currentData?.moisture < plant.config?.moistureThresholds?.min
      );
      
      // Show notification if any plants need attention
      if (plantsNeedingAttention.length > 0) {
        const plantNames = plantsNeedingAttention.map(p => p.name).join(', ');
        
        await self.registration.showNotification('Plants Need Attention', {
          body: `${plantNames} ${plantsNeedingAttention.length === 1 ? 'needs' : 'need'} your attention`,
          icon: '/icons/icon-192x192.png',
          tag: 'plant-health-alert',
          data: {
            type: 'health-check',
            plants: plantsNeedingAttention
          },
          actions: [
            {
              action: 'view-dashboard',
              title: 'View Dashboard'
            }
          ]
        });
      }
    }
  } catch (error) {
    console.error('Service Worker: Health check failed', error);
  }
}