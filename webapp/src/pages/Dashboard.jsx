import { Plus } from 'lucide-react';
import { useQuery } from '@tanstack/react-query';
import { motion } from 'framer-motion';
import React from 'react';

import DashboardStats from '../components/DashboardStats';
import PlantCard from '../components/PlantCard';
import ErrorState from '../components/ui/ErrorState';
import LoadingSpinner from '../components/ui/LoadingSpinner';
import { usePlants } from '../context/PlantContext';
import { plantsApi } from '../services/api';

const Dashboard = () => {
  const { plants, setPlants, setLoading, setError } = usePlants();

  // Fetch plants data
  const { isLoading, error, refetch } = useQuery({
    queryKey: ['plants'],
    queryFn: async () => {
      const response = await plantsApi.getAll();
      return response.data;
    },
    onSuccess: data => {
      setPlants(data.data);
      setLoading(false);
    },
    onError: error => {
      setError(error.message);
      setLoading(false);
    },
    refetchInterval: 60000, // Refetch every minute
  });

  // Container animation variants
  const containerVariants = {
    hidden: { opacity: 0 },
    visible: {
      opacity: 1,
      transition: {
        duration: 0.3,
        staggerChildren: 0.1,
      },
    },
  };

  // Card animation variants
  const cardVariants = {
    hidden: {
      opacity: 0,
      y: 20,
      scale: 0.95,
    },
    visible: {
      opacity: 1,
      y: 0,
      scale: 1,
      transition: {
        duration: 0.3,
        ease: 'easeOut',
      },
    },
  };

  if (isLoading) {
    return (
      <div className="flex min-h-[60vh] items-center justify-center">
        <LoadingSpinner size="lg" message="Loading your plants..." />
      </div>
    );
  }

  if (error) {
    return (
      <ErrorState
        title="Failed to load plants"
        message="There was an error loading your plant data."
        onRetry={refetch}
      />
    );
  }

  return (
    <motion.div
      variants={containerVariants}
      initial="hidden"
      animate="visible"
      className="space-y-6"
    >
      {/* Page Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white">
            My Plants
          </h1>
          <p className="mt-1 text-sm text-gray-600 dark:text-gray-400">
            Monitor and care for your plants in real-time
          </p>
        </div>

        <motion.button
          variants={cardVariants}
          className="btn-primary mt-4 inline-flex items-center space-x-2 sm:mt-0"
          whileHover={{ scale: 1.05 }}
          whileTap={{ scale: 0.95 }}
        >
          <Plus className="h-5 w-5" />
          <span>Add Plant</span>
        </motion.button>
      </div>

      {/* Dashboard Stats */}
      <motion.div variants={cardVariants}>
        <DashboardStats />
      </motion.div>

      {/* Plants Grid */}
      {plants.length > 0 ? (
        <motion.div
          variants={containerVariants}
          className="grid grid-cols-1 gap-6 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4"
        >
          {plants.map(plant => (
            <motion.div key={plant.id} variants={cardVariants}>
              <PlantCard plant={plant} />
            </motion.div>
          ))}
        </motion.div>
      ) : (
        <motion.div variants={cardVariants} className="py-12 text-center">
          <div className="mx-auto mb-4 flex h-24 w-24 items-center justify-center rounded-full bg-gray-100 dark:bg-gray-800">
            <span className="text-4xl">🌱</span>
          </div>
          <h3 className="mb-2 text-lg font-semibold text-gray-900 dark:text-white">
            No plants yet
          </h3>
          <p className="mx-auto mb-6 max-w-sm text-gray-600 dark:text-gray-400">
            Add your first plant to start monitoring its health and growth.
          </p>
          <motion.button
            className="btn-primary inline-flex items-center space-x-2"
            whileHover={{ scale: 1.05 }}
            whileTap={{ scale: 0.95 }}
          >
            <Plus className="h-5 w-5" />
            <span>Add Your First Plant</span>
          </motion.button>
        </motion.div>
      )}

      {/* Mobile spacing for bottom navigation */}
      <div className="h-20 lg:h-0" />
    </motion.div>
  );
};

export default Dashboard;
