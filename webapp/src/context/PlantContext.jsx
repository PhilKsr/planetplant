import React, { createContext, useContext, useEffect, useReducer } from 'react';

import { useWebSocket } from './WebSocketContext';

const PlantContext = createContext();

export const usePlants = () => {
  const context = useContext(PlantContext);
  if (!context) {
    throw new Error('usePlants must be used within a PlantProvider');
  }
  return context;
};

// Plant state reducer
const plantReducer = (state, action) => {
  switch (action.type) {
    case 'SET_PLANTS':
      return {
        ...state,
        plants: action.payload,
        loading: false,
        error: null,
      };

    case 'UPDATE_PLANT':
      return {
        ...state,
        plants: state.plants.map(plant =>
          plant.id === action.payload.id
            ? { ...plant, ...action.payload }
            : plant
        ),
      };

    case 'UPDATE_SENSOR_DATA':
      return {
        ...state,
        plants: state.plants.map(plant =>
          plant.id === action.payload.plantId
            ? {
                ...plant,
                currentData: {
                  ...plant.currentData,
                  ...action.payload.data,
                  lastUpdate: action.payload.timestamp,
                },
              }
            : plant
        ),
      };

    case 'UPDATE_PLANT_STATUS':
      return {
        ...state,
        plants: state.plants.map(plant =>
          plant.id === action.payload.plantId
            ? {
                ...plant,
                status: {
                  ...plant.status,
                  ...action.payload.status,
                },
              }
            : plant
        ),
      };

    case 'SET_LOADING':
      return {
        ...state,
        loading: action.payload,
      };

    case 'SET_ERROR':
      return {
        ...state,
        error: action.payload,
        loading: false,
      };

    case 'CLEAR_ERROR':
      return {
        ...state,
        error: null,
      };

    case 'ADD_PLANT':
      return {
        ...state,
        plants: [...state.plants, action.payload],
      };

    case 'REMOVE_PLANT':
      return {
        ...state,
        plants: state.plants.filter(plant => plant.id !== action.payload),
      };

    default:
      return state;
  }
};

const initialState = {
  plants: [],
  loading: true,
  error: null,
  lastUpdate: null,
};

export const PlantProvider = ({ children }) => {
  const [state, dispatch] = useReducer(plantReducer, initialState);
  const { subscribe, lastMessage } = useWebSocket();

  // Subscribe to WebSocket updates
  useEffect(() => {
    if (!subscribe) return;

    const unsubscribers = [
      // Sensor data updates
      subscribe('sensorData', data => {
        dispatch({
          type: 'UPDATE_SENSOR_DATA',
          payload: data,
        });
      }),

      // Plant status updates
      subscribe('plantStatus', data => {
        dispatch({
          type: 'UPDATE_PLANT_STATUS',
          payload: data,
        });
      }),

      // Plants data (bulk update)
      subscribe('plantsData', data => {
        dispatch({
          type: 'SET_PLANTS',
          payload: data.plants,
        });
      }),

      // Configuration updates
      subscribe('configUpdated', data => {
        dispatch({
          type: 'UPDATE_PLANT',
          payload: {
            id: data.plantId,
            config: data.config,
            updated: data.timestamp,
          },
        });
      }),

      // Watering events
      subscribe('wateringStarted', data => {
        dispatch({
          type: 'UPDATE_PLANT',
          payload: {
            id: data.plantId,
            stats: {
              lastWatering: data.timestamp,
            },
          },
        });
      }),

      subscribe('automaticWateringStarted', data => {
        dispatch({
          type: 'UPDATE_PLANT',
          payload: {
            id: data.plantId,
            stats: {
              lastWatering: data.timestamp,
            },
          },
        });
      }),
    ];

    // Cleanup subscriptions
    return () => {
      unsubscribers.forEach(unsubscribe => {
        if (typeof unsubscribe === 'function') {
          unsubscribe();
        }
      });
    };
  }, [subscribe]);

  // Action creators
  const actions = {
    setPlants: plants => {
      dispatch({ type: 'SET_PLANTS', payload: plants });
    },

    updatePlant: plant => {
      dispatch({ type: 'UPDATE_PLANT', payload: plant });
    },

    addPlant: plant => {
      dispatch({ type: 'ADD_PLANT', payload: plant });
    },

    removePlant: plantId => {
      dispatch({ type: 'REMOVE_PLANT', payload: plantId });
    },

    setLoading: loading => {
      dispatch({ type: 'SET_LOADING', payload: loading });
    },

    setError: error => {
      dispatch({ type: 'SET_ERROR', payload: error });
    },

    clearError: () => {
      dispatch({ type: 'CLEAR_ERROR' });
    },
  };

  // Utility functions
  const getPlantById = plantId => {
    return state.plants.find(plant => plant.id === plantId);
  };

  const getOnlinePlants = () => {
    return state.plants.filter(plant => plant.status?.isOnline);
  };

  const getPlantsNeedingWater = () => {
    return state.plants.filter(plant => {
      const moisture = plant.currentData?.moisture;
      const threshold = plant.config?.moistureThresholds?.min || 30;
      return moisture !== null && moisture < threshold;
    });
  };

  const getPlantsSummary = () => {
    return {
      total: state.plants.length,
      online: getOnlinePlants().length,
      needingWater: getPlantsNeedingWater().length,
      offline: state.plants.length - getOnlinePlants().length,
    };
  };

  const value = {
    // State
    plants: state.plants,
    loading: state.loading,
    error: state.error,
    lastUpdate: state.lastUpdate,

    // Actions
    ...actions,

    // Utilities
    getPlantById,
    getOnlinePlants,
    getPlantsNeedingWater,
    getPlantsSummary,

    // WebSocket message for debugging
    lastMessage,
  };

  return (
    <PlantContext.Provider value={value}>{children}</PlantContext.Provider>
  );
};
