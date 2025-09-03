const express = require('express');
const axios = require('axios');
const app = express();

const SERVICES = {
  'backend-prod': 'http://localhost:3001/api/health',
  'backend-staging': 'http://localhost:3002/api/health', 
  'frontend-prod': 'http://localhost/health',
  'frontend-staging': 'http://localhost:8080/health',
  'influxdb-prod': 'http://localhost:8086/ping',
  'influxdb-staging': 'http://localhost:8087/ping',
  'prometheus': 'http://localhost:9091/-/healthy',
  'grafana': 'http://localhost:3006/api/health',
  'uptime-kuma': 'http://localhost:3005/api/status-page/heartbeat'
};

app.get('/api/badge/:service/status', async (req, res) => {
  const service = req.params.service;
  const url = SERVICES[service];
  
  if (!url) {
    return res.json({
      schemaVersion: 1,
      label: service,
      message: "unknown",
      color: "lightgrey"
    });
  }
  
  try {
    const response = await axios.get(url, { timeout: 5000 });
    const status = response.status === 200 ? 'online' : 'degraded';
    const color = status === 'online' ? 'brightgreen' : 'yellow';
    
    res.json({
      schemaVersion: 1,
      label: service,
      message: status,
      color: color,
      namedLogo: 'raspberry-pi',
      logoColor: 'white'
    });
  } catch (error) {
    res.json({
      schemaVersion: 1,
      label: service,
      message: "offline",
      color: "red",
      namedLogo: 'raspberry-pi',
      logoColor: 'white'
    });
  }
});

app.get('/api/badge/system/overall', async (req, res) => {
  const criticalServices = ['backend-prod', 'influxdb-prod', 'uptime-kuma'];
  let onlineCount = 0;
  
  for (const service of criticalServices) {
    try {
      const response = await axios.get(SERVICES[service], { timeout: 3000 });
      if (response.status === 200) onlineCount++;
    } catch (error) {
      // Service offline
    }
  }
  
  const status = onlineCount === criticalServices.length ? 'online' : 
                 onlineCount > 0 ? 'degraded' : 'offline';
  const color = status === 'online' ? 'brightgreen' : 
                status === 'degraded' ? 'yellow' : 'red';
  
  res.json({
    schemaVersion: 1,
    label: 'system',
    message: status,
    color: color,
    namedLogo: 'raspberry-pi',
    logoColor: 'white'
  });
});

app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

const PORT = process.env.BADGE_API_PORT || 3007;
app.listen(PORT, () => {
  console.log(`Status Badge API listening on port ${PORT}`);
});