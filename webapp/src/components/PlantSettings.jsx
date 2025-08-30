import { Check, Image, Trash2 } from 'lucide-react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { motion } from 'framer-motion';
import React, { useState } from 'react';
import toast from 'react-hot-toast';

import { useWebSocket } from '../context/WebSocketContext';
import { plantsApi } from '../services/api';

const PlantSettings = ({ plant }) => {
  const [settings, setSettings] = useState({
    name: plant.name || '',
    type: plant.type || 'houseplant',
    location: plant.location || '',
    moistureMin: plant.config?.moistureThresholds?.min || 30,
    moistureMax: plant.config?.moistureThresholds?.max || 80,
    temperatureMin: plant.config?.temperatureThresholds?.min || 15,
    temperatureMax: plant.config?.temperatureThresholds?.max || 35,
    wateringDuration: plant.config?.wateringConfig?.duration || 5000,
    maxDailyWaterings: plant.config?.wateringConfig?.maxDailyWaterings || 3,
    quietStart: plant.config?.wateringConfig?.quietHours?.start || '22:00',
    quietEnd: plant.config?.wateringConfig?.quietHours?.end || '06:00',
    autoWateringEnabled: plant.config?.wateringConfig?.enabled !== false,
  });

  const [hasChanges, setHasChanges] = useState(false);
  const queryClient = useQueryClient();
  const { updateConfig } = useWebSocket();

  // Update plant mutation
  const updatePlantMutation = useMutation({
    mutationFn: async updates => {
      const response = await plantsApi.update(plant.id, updates);
      return response.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries(['plant', plant.id]);
      toast.success('Plant details updated!');
    },
    onError: _error => {
      toast.error('Failed to update plant details');
    },
  });

  // Update config mutation
  const updateConfigMutation = useMutation({
    mutationFn: async config => {
      const response = await plantsApi.updateConfig(plant.id, config);
      return response.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries(['plant', plant.id]);
      toast.success('Plant configuration updated!');
      setHasChanges(false);
    },
    onError: _error => {
      toast.error('Failed to update plant configuration');
    },
  });

  const handleInputChange = (field, value) => {
    setSettings(prev => ({ ...prev, [field]: value }));
    setHasChanges(true);
  };

  const handleSaveBasicInfo = () => {
    updatePlantMutation.mutate({
      name: settings.name,
      type: settings.type,
      location: settings.location,
    });
  };

  const handleSaveConfiguration = () => {
    const config = {
      moistureThresholds: {
        min: settings.moistureMin,
        max: settings.moistureMax,
      },
      temperatureThresholds: {
        min: settings.temperatureMin,
        max: settings.temperatureMax,
      },
      wateringConfig: {
        duration: settings.wateringDuration,
        maxDailyWaterings: settings.maxDailyWaterings,
        quietHours: {
          start: settings.quietStart,
          end: settings.quietEnd,
        },
        enabled: settings.autoWateringEnabled,
      },
    };

    updateConfigMutation.mutate(config);

    // Also send via WebSocket for immediate effect
    updateConfig(plant.id, config);
  };

  const plantTypes = [
    { value: 'houseplant', label: 'Houseplant' },
    { value: 'herb', label: 'Herb' },
    { value: 'vegetable', label: 'Vegetable' },
    { value: 'succulent', label: 'Succulent' },
    { value: 'flower', label: 'Flower' },
    { value: 'tree', label: 'Tree' },
    { value: 'other', label: 'Other' },
  ];

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      transition={{ duration: 0.3 }}
      className="space-y-8"
    >
      {/* Basic Information */}
      <div>
        <h3 className="mb-4 text-lg font-semibold text-gray-900 dark:text-white">
          Plant Information
        </h3>

        <div className="space-y-4">
          <div>
            <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
              Plant Name
            </label>
            <input
              type="text"
              value={settings.name}
              onChange={e => handleInputChange('name', e.target.value)}
              className="input-field"
              placeholder="My Beautiful Plant"
            />
          </div>

          <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
            <div>
              <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
                Plant Type
              </label>
              <select
                value={settings.type}
                onChange={e => handleInputChange('type', e.target.value)}
                className="input-field"
              >
                {plantTypes.map(type => (
                  <option key={type.value} value={type.value}>
                    {type.label}
                  </option>
                ))}
              </select>
            </div>

            <div>
              <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
                Location
              </label>
              <input
                type="text"
                value={settings.location}
                onChange={e => handleInputChange('location', e.target.value)}
                className="input-field"
                placeholder="Living Room"
              />
            </div>
          </div>

          {/* Plant Photo Upload */}
          <div>
            <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
              Plant Photo
            </label>
            <div className="flex items-center space-x-4">
              <div className="flex h-20 w-20 items-center justify-center rounded-lg bg-gray-100 dark:bg-gray-700">
                <Image className="h-8 w-8 text-gray-400" />
              </div>
              <div className="flex-1">
                <button className="btn-secondary text-sm">Upload Photo</button>
                <p className="mt-1 text-xs text-gray-500 dark:text-gray-400">
                  JPG, PNG up to 2MB
                </p>
              </div>
            </div>
          </div>

          <button
            onClick={handleSaveBasicInfo}
            disabled={updatePlantMutation.isLoading}
            className="btn-primary"
          >
            {updatePlantMutation.isLoading ? 'Saving...' : 'Save Basic Info'}
          </button>
        </div>
      </div>

      {/* Sensor Thresholds */}
      <div>
        <h3 className="mb-4 text-lg font-semibold text-gray-900 dark:text-white">
          Sensor Thresholds
        </h3>

        <div className="space-y-6">
          {/* Moisture Thresholds */}
          <div className="card p-4">
            <h4 className="mb-4 font-medium text-gray-900 dark:text-white">
              Soil Moisture
            </h4>

            <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
              <div>
                <label className="mb-2 block text-sm text-gray-600 dark:text-gray-400">
                  Minimum (Water when below)
                </label>
                <div className="flex items-center space-x-3">
                  <input
                    type="range"
                    min="10"
                    max="90"
                    value={settings.moistureMin}
                    onChange={e =>
                      handleInputChange('moistureMin', parseInt(e.target.value))
                    }
                    className="flex-1"
                  />
                  <span className="w-12 text-sm font-medium text-gray-900 dark:text-white">
                    {settings.moistureMin}%
                  </span>
                </div>
              </div>

              <div>
                <label className="mb-2 block text-sm text-gray-600 dark:text-gray-400">
                  Maximum (Stop watering when above)
                </label>
                <div className="flex items-center space-x-3">
                  <input
                    type="range"
                    min="20"
                    max="100"
                    value={settings.moistureMax}
                    onChange={e =>
                      handleInputChange('moistureMax', parseInt(e.target.value))
                    }
                    className="flex-1"
                  />
                  <span className="w-12 text-sm font-medium text-gray-900 dark:text-white">
                    {settings.moistureMax}%
                  </span>
                </div>
              </div>
            </div>
          </div>

          {/* Temperature Thresholds */}
          <div className="card p-4">
            <h4 className="mb-4 font-medium text-gray-900 dark:text-white">
              Temperature Range
            </h4>

            <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
              <div>
                <label className="mb-2 block text-sm text-gray-600 dark:text-gray-400">
                  Minimum Temperature
                </label>
                <div className="flex items-center space-x-3">
                  <input
                    type="range"
                    min="5"
                    max="25"
                    value={settings.temperatureMin}
                    onChange={e =>
                      handleInputChange(
                        'temperatureMin',
                        parseInt(e.target.value)
                      )
                    }
                    className="flex-1"
                  />
                  <span className="w-12 text-sm font-medium text-gray-900 dark:text-white">
                    {settings.temperatureMin}°C
                  </span>
                </div>
              </div>

              <div>
                <label className="mb-2 block text-sm text-gray-600 dark:text-gray-400">
                  Maximum Temperature
                </label>
                <div className="flex items-center space-x-3">
                  <input
                    type="range"
                    min="20"
                    max="45"
                    value={settings.temperatureMax}
                    onChange={e =>
                      handleInputChange(
                        'temperatureMax',
                        parseInt(e.target.value)
                      )
                    }
                    className="flex-1"
                  />
                  <span className="w-12 text-sm font-medium text-gray-900 dark:text-white">
                    {settings.temperatureMax}°C
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Watering Configuration */}
      <div>
        <h3 className="mb-4 text-lg font-semibold text-gray-900 dark:text-white">
          Watering Settings
        </h3>

        <div className="card space-y-4 p-4">
          {/* Auto-watering toggle */}
          <div className="flex items-center justify-between">
            <div>
              <div className="font-medium text-gray-900 dark:text-white">
                Automatic Watering
              </div>
              <div className="text-sm text-gray-600 dark:text-gray-400">
                Enable automatic watering based on sensor readings
              </div>
            </div>
            <label className="relative inline-flex cursor-pointer items-center">
              <input
                type="checkbox"
                checked={settings.autoWateringEnabled}
                onChange={e =>
                  handleInputChange('autoWateringEnabled', e.target.checked)
                }
                className="peer sr-only"
              />
              <div className="peer h-6 w-11 rounded-full bg-gray-200 after:absolute after:left-[2px] after:top-[2px] after:h-5 after:w-5 after:rounded-full after:bg-white after:transition-all after:content-[''] peer-checked:bg-primary-600 peer-checked:after:translate-x-full peer-checked:after:border-white peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-primary-300 dark:border-gray-600 dark:bg-gray-700 dark:peer-focus:ring-primary-800"></div>
            </label>
          </div>

          {/* Watering duration */}
          <div>
            <label className="mb-2 block text-sm text-gray-600 dark:text-gray-400">
              Watering Duration
            </label>
            <div className="flex items-center space-x-3">
              <input
                type="range"
                min="2000"
                max="30000"
                step="1000"
                value={settings.wateringDuration}
                onChange={e =>
                  handleInputChange(
                    'wateringDuration',
                    parseInt(e.target.value)
                  )
                }
                className="flex-1"
              />
              <span className="w-16 text-sm font-medium text-gray-900 dark:text-white">
                {(settings.wateringDuration / 1000).toFixed(1)}s
              </span>
            </div>
          </div>

          {/* Max daily waterings */}
          <div>
            <label className="mb-2 block text-sm text-gray-600 dark:text-gray-400">
              Maximum Daily Waterings
            </label>
            <div className="flex items-center space-x-3">
              <input
                type="range"
                min="1"
                max="8"
                value={settings.maxDailyWaterings}
                onChange={e =>
                  handleInputChange(
                    'maxDailyWaterings',
                    parseInt(e.target.value)
                  )
                }
                className="flex-1"
              />
              <span className="w-12 text-sm font-medium text-gray-900 dark:text-white">
                {settings.maxDailyWaterings}x
              </span>
            </div>
          </div>

          {/* Quiet hours */}
          <div>
            <label className="mb-2 block text-sm text-gray-600 dark:text-gray-400">
              Quiet Hours (No watering)
            </label>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <input
                  type="time"
                  value={settings.quietStart}
                  onChange={e =>
                    handleInputChange('quietStart', e.target.value)
                  }
                  className="input-field"
                />
                <div className="mt-1 text-xs text-gray-500">Start</div>
              </div>
              <div>
                <input
                  type="time"
                  value={settings.quietEnd}
                  onChange={e => handleInputChange('quietEnd', e.target.value)}
                  className="input-field"
                />
                <div className="mt-1 text-xs text-gray-500">End</div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Action Buttons */}
      <div className="flex items-center justify-between border-t border-gray-200 pt-6 dark:border-gray-700">
        <button
          className="btn-danger inline-flex items-center space-x-2"
          onClick={() => {
            if (confirm('Are you sure you want to delete this plant?')) {
              toast.success('Plant deletion not implemented yet');
            }
          }}
        >
          <Trash2 className="h-5 w-5" />
          <span>Delete Plant</span>
        </button>

        <div className="flex items-center space-x-3">
          {hasChanges && (
            <span className="text-sm text-yellow-600 dark:text-yellow-400">
              You have unsaved changes
            </span>
          )}

          <button
            onClick={handleSaveConfiguration}
            disabled={!hasChanges || updateConfigMutation.isLoading}
            className={`btn-primary inline-flex items-center space-x-2 ${
              !hasChanges ? 'cursor-not-allowed opacity-50' : ''
            }`}
          >
            <Check className="h-5 w-5" />
            <span>
              {updateConfigMutation.isLoading
                ? 'Saving...'
                : 'Save Configuration'}
            </span>
          </button>
        </div>
      </div>

      {/* Calibration Section */}
      <div>
        <h3 className="mb-4 text-lg font-semibold text-gray-900 dark:text-white">
          Sensor Calibration
        </h3>

        <div className="card p-4">
          <div className="mb-4 text-sm text-gray-600 dark:text-gray-400">
            Calibrate sensors for more accurate readings. Make sure the soil is
            in the desired state before calibrating.
          </div>

          <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
            <button
              className="btn-secondary"
              onClick={() => {
                toast.success('Dry calibration not implemented yet');
              }}
            >
              Calibrate Dry Soil
            </button>

            <button
              className="btn-secondary"
              onClick={() => {
                toast.success('Wet calibration not implemented yet');
              }}
            >
              Calibrate Wet Soil
            </button>
          </div>
        </div>
      </div>
    </motion.div>
  );
};

export default PlantSettings;
