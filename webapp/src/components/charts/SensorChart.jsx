import { motion } from 'framer-motion';
import React from 'react';
import {
  Area,
  AreaChart,
  CartesianGrid,
  Line,
  LineChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';

const SensorChart = ({
  data = [],
  sensorType = 'moisture',
  _timeRange = '24h',
  height = 300,
  showArea = false,
  animate = true,
}) => {
  // Sensor configuration
  const sensorConfigs = {
    moisture: {
      color: '#3b82f6',
      unit: '%',
      label: 'Soil Moisture',
      gradient: ['#3b82f6', '#1d4ed8'],
    },
    temperature: {
      color: '#ef4444',
      unit: '°C',
      label: 'Temperature',
      gradient: ['#ef4444', '#dc2626'],
    },
    humidity: {
      color: '#06b6d4',
      unit: '%',
      label: 'Air Humidity',
      gradient: ['#06b6d4', '#0891b2'],
    },
    light: {
      color: '#f59e0b',
      unit: 'lux',
      label: 'Light Level',
      gradient: ['#f59e0b', '#d97706'],
    },
  };

  const config = sensorConfigs[sensorType] || sensorConfigs.moisture;

  // Transform data for Recharts
  const chartData = data.map(item => ({
    timestamp: item.timestamp,
    value: item.value,
    time: new Date(item.timestamp).toLocaleTimeString('en-US', {
      hour: '2-digit',
      minute: '2-digit',
    }),
    date: new Date(item.timestamp).toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
    }),
  }));

  // Custom tooltip
  const CustomTooltip = ({ active, payload, label: _label }) => {
    if (active && payload && payload.length) {
      const data = payload[0];
      const timestamp = new Date(data.payload.timestamp);

      return (
        <motion.div
          initial={{ opacity: 0, scale: 0.9 }}
          animate={{ opacity: 1, scale: 1 }}
          className="rounded-lg border border-gray-200 bg-white p-3 shadow-lg dark:border-gray-700 dark:bg-gray-800"
        >
          <div className="mb-1 text-sm font-medium text-gray-900 dark:text-white">
            {config.label}
          </div>
          <div className="text-lg font-bold" style={{ color: config.color }}>
            {data.value?.toFixed(1)} {config.unit}
          </div>
          <div className="mt-1 text-xs text-gray-500 dark:text-gray-400">
            {timestamp.toLocaleString()}
          </div>
        </motion.div>
      );
    }
    return null;
  };

  // Custom dot for line chart
  const CustomDot = props => {
    const { cx, cy, payload } = props;
    if (!payload) return null;

    return (
      <motion.circle
        cx={cx}
        cy={cy}
        r={3}
        fill={config.color}
        stroke="white"
        strokeWidth={2}
        initial={animate ? { scale: 0, opacity: 0 } : {}}
        animate={animate ? { scale: 1, opacity: 1 } : {}}
        transition={{ delay: 0.5, duration: 0.3 }}
        className="drop-shadow-sm"
      />
    );
  };

  if (!chartData.length) {
    return (
      <div className="flex h-64 items-center justify-center text-gray-500 dark:text-gray-400">
        <div className="text-center">
          <div className="mb-4 text-6xl">📊</div>
          <div className="font-medium">No data available</div>
          <div className="text-sm">Waiting for sensor readings...</div>
        </div>
      </div>
    );
  }

  return (
    <motion.div
      initial={animate ? { opacity: 0, y: 20 } : {}}
      animate={animate ? { opacity: 1, y: 0 } : {}}
      transition={{ duration: 0.5 }}
      style={{ height }}
    >
      <ResponsiveContainer width="100%" height="100%">
        {showArea ? (
          <AreaChart
            data={chartData}
            margin={{ top: 5, right: 30, left: 20, bottom: 5 }}
          >
            <defs>
              <linearGradient
                id={`gradient-${sensorType}`}
                x1="0"
                y1="0"
                x2="0"
                y2="1"
              >
                <stop
                  offset="5%"
                  stopColor={config.gradient[0]}
                  stopOpacity={0.3}
                />
                <stop
                  offset="95%"
                  stopColor={config.gradient[1]}
                  stopOpacity={0.1}
                />
              </linearGradient>
            </defs>

            <CartesianGrid
              strokeDasharray="3 3"
              className="stroke-gray-200 dark:stroke-gray-700"
            />

            <XAxis
              dataKey="time"
              className="text-xs text-gray-500 dark:text-gray-400"
              axisLine={false}
              tickLine={false}
            />

            <YAxis
              className="text-xs text-gray-500 dark:text-gray-400"
              axisLine={false}
              tickLine={false}
              domain={['dataMin - 5', 'dataMax + 5']}
            />

            <Tooltip content={<CustomTooltip />} />

            <Area
              type="monotone"
              dataKey="value"
              stroke={config.color}
              strokeWidth={2}
              fill={`url(#gradient-${sensorType})`}
              dot={<CustomDot />}
              activeDot={{
                r: 5,
                fill: config.color,
                stroke: 'white',
                strokeWidth: 2,
              }}
            />
          </AreaChart>
        ) : (
          <LineChart
            data={chartData}
            margin={{ top: 5, right: 30, left: 20, bottom: 5 }}
          >
            <CartesianGrid
              strokeDasharray="3 3"
              className="stroke-gray-200 dark:stroke-gray-700"
            />

            <XAxis
              dataKey="time"
              className="text-xs text-gray-500 dark:text-gray-400"
              axisLine={false}
              tickLine={false}
            />

            <YAxis
              className="text-xs text-gray-500 dark:text-gray-400"
              axisLine={false}
              tickLine={false}
              domain={['dataMin - 5', 'dataMax + 5']}
            />

            <Tooltip content={<CustomTooltip />} />

            <Line
              type="monotone"
              dataKey="value"
              stroke={config.color}
              strokeWidth={3}
              dot={<CustomDot />}
              activeDot={{
                r: 6,
                fill: config.color,
                stroke: 'white',
                strokeWidth: 2,
                className: 'drop-shadow-sm',
              }}
            />
          </LineChart>
        )}
      </ResponsiveContainer>
    </motion.div>
  );
};

export default SensorChart;
