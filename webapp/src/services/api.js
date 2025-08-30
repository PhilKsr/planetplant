import axios from 'axios';
import toast from 'react-hot-toast';

// Create axios instance with default configuration
const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL || 'http://localhost:3000/api',
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor
api.interceptors.request.use(
  config => {
    // Add timestamp to prevent caching issues
    if (config.method === 'get') {
      config.params = {
        ...config.params,
        _t: Date.now(),
      };
    }

    console.log(
      `🌐 API Request: ${config.method?.toUpperCase()} ${config.url}`
    );
    return config;
  },
  error => {
    console.error('🌐 API Request Error:', error);
    return Promise.reject(error);
  }
);

// Response interceptor
api.interceptors.response.use(
  response => {
    console.log(`🌐 API Response: ${response.status} ${response.config.url}`);
    return response;
  },
  error => {
    console.error('🌐 API Response Error:', error);

    // Handle different error types
    if (error.response) {
      // Server responded with error status
      const { status, data } = error.response;

      switch (status) {
        case 400:
          toast.error(data.error?.message || 'Invalid request');
          break;
        case 404:
          toast.error('Resource not found');
          break;
        case 500:
          toast.error('Server error. Please try again later.');
          break;
        default:
          toast.error(data.error?.message || `Request failed (${status})`);
      }
    } else if (error.request) {
      // Network error
      toast.error('Network error. Check your connection.');
    } else {
      // Other error
      toast.error('Request failed. Please try again.');
    }

    return Promise.reject(error);
  }
);

// Plants API
export const plantsApi = {
  // Get all plants
  getAll: () => api.get('/plants'),

  // Get plants summary
  getSummary: () => api.get('/plants/summary'),

  // Get specific plant
  getById: plantId => api.get(`/plants/${plantId}`),

  // Get current sensor data
  getCurrent: plantId => api.get(`/plants/${plantId}/current`),

  // Get historical data
  getHistory: (plantId, params = {}) =>
    api.get(`/plants/${plantId}/history`, { params }),

  // Get watering history
  getWateringHistory: (plantId, params = {}) =>
    api.get(`/plants/${plantId}/watering/history`, { params }),

  // Manual watering
  water: (plantId, data = {}) => api.post(`/plants/${plantId}/water`, data),

  // Update plant configuration
  updateConfig: (plantId, config) =>
    api.put(`/plants/${plantId}/config`, config),

  // Update plant details
  update: (plantId, data) => api.put(`/plants/${plantId}`, data),

  // Calibrate sensors
  calibrate: (plantId, data) => api.post(`/plants/${plantId}/calibrate`, data),

  // Get care recommendations
  getRecommendations: plantId => api.get(`/plants/${plantId}/recommendations`),
};

// System API
export const systemApi = {
  // Get system status
  getStatus: () => api.get('/system/status'),

  // Get system info
  getInfo: () => api.get('/system/info'),

  // Get system metrics
  getMetrics: (params = {}) => api.get('/system/metrics', { params }),

  // Get logs
  getLogs: (params = {}) => api.get('/system/logs', { params }),

  // Restart services
  restart: (service = 'all') => api.post('/system/restart', { service }),

  // Cleanup old data
  cleanup: (retentionPeriod = '30d', dryRun = false) =>
    api.post('/system/cleanup', { retentionPeriod, dryRun }),

  // Get configuration
  getConfig: () => api.get('/system/config'),

  // Run system tests
  test: (component = 'all') => api.post('/system/test', { component }),
};

// Utility functions
export const handleApiError = (error, defaultMessage = 'Operation failed') => {
  console.error('API Error:', error);

  if (error.response?.data?.error?.message) {
    return error.response.data.error.message;
  }

  if (error.message) {
    return error.message;
  }

  return defaultMessage;
};

export const isNetworkError = error => {
  return !error.response && error.request;
};

export const isServerError = error => {
  return error.response?.status >= 500;
};

export const isClientError = error => {
  return error.response?.status >= 400 && error.response?.status < 500;
};

// Export default api instance for custom requests
export default api;
