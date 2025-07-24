const { createClient } = require('redis');
const logger = require('../utils/logger');

let redisClient = null;

const createRedisClient = () => {
  try {
    // Railway provides REDIS_URL, fallback to individual env vars
    const redisUrl = process.env.REDIS_URL || 
      `redis://${process.env.REDIS_HOST || 'localhost'}:${process.env.REDIS_PORT || 6379}`;
    
    const client = createClient({
      url: redisUrl,
      password: process.env.REDIS_PASSWORD || undefined,
      database: parseInt(process.env.REDIS_DB || '0'),
      socket: {
        connectTimeout: 60000,
        lazyConnect: true,
        reconnectStrategy: (retries) => {
          if (retries > 20) {
            logger.error('Redis reconnection failed after 20 attempts');
            return false;
          }
          return Math.min(retries * 50, 5000);
        }
      }
    });

    client.on('error', (err) => {
      logger.error('Redis Client Error:', err);
    });

    client.on('connect', () => {
      logger.info('Redis connected successfully');
    });

    client.on('reconnecting', () => {
      logger.info('Redis reconnecting...');
    });

    client.on('ready', () => {
      logger.info('Redis client ready');
    });

    return client;
  } catch (error) {
    logger.error('Failed to create Redis client:', error);
    return null;
  }
};

const getRedisClient = async () => {
  if (!redisClient) {
    redisClient = createRedisClient();
    if (redisClient) {
      try {
        await redisClient.connect();
      } catch (error) {
        logger.error('Failed to connect to Redis:', error);
        redisClient = null;
      }
    }
  }
  return redisClient;
};

const disconnectRedis = async () => {
  if (redisClient) {
    try {
      await redisClient.quit();
      redisClient = null;
      logger.info('Redis disconnected');
    } catch (error) {
      logger.error('Error disconnecting Redis:', error);
    }
  }
};

// Health check function
const isRedisHealthy = async () => {
  try {
    const client = await getRedisClient();
    if (!client) return false;
    
    const pong = await client.ping();
    return pong === 'PONG';
  } catch (error) {
    logger.error('Redis health check failed:', error);
    return false;
  }
};

module.exports = {
  getRedisClient,
  disconnectRedis,
  isRedisHealthy
}; 