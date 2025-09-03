const express = require('express');
const fs = require('fs-extra');
const path = require('path');
const { execSync } = require('child_process');

const app = express();
app.use(express.json());

// Configuration
const BACKUP_DIR = process.env.BACKUP_DIR || '/backups';
const LOG_DIR = process.env.LOG_DIR || '/logs';

// Get backup status and statistics
app.get('/api/status', async (req, res) => {
  try {
    // Check if Restic repository exists
    const repoExists = await fs.pathExists(path.join(BACKUP_DIR, 'restic-repo'));
    
    if (!repoExists) {
      return res.json({
        status: 'not_initialized',
        message: 'Backup repository not initialized',
        repository_path: BACKUP_DIR
      });
    }
    
    // Get Restic repository stats
    let resticStats = {};
    try {
      const statsOutput = execSync('restic stats --mode raw-data --json', {
        env: {
          ...process.env,
          RESTIC_REPOSITORY: path.join(BACKUP_DIR, 'restic-repo'),
          RESTIC_PASSWORD: process.env.RESTIC_PASSWORD
        },
        encoding: 'utf8'
      });
      resticStats = JSON.parse(statsOutput);
    } catch (error) {
      console.error('Failed to get restic stats:', error.message);
    }
    
    // Get recent snapshots
    let snapshots = [];
    try {
      const snapshotsOutput = execSync('restic snapshots --json', {
        env: {
          ...process.env,
          RESTIC_REPOSITORY: path.join(BACKUP_DIR, 'restic-repo'),
          RESTIC_PASSWORD: process.env.RESTIC_PASSWORD
        },
        encoding: 'utf8'
      });
      snapshots = JSON.parse(snapshotsOutput).slice(-10); // Last 10 snapshots
    } catch (error) {
      console.error('Failed to get snapshots:', error.message);
    }
    
    // Get backup logs
    let lastBackupLog = null;
    try {
      const logFile = path.join(LOG_DIR, 'backup.log');
      if (await fs.pathExists(logFile)) {
        const logContent = await fs.readFile(logFile, 'utf8');
        const logLines = logContent.split('\n').filter(line => line.trim());
        lastBackupLog = logLines.slice(-20); // Last 20 lines
      }
    } catch (error) {
      console.error('Failed to read backup log:', error.message);
    }
    
    res.json({
      status: 'initialized',
      repository: {
        path: BACKUP_DIR,
        size_bytes: resticStats.total_size || 0,
        size_human: formatBytes(resticStats.total_size || 0),
        file_count: resticStats.total_file_count || 0
      },
      snapshots: {
        total: snapshots.length,
        latest: snapshots[snapshots.length - 1] || null,
        recent: snapshots.map(s => ({
          id: s.short_id,
          time: s.time,
          tags: s.tags || [],
          hostname: s.hostname,
          username: s.username
        }))
      },
      logs: {
        recent_entries: lastBackupLog || [],
        log_file: path.join(LOG_DIR, 'backup.log')
      },
      next_scheduled: getNextScheduledBackup(),
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    console.error('Backup status error:', error);
    res.status(500).json({
      status: 'error',
      message: 'Failed to retrieve backup status',
      error: error.message
    });
  }
});

// Get detailed snapshot information
app.get('/api/snapshots/:id', async (req, res) => {
  try {
    const snapshotId = req.params.id;
    
    const snapshotOutput = execSync(`restic snapshots ${snapshotId} --json`, {
      env: {
        ...process.env,
        RESTIC_REPOSITORY: path.join(BACKUP_DIR, 'restic-repo'),
        RESTIC_PASSWORD: process.env.RESTIC_PASSWORD
      },
      encoding: 'utf8'
    });
    
    const snapshot = JSON.parse(snapshotOutput)[0];
    
    res.json({
      success: true,
      data: snapshot
    });
    
  } catch (error) {
    res.status(404).json({
      success: false,
      error: 'Snapshot not found or access failed'
    });
  }
});

// Trigger manual backup
app.post('/api/backup/trigger', async (req, res) => {
  try {
    const { type = 'manual' } = req.body;
    
    // Validate backup type
    if (!['daily', 'weekly', 'monthly', 'manual'].includes(type)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid backup type'
      });
    }
    
    // Trigger backup script
    console.log(`Triggering ${type} backup...`);
    
    // Execute backup in background
    execSync(`/scripts/backup-all.sh ${type} > /logs/manual-backup.log 2>&1 &`, {
      stdio: 'inherit'
    });
    
    res.json({
      success: true,
      message: `${type} backup triggered`,
      type: type,
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    res.status(500).json({
      success: false,
      error: 'Failed to trigger backup',
      details: error.message
    });
  }
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    service: 'planetplant-backup-monitor',
    timestamp: new Date().toISOString()
  });
});

// Utility functions
function formatBytes(bytes) {
  const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
  if (bytes === 0) return '0 Bytes';
  const i = Math.floor(Math.log(bytes) / Math.log(1024));
  return Math.round(bytes / Math.pow(1024, i) * 100) / 100 + ' ' + sizes[i];
}

function getNextScheduledBackup() {
  // Simple next backup calculation based on current time
  const now = new Date();
  const tomorrow = new Date(now);
  tomorrow.setDate(tomorrow.getDate() + 1);
  tomorrow.setHours(2, 0, 0, 0); // 02:00 next day
  
  return {
    next_daily: tomorrow.toISOString(),
    next_weekly: getNextSunday().toISOString(),
    next_monthly: getFirstOfNextMonth().toISOString()
  };
}

function getNextSunday() {
  const now = new Date();
  const nextSunday = new Date(now);
  nextSunday.setDate(now.getDate() + (7 - now.getDay()));
  nextSunday.setHours(3, 0, 0, 0);
  return nextSunday;
}

function getFirstOfNextMonth() {
  const now = new Date();
  const nextMonth = new Date(now.getFullYear(), now.getMonth() + 1, 1);
  nextMonth.setHours(4, 0, 0, 0);
  return nextMonth;
}

// Error handling
app.use((error, req, res, next) => {
  console.error('API Error:', error);
  res.status(500).json({
    success: false,
    error: 'Internal server error'
  });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Backup Monitor API listening on port ${PORT}`);
});