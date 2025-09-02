export default {
  apps: [{
    name: 'planetplant-server',
    script: 'src/app.js',
    cwd: '/home/pi/PlanetPlant/raspberry-pi',
    
    // Instance configuration
    instances: 1,
    exec_mode: 'fork',
    
    // Auto-restart configuration
    autorestart: true,
    watch: false,
    max_memory_restart: '512M',
    
    // Environment variables
    env: {
      NODE_ENV: 'development',
      PORT: 3000,
      LOG_LEVEL: 'info'
    },
    
    env_production: {
      NODE_ENV: 'production',
      PORT: 3000,
      LOG_LEVEL: 'warn',
      LOG_TO_CONSOLE: 'false',
      LOG_TO_FILE: 'true'
    },
    
    // Logging configuration
    log_file: '/home/pi/PlanetPlant/raspberry-pi/logs/pm2-combined.log',
    out_file: '/home/pi/PlanetPlant/raspberry-pi/logs/pm2-out.log',
    error_file: '/home/pi/PlanetPlant/raspberry-pi/logs/pm2-error.log',
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
    
    // Process management
    min_uptime: '10s',
    max_restarts: 10,
    restart_delay: 4000,
    
    // Monitoring
    monitoring: true,
    pmx: true,
    
    // Advanced configuration
    node_args: '--max-old-space-size=256',
    
    // Health check
    health_check_url: 'http://localhost:3000/health',
    health_check_grace_period: 3000,
    
    // Graceful shutdown
    kill_timeout: 5000,
    listen_timeout: 3000,
    
    // Advanced PM2 features
    increment_var: 'PORT',
    
    // Cron restart (optional - restart every day at 3 AM)
    cron_restart: '0 3 * * *',
    
    // Source map support
    source_map_support: true,
    
    // Disable automatic restart on specific exit codes
    stop_exit_codes: [0],
    
    // Environment-specific overrides
    env_staging: {
      NODE_ENV: 'staging',
      LOG_LEVEL: 'debug'
    }
  },
  
  // Optional: Separate worker for automation tasks
  {
    name: 'planetplant-automation',
    script: 'src/workers/automationWorker.js',
    cwd: '/home/pi/PlanetPlant/raspberry-pi',
    
    instances: 1,
    exec_mode: 'fork',
    
    autorestart: true,
    watch: false,
    max_memory_restart: '128M',
    
    env: {
      NODE_ENV: 'development',
      WORKER_TYPE: 'automation'
    },
    
    env_production: {
      NODE_ENV: 'production',
      WORKER_TYPE: 'automation',
      LOG_LEVEL: 'warn'
    },
    
    log_file: '/home/pi/PlanetPlant/raspberry-pi/logs/automation-combined.log',
    out_file: '/home/pi/PlanetPlant/raspberry-pi/logs/automation-out.log',
    error_file: '/home/pi/PlanetPlant/raspberry-pi/logs/automation-error.log',
    
    min_uptime: '10s',
    max_restarts: 5,
    restart_delay: 5000,
    
    // This worker is disabled by default - enable if you want separate automation process
    disabled: true
  }],
  
  // Deployment configuration
  deploy: {
    production: {
      user: 'pi',
      host: 'raspberry-pi.local',
      ref: 'origin/main',
      repo: 'https://github.com/yourusername/PlanetPlant.git',
      path: '/home/pi/PlanetPlant',
      'pre-deploy-local': '',
      'post-deploy': 'npm install --production && pm2 reload ecosystem.config.js --env production',
      'pre-setup': 'apt update && apt install git -y'
    }
  }
};