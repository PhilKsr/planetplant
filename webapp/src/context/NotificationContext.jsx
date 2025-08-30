import React, { createContext, useContext, useEffect, useState } from 'react';
import toast from 'react-hot-toast';

import notificationService from '../services/notifications';

const NotificationContext = createContext();

export const useNotifications = () => {
  const context = useContext(NotificationContext);
  if (!context) {
    throw new Error(
      'useNotifications must be used within a NotificationProvider'
    );
  }
  return context;
};

export const NotificationProvider = ({ children }) => {
  const [isSupported, setIsSupported] = useState(false);
  const [permission, setPermission] = useState('default');
  const [isSubscribed, setIsSubscribed] = useState(false);
  const [subscription, setSubscription] = useState(null);
  const [preferences, setPreferences] = useState({
    lowMoisture: true,
    deviceOffline: true,
    systemAlerts: true,
    dailyReport: false,
    criticalOnly: false,
  });

  useEffect(() => {
    initializeNotifications();
  }, []);

  const initializeNotifications = async () => {
    try {
      // Check if notifications are supported
      const supported = await notificationService.init();
      setIsSupported(supported);

      if (!supported) {
        console.log('Push notifications not supported');
        return;
      }

      // Check current permission status
      const currentPermission = await notificationService.getPermissionStatus();
      setPermission(currentPermission);

      // Check if already subscribed
      const currentSubscription = await notificationService.getSubscription();
      if (currentSubscription) {
        setSubscription(currentSubscription);
        setIsSubscribed(true);
      }

      // Handle service worker updates
      await notificationService.handleServiceWorkerUpdate();

      // Setup connection status monitoring
      notificationService.handleConnectionStatus();
    } catch (error) {
      console.error('Failed to initialize notifications:', error);
      toast.error('Failed to initialize notifications');
    }
  };

  const enableNotifications = async () => {
    try {
      if (!isSupported) {
        toast.error('Notifications are not supported on this device');
        return false;
      }

      // Request permission
      const hasPermission = await notificationService.requestPermission();
      setPermission(hasPermission ? 'granted' : 'denied');

      if (!hasPermission) {
        toast.error('Notification permission denied');
        return false;
      }

      // Subscribe to push notifications
      // Note: In a real app, you'd get this VAPID key from your server
      const vapidPublicKey =
        import.meta.env.VITE_VAPID_PUBLIC_KEY ||
        'BEl62iUYgUivxIkv69yViEuiBIa40HI80Y_8M0n8Gr8Ts-ZQ9C0h7cJ8Rl4Hw0Y6B8FcXvMR2P4Q8J0M8D1QhVwA';

      const pushSubscription =
        await notificationService.subscribeToPush(vapidPublicKey);
      setSubscription(pushSubscription);

      // Send subscription to server
      await notificationService.sendSubscriptionToServer(pushSubscription);

      setIsSubscribed(true);
      toast.success('Notifications enabled successfully!');
      return true;
    } catch (error) {
      console.error('Failed to enable notifications:', error);
      toast.error('Failed to enable notifications: ' + error.message);
      return false;
    }
  };

  const disableNotifications = async () => {
    try {
      if (subscription) {
        // Remove subscription from server
        await notificationService.removeSubscriptionFromServer(subscription);

        // Unsubscribe from push notifications
        await notificationService.unsubscribeFromPush();

        setSubscription(null);
        setIsSubscribed(false);
        toast.success('Notifications disabled');
        return true;
      }
    } catch (error) {
      console.error('Failed to disable notifications:', error);
      toast.error('Failed to disable notifications');
      return false;
    }
  };

  const updatePreferences = async newPreferences => {
    try {
      // Update local state
      setPreferences(newPreferences);

      // Send preferences to server if subscribed
      if (isSubscribed) {
        await notificationService.updateNotificationPreferences(newPreferences);
        toast.success('Notification preferences updated');
      }
    } catch (error) {
      console.error('Failed to update notification preferences:', error);
      toast.error('Failed to update notification preferences');
    }
  };

  const sendTestNotification = async () => {
    try {
      if (!isSubscribed) {
        // Show local notification as test
        notificationService.showLocalNotification('Test Notification', {
          body: 'This is a test notification from PlanetPlant!',
          tag: 'test-notification',
        });
        return;
      }

      // Send test push notification via server
      await notificationService.sendTestNotification();
      toast.success('Test notification sent!');
    } catch (error) {
      console.error('Failed to send test notification:', error);
      toast.error('Failed to send test notification');
    }
  };

  // Handle plant-specific notifications
  const notifyLowMoisture = plant => {
    if (!preferences.lowMoisture) return;

    notificationService.showLocalNotification(`${plant.name} needs water!`, {
      body: `Soil moisture is ${plant.currentData?.moisture}% (below ${plant.config?.moistureThresholds?.min}%)`,
      tag: `low-moisture-${plant.id}`,
      data: {
        type: 'low-moisture',
        plantId: plant.id,
      },
      actions: [
        {
          action: 'water-now',
          title: 'Water Now',
        },
        {
          action: 'view-plant',
          title: 'View Plant',
        },
      ],
    });
  };

  const notifyDeviceOffline = plant => {
    if (!preferences.deviceOffline) return;

    notificationService.showLocalNotification(`${plant.name} went offline`, {
      body: `Device has been offline since ${new Date(plant.status?.lastSeen).toLocaleString()}`,
      tag: `device-offline-${plant.id}`,
      data: {
        type: 'device-offline',
        plantId: plant.id,
      },
      actions: [
        {
          action: 'view-plant',
          title: 'View Plant',
        },
      ],
    });
  };

  const notifySystemAlert = alert => {
    if (!preferences.systemAlerts) return;

    const severity = alert.severity || 'info';
    const requireInteraction = severity === 'critical';

    notificationService.showLocalNotification(
      `System Alert: ${alert.component}`,
      {
        body: alert.message,
        tag: `system-alert-${alert.component}`,
        requireInteraction,
        data: {
          type: 'system-alert',
          component: alert.component,
          severity,
        },
        actions: [
          {
            action: 'view-system',
            title: 'View System',
          },
        ],
      }
    );
  };

  const notifyWateringComplete = (plant, duration) => {
    notificationService.showLocalNotification(
      `${plant.name} watered successfully`,
      {
        body: `Watering completed (${duration / 1000}s)`,
        tag: `watering-complete-${plant.id}`,
        data: {
          type: 'watering-complete',
          plantId: plant.id,
        },
      }
    );
  };

  const notifyWateringFailed = (plant, error) => {
    notificationService.showLocalNotification(`Failed to water ${plant.name}`, {
      body: error || 'Watering system error',
      tag: `watering-failed-${plant.id}`,
      requireInteraction: true,
      data: {
        type: 'watering-failed',
        plantId: plant.id,
      },
      actions: [
        {
          action: 'retry-watering',
          title: 'Retry',
        },
        {
          action: 'view-plant',
          title: 'View Plant',
        },
      ],
    });
  };

  // Daily report notification
  const sendDailyReport = summary => {
    if (!preferences.dailyReport) return;

    const plantsNeedingAttention = summary.plantsNeedingAttention || 0;
    const totalWaterings = summary.totalWaterings || 0;

    let body = `${totalWaterings} waterings today.`;
    if (plantsNeedingAttention > 0) {
      body += ` ${plantsNeedingAttention} plants need attention.`;
    } else {
      body += ' All plants are healthy!';
    }

    notificationService.showLocalNotification('Daily Plant Report', {
      body,
      tag: 'daily-report',
      data: {
        type: 'daily-report',
        summary,
      },
      actions: [
        {
          action: 'view-dashboard',
          title: 'View Dashboard',
        },
      ],
    });
  };

  const value = {
    isSupported,
    permission,
    isSubscribed,
    subscription,
    preferences,
    enableNotifications,
    disableNotifications,
    updatePreferences,
    sendTestNotification,
    notifyLowMoisture,
    notifyDeviceOffline,
    notifySystemAlert,
    notifyWateringComplete,
    notifyWateringFailed,
    sendDailyReport,
  };

  return (
    <NotificationContext.Provider value={value}>
      {children}
    </NotificationContext.Provider>
  );
};

export default NotificationProvider;
