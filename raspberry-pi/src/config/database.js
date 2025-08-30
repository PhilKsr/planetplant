export const influxConfig = {
  url: process.env.INFLUXDB_URL || 'http://localhost:8086',
  token: process.env.INFLUXDB_TOKEN,
  org: process.env.INFLUXDB_ORG || 'plantplant',
  bucket: process.env.INFLUXDB_BUCKET || 'sensors',
  precision: 's'
};

export const measurements = {
  SENSOR_DATA: 'sensor_data',
  WATERING_EVENTS: 'watering_events',
  SYSTEM_EVENTS: 'system_events',
  DEVICE_STATUS: 'device_status'
};

export const tags = {
  PLANT_ID: 'plant_id',
  SENSOR_TYPE: 'sensor_type',
  EVENT_TYPE: 'event_type',
  DEVICE_ID: 'device_id',
  SEVERITY: 'severity'
};

export const fields = {
  VALUE: 'value',
  UNIT: 'unit',
  DURATION: 'duration_ms',
  VOLUME: 'volume_ml',
  SUCCESS: 'success',
  MESSAGE: 'message',
  DETAILS: 'details'
};