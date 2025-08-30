import Joi from 'joi';

// Plant configuration validation schema
export const plantConfigSchema = Joi.object({
  moistureThresholds: Joi.object({
    min: Joi.number().min(0).max(100),
    max: Joi.number().min(0).max(100).greater(Joi.ref('min'))
  }),
  
  temperatureThresholds: Joi.object({
    min: Joi.number().min(-50).max(100),
    max: Joi.number().min(-50).max(100).greater(Joi.ref('min'))
  }),
  
  wateringConfig: Joi.object({
    duration: Joi.number().min(1000).max(30000),
    maxDailyWaterings: Joi.number().min(1).max(10),
    quietHours: Joi.object({
      start: Joi.string().pattern(/^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$/),
      end: Joi.string().pattern(/^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$/)
    }),
    cooldownMs: Joi.number().min(60000).max(3600000)
  }),
  
  alertConfig: Joi.object({
    lowMoisture: Joi.boolean(),
    highTemperature: Joi.boolean(),
    deviceOffline: Joi.boolean(),
    wateringFailed: Joi.boolean()
  })
});

// Sensor data validation schema
export const sensorDataSchema = Joi.object({
  temperature: Joi.number().min(-50).max(100).required(),
  humidity: Joi.number().min(0).max(100).required(),
  moisture: Joi.number().min(0).max(100).required(),
  light: Joi.number().min(0).optional(),
  batteryLevel: Joi.number().min(0).max(100).optional(),
  wifiStrength: Joi.number().min(-100).max(0).optional()
});

// Watering request validation schema
export const wateringRequestSchema = Joi.object({
  duration: Joi.number().min(1000).max(30000).default(5000),
  reason: Joi.string().max(255).default('manual')
});

// Plant update validation schema
export const plantUpdateSchema = Joi.object({
  name: Joi.string().min(1).max(100),
  type: Joi.string().valid('houseplant', 'herb', 'vegetable', 'succulent', 'flower', 'tree', 'other'),
  location: Joi.string().max(100)
});

// System command validation schema
export const systemCommandSchema = Joi.object({
  command: Joi.string().valid('restart', 'cleanup', 'test', 'backup').required(),
  parameters: Joi.object().default({})
});

// Query parameters validation schemas
export const timeRangeSchema = Joi.string().valid('1h', '6h', '12h', '24h', '7d', '30d').default('24h');

export const paginationSchema = Joi.object({
  page: Joi.number().min(1).default(1),
  limit: Joi.number().min(1).max(1000).default(100),
  sortBy: Joi.string().default('timestamp'),
  sortOrder: Joi.string().valid('asc', 'desc').default('desc')
});

// Validation middleware factory
export const validate = (schema, property = 'body') => {
  return (req, res, next) => {
    const { error, value } = schema.validate(req[property], {
      abortEarly: false,
      stripUnknown: true
    });

    if (error) {
      const details = error.details.map(detail => ({
        field: detail.path.join('.'),
        message: detail.message,
        value: detail.context?.value
      }));

      return res.status(400).json({
        success: false,
        error: {
          message: 'Validation error',
          details
        }
      });
    }

    // Replace the original data with validated data
    req[property] = value;
    next();
  };
};

// Specific validation middlewares
export const validatePlantConfig = validate(plantConfigSchema);
export const validateSensorData = validate(sensorDataSchema);
export const validateWateringRequest = validate(wateringRequestSchema);
export const validatePlantUpdate = validate(plantUpdateSchema);
export const validateSystemCommand = validate(systemCommandSchema);
export const validateTimeRange = validate(timeRangeSchema, 'query');
export const validatePagination = validate(paginationSchema, 'query');