import Database from 'better-sqlite3';
import path from 'path';
import { fileURLToPath } from 'url';
import fs from 'fs';
import dotenv from 'dotenv';

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const DB_PATH = process.env.DB_PATH || path.join(__dirname, '../data/plantdata.db');

console.log('🗄️  Initializing PlanetPlant SQLite Database...');
console.log(`Database path: ${DB_PATH}`);

const dbDir = path.dirname(DB_PATH);
if (!fs.existsSync(dbDir)) {
  console.log(`Creating database directory: ${dbDir}`);
  fs.mkdirSync(dbDir, { recursive: true });
}

const db = new Database(DB_PATH);

console.log('⚡ Setting SQLite pragmas for optimal Raspberry Pi performance...');
db.pragma('journal_mode = WAL');
db.pragma('synchronous = NORMAL');
db.pragma('cache_size = 10000');
db.pragma('temp_store = memory');
db.pragma('mmap_size = 268435456'); // 256MB

console.log('📋 Creating sensor_data table...');
const createSensorDataTable = `
  CREATE TABLE IF NOT EXISTS sensor_data (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp INTEGER NOT NULL,
    device TEXT NOT NULL,
    location TEXT,
    plant_id TEXT NOT NULL,
    sensor_type TEXT NOT NULL,
    value REAL NOT NULL,
    unit TEXT NOT NULL,
    created_at INTEGER DEFAULT (unixepoch() * 1000)
  )
`;
db.exec(createSensorDataTable);

console.log('💧 Creating watering_events table...');
const createWateringEventsTable = `
  CREATE TABLE IF NOT EXISTS watering_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp INTEGER NOT NULL,
    plant_id TEXT NOT NULL,
    trigger_type TEXT NOT NULL DEFAULT 'manual',
    duration_ms INTEGER NOT NULL,
    volume_ml REAL DEFAULT 0,
    success INTEGER DEFAULT 1,
    reason TEXT,
    created_at INTEGER DEFAULT (unixepoch() * 1000)
  )
`;
db.exec(createWateringEventsTable);

console.log('🔧 Creating system_events table...');
const createSystemEventsTable = `
  CREATE TABLE IF NOT EXISTS system_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp INTEGER NOT NULL,
    event_type TEXT NOT NULL,
    severity TEXT DEFAULT 'info',
    message TEXT,
    details TEXT,
    created_at INTEGER DEFAULT (unixepoch() * 1000)
  )
`;
db.exec(createSystemEventsTable);

console.log('📊 Creating performance indexes...');
const indexes = [
  'CREATE INDEX IF NOT EXISTS idx_sensor_data_timestamp ON sensor_data(timestamp)',
  'CREATE INDEX IF NOT EXISTS idx_sensor_data_plant_id ON sensor_data(plant_id)',
  'CREATE INDEX IF NOT EXISTS idx_sensor_data_type ON sensor_data(sensor_type)',
  'CREATE INDEX IF NOT EXISTS idx_sensor_data_plant_type ON sensor_data(plant_id, sensor_type)',
  'CREATE INDEX IF NOT EXISTS idx_watering_plant_id ON watering_events(plant_id)',
  'CREATE INDEX IF NOT EXISTS idx_watering_timestamp ON watering_events(timestamp)',
  'CREATE INDEX IF NOT EXISTS idx_system_events_type ON system_events(event_type)',
  'CREATE INDEX IF NOT EXISTS idx_system_events_timestamp ON system_events(timestamp)'
];

indexes.forEach(indexSQL => {
  db.exec(indexSQL);
});

console.log('🧪 Inserting test data...');
const insertTestData = db.transaction(() => {
  const now = Date.now();
  const testPlantId = 'plant-001';
  
  const testSensorData = [
    { sensor_type: 'temperature', value: 22.5, unit: '°C' },
    { sensor_type: 'humidity', value: 65.0, unit: '%' },
    { sensor_type: 'moisture', value: 45.0, unit: '%' },
    { sensor_type: 'light', value: 850.0, unit: 'lux' }
  ];
  
  const insertSensor = db.prepare(`
    INSERT INTO sensor_data (timestamp, device, plant_id, sensor_type, value, unit)
    VALUES (?, ?, ?, ?, ?, ?)
  `);
  
  testSensorData.forEach(data => {
    insertSensor.run(now, 'esp32-001', testPlantId, data.sensor_type, data.value, data.unit);
  });
  
  const insertWatering = db.prepare(`
    INSERT INTO watering_events (timestamp, plant_id, trigger_type, duration_ms, volume_ml, success)
    VALUES (?, ?, ?, ?, ?, ?)
  `);
  
  insertWatering.run(now - 3600000, testPlantId, 'automatic', 5000, 25.0, 1);
  
  const insertSystem = db.prepare(`
    INSERT INTO system_events (timestamp, event_type, severity, message)
    VALUES (?, ?, ?, ?)
  `);
  
  insertSystem.run(now, 'database_initialized', 'info', 'SQLite database initialized successfully');
});

insertTestData();

console.log('📈 Database statistics:');
const sensorCount = db.prepare('SELECT COUNT(*) as count FROM sensor_data').get();
const wateringCount = db.prepare('SELECT COUNT(*) as count FROM watering_events').get();
const systemCount = db.prepare('SELECT COUNT(*) as count FROM system_events').get();

console.log(`  - Sensor records: ${sensorCount.count}`);
console.log(`  - Watering records: ${wateringCount.count}`);
console.log(`  - System records: ${systemCount.count}`);

const dbSize = fs.statSync(DB_PATH).size;
console.log(`  - Database size: ${(dbSize / 1024).toFixed(2)} KB`);

console.log('🏥 Testing database health...');
const testQuery = db.prepare(`
  SELECT sensor_type, value, unit, timestamp
  FROM sensor_data
  WHERE plant_id = ?
  ORDER BY timestamp DESC
  LIMIT 5
`);

const testResults = testQuery.all('plant-001');
console.log(`  - Test query returned ${testResults.length} records`);

db.close();
console.log('✅ Database initialization completed successfully!');
console.log('');
console.log('🚀 Next steps:');
console.log('  1. Copy .env.example to .env');
console.log('  2. Update DB_PATH in .env if needed');
console.log('  3. Run: cd raspberry-pi && npm install');
console.log('  4. Run: npm start');