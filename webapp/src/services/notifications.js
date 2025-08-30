class NotificationService {
  constructor() {
    this.registration = null;
    this.subscription = null;
    this.isSupported = 'serviceWorker' in navigator && 'PushManager' in window;
  }

  async init() {
    if (!this.isSupported) {
      console.warn('Push notifications are not supported');
      return false;
    }

    try {
      // Register service worker
      this.registration = await navigator.serviceWorker.register('/sw.js');
      console.log('Service Worker registered:', this.registration);

      // Wait for service worker to be ready
      await navigator.serviceWorker.ready;

      return true;
    } catch (error) {
      console.error('Service Worker registration failed:', error);
      return false;
    }
  }

  async requestPermission() {
    if (!this.isSupported) {
      return false;
    }

    const permission = await Notification.requestPermission();
    return permission === 'granted';
  }

  async getPermissionStatus() {
    if (!this.isSupported) {
      return 'unsupported';
    }

    return Notification.permission;
  }

  async subscribeToPush(vapidPublicKey) {
    if (!this.registration) {
      throw new Error('Service worker not registered');
    }

    try {
      // Check if already subscribed
      this.subscription = await this.registration.pushManager.getSubscription();

      if (!this.subscription) {
        // Subscribe to push notifications
        this.subscription = await this.registration.pushManager.subscribe({
          userVisibleOnly: true,
          applicationServerKey: this.urlBase64ToUint8Array(vapidPublicKey),
        });
      }

      return this.subscription;
    } catch (error) {
      console.error('Push subscription failed:', error);
      throw error;
    }
  }

  async unsubscribeFromPush() {
    if (this.subscription) {
      try {
        await this.subscription.unsubscribe();
        this.subscription = null;
        return true;
      } catch (error) {
        console.error('Push unsubscribe failed:', error);
        return false;
      }
    }
    return true;
  }

  async getSubscription() {
    if (!this.registration) {
      return null;
    }

    try {
      return await this.registration.pushManager.getSubscription();
    } catch (error) {
      console.error('Failed to get push subscription:', error);
      return null;
    }
  }

  // Send subscription to server
  async sendSubscriptionToServer(subscription, userId = null) {
    try {
      const response = await fetch('/api/notifications/subscribe', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          subscription,
          userId,
          userAgent: navigator.userAgent,
          timestamp: new Date().toISOString(),
        }),
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      const result = await response.json();
      console.log('Subscription sent to server:', result);
      return result;
    } catch (error) {
      console.error('Failed to send subscription to server:', error);
      throw error;
    }
  }

  // Remove subscription from server
  async removeSubscriptionFromServer(subscription) {
    try {
      const response = await fetch('/api/notifications/unsubscribe', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ subscription }),
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      return await response.json();
    } catch (error) {
      console.error('Failed to remove subscription from server:', error);
      throw error;
    }
  }

  // Show local notification
  showLocalNotification(title, options = {}) {
    if (!this.isSupported || Notification.permission !== 'granted') {
      return false;
    }

    const notification = new Notification(title, {
      icon: '/icons/icon-192x192.png',
      badge: '/icons/badge-72x72.png',
      ...options,
    });

    // Auto-close after 5 seconds unless requireInteraction is true
    if (!options.requireInteraction) {
      setTimeout(() => {
        notification.close();
      }, 5000);
    }

    return notification;
  }

  // Configure notification preferences
  async updateNotificationPreferences(preferences) {
    try {
      const response = await fetch('/api/notifications/preferences', {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(preferences),
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      return await response.json();
    } catch (error) {
      console.error('Failed to update notification preferences:', error);
      throw error;
    }
  }

  // Test notification
  async sendTestNotification() {
    try {
      const response = await fetch('/api/notifications/test', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      return await response.json();
    } catch (error) {
      console.error('Failed to send test notification:', error);
      throw error;
    }
  }

  // Utility function to convert VAPID key
  urlBase64ToUint8Array(base64String) {
    const padding = '='.repeat((4 - (base64String.length % 4)) % 4);
    const base64 = (base64String + padding)
      .replace(/-/g, '+')
      .replace(/_/g, '/');

    const rawData = window.atob(base64);
    const outputArray = new Uint8Array(rawData.length);

    for (let i = 0; i < rawData.length; ++i) {
      outputArray[i] = rawData.charCodeAt(i);
    }
    return outputArray;
  }

  // Handle service worker updates
  async handleServiceWorkerUpdate() {
    if (!this.registration) return;

    this.registration.addEventListener('updatefound', () => {
      const newWorker = this.registration.installing;

      newWorker.addEventListener('statechange', () => {
        if (newWorker.state === 'installed') {
          if (navigator.serviceWorker.controller) {
            // New update available
            this.showUpdateNotification();
          }
        }
      });
    });
  }

  showUpdateNotification() {
    this.showLocalNotification('App Update Available', {
      body: 'A new version of PlanetPlant is available. Refresh to update.',
      tag: 'app-update',
      requireInteraction: true,
      actions: [
        {
          action: 'refresh',
          title: 'Refresh Now',
        },
        {
          action: 'dismiss',
          title: 'Later',
        },
      ],
    });
  }

  // Check connection status and handle offline notifications
  handleConnectionStatus() {
    const showOfflineNotification = () => {
      this.showLocalNotification('You are offline', {
        body: "Some features may not work. We'll sync when you're back online.",
        tag: 'offline-status',
        icon: '/icons/offline-icon.png',
      });
    };

    const showOnlineNotification = () => {
      this.showLocalNotification('You are back online', {
        body: 'All features are now available. Syncing latest data...',
        tag: 'online-status',
      });
    };

    window.addEventListener('offline', showOfflineNotification);
    window.addEventListener('online', showOnlineNotification);
  }
}

// Create and export singleton instance
const notificationService = new NotificationService();

export default notificationService;
