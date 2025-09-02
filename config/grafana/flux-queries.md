# PlanetPlant Flux Queries für Grafana

## 1. Feuchtigkeitsverlauf (24h)
```flux
from(bucket: "sensor-data")
  |> range(start: -24h)
  |> filter(fn: (r) => r["_measurement"] == "sensor_data")
  |> filter(fn: (r) => r["sensor_type"] == "moisture")
  |> aggregateWindow(every: 5m, fn: mean, createEmpty: false)
  |> group(columns: ["plant_id"])
```

## 2. Temperatur & Luftfeuchtigkeit kombiniert
```flux
from(bucket: "sensor-data")
  |> range(start: -24h)
  |> filter(fn: (r) => r["_measurement"] == "sensor_data")
  |> filter(fn: (r) => r["sensor_type"] == "temperature" or r["sensor_type"] == "humidity")
  |> aggregateWindow(every: 10m, fn: mean, createEmpty: false)
  |> group(columns: ["sensor_type", "plant_id"])
```

## 3. Bewässerungs-Effizienz (Erfolgsrate)
```flux
from(bucket: "sensor-data")
  |> range(start: -7d)
  |> filter(fn: (r) => r["_measurement"] == "watering_events")
  |> filter(fn: (r) => r["_field"] == "success")
  |> aggregateWindow(every: 1d, fn: sum, createEmpty: false)
  |> map(fn: (r) => ({ r with _value: float(v: r._value) / float(v: r._value) * 100.0 }))
```

## 4. Sensor-Vergleiche (Aktuell)
```flux
from(bucket: "sensor-data")
  |> range(start: -1h)
  |> filter(fn: (r) => r["_measurement"] == "sensor_data")
  |> group(columns: ["plant_id", "sensor_type"])
  |> last()
  |> pivot(rowKey: ["plant_id"], columnKey: ["sensor_type"], valueColumn: "_value")
```

## 5. Trend-Analyse (30 Tage Feuchtigkeit)
```flux
from(bucket: "sensor-data")
  |> range(start: -30d)
  |> filter(fn: (r) => r["_measurement"] == "sensor_data")
  |> filter(fn: (r) => r["sensor_type"] == "moisture")
  |> aggregateWindow(every: 1d, fn: mean, createEmpty: false)
  |> derivative(unit: 1d, nonNegative: false)
  |> yield(name: "moisture_trend")
```

## 6. Anomalie-Erkennung
```flux
from(bucket: "sensor-data")
  |> range(start: -24h)
  |> filter(fn: (r) => r["_measurement"] == "sensor_data")
  |> filter(fn: (r) => r["sensor_type"] == "moisture")
  |> aggregateWindow(every: 1h, fn: mean)
  |> movingAverage(n: 6)
  |> map(fn: (r) => ({ 
      r with 
      anomaly: if r._value > r._value_ma * 1.5 or r._value < r._value_ma * 0.5 
               then "high" 
               else "normal" 
    }))
  |> filter(fn: (r) => r.anomaly == "high")
```

## 7. System Performance
```flux
from(bucket: "sensor-data")
  |> range(start: -1h)
  |> filter(fn: (r) => r["_measurement"] == "system_stats")
  |> aggregateWindow(every: 5m, fn: mean, createEmpty: false)
  |> group(columns: ["_field"])
```

## 8. Bewässerungs-Volumen pro Tag
```flux
from(bucket: "sensor-data")
  |> range(start: -7d)
  |> filter(fn: (r) => r["_measurement"] == "watering_events")
  |> filter(fn: (r) => r["_field"] == "volume_ml")
  |> aggregateWindow(every: 1d, fn: sum, createEmpty: false)
  |> group(columns: ["plant_id"])
```

## 9. Sensor-Qualität (Fehlerrate)
```flux
from(bucket: "sensor-data")
  |> range(start: -24h)
  |> filter(fn: (r) => r["_measurement"] == "sensor_data")
  |> filter(fn: (r) => r["quality"] != "good")
  |> group(columns: ["plant_id", "sensor_type"])
  |> count()
```

## 10. Aktuelle Alerts
```flux
from(bucket: "sensor-data")
  |> range(start: -1h)
  |> filter(fn: (r) => r["_measurement"] == "sensor_data")
  |> group(columns: ["plant_id", "sensor_type"])
  |> last()
  |> map(fn: (r) => ({ 
      r with 
      alert_type: if r.sensor_type == "moisture" and r._value < 20.0 then "low_moisture"
                 else if r.sensor_type == "temperature" and r._value > 35.0 then "high_temperature"
                 else if r.sensor_type == "temperature" and r._value < 10.0 then "low_temperature"
                 else "normal"
    }))
  |> filter(fn: (r) => r.alert_type != "normal")
```