export const mqttConfig = {
  broker: {
    host: process.env.MQTT_HOST || 'localhost',
    port: parseInt(process.env.MQTT_PORT) || 1883,
    username: process.env.MQTT_USERNAME,
    password: process.env.MQTT_PASSWORD
  },
  
  client: {
    clientId: process.env.MQTT_CLIENT_ID || `plantplant-server-${Date.now()}`,
    keepalive: parseInt(process.env.MQTT_KEEPALIVE) || 60,
    connectTimeout: parseInt(process.env.MQTT_CONNECT_TIMEOUT) || 10000,
    reconnectPeriod: parseInt(process.env.MQTT_RECONNECT_INTERVAL) || 5000,
    clean: true
  },
  
  topics: {
    // Incoming topics (subscribe)
    sensors: {
      data: 'sensors/+/data',
      status: 'sensors/+/status'
    },
    
    devices: {
      heartbeat: 'devices/+/heartbeat',
      status: 'devices/+/status'
    },
    
    // Outgoing topics (publish)
    commands: {
      water: 'commands/{plant_id}/water',
      config: 'commands/{plant_id}/config',
      calibrate: 'commands/{plant_id}/calibrate',
      system: 'commands/system'
    },
    
    server: {
      status: 'server/status',
      heartbeat: 'server/heartbeat'
    }
  },
  
  qos: {
    sensor_data: 1,
    commands: 1,
    status: 1,
    heartbeat: 0
  }
};

export const getTopicForPlant = (template, plantId) => {
  return template.replace('{plant_id}', plantId);
};