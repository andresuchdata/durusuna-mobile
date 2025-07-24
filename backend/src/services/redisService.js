const { getRedisClient } = require('../config/redis');
const logger = require('../utils/logger');

class RedisService {
  constructor() {
    this.client = null;
  }

  async initialize() {
    try {
      this.client = await getRedisClient();
      return this.client !== null;
    } catch (error) {
      logger.error('Failed to initialize Redis service:', error);
      return false;
    }
  }

  // Session Management
  async setSession(sessionId, data, ttl = 3600) {
    try {
      if (!this.client) await this.initialize();
      if (!this.client) return false;

      const key = `session:${sessionId}`;
      await this.client.setEx(key, ttl, JSON.stringify(data));
      return true;
    } catch (error) {
      logger.error('Error setting session:', error);
      return false;
    }
  }

  async getSession(sessionId) {
    try {
      if (!this.client) await this.initialize();
      if (!this.client) return null;

      const key = `session:${sessionId}`;
      const data = await this.client.get(key);
      return data ? JSON.parse(data) : null;
    } catch (error) {
      logger.error('Error getting session:', error);
      return null;
    }
  }

  async deleteSession(sessionId) {
    try {
      if (!this.client) await this.initialize();
      if (!this.client) return false;

      const key = `session:${sessionId}`;
      await this.client.del(key);
      return true;
    } catch (error) {
      logger.error('Error deleting session:', error);
      return false;
    }
  }

  // Caching
  async set(key, value, ttl = 3600) {
    try {
      if (!this.client) await this.initialize();
      if (!this.client) return false;

      if (ttl > 0) {
        await this.client.setEx(key, ttl, JSON.stringify(value));
      } else {
        await this.client.set(key, JSON.stringify(value));
      }
      return true;
    } catch (error) {
      logger.error('Error setting cache:', error);
      return false;
    }
  }

  async get(key) {
    try {
      if (!this.client) await this.initialize();
      if (!this.client) return null;

      const data = await this.client.get(key);
      return data ? JSON.parse(data) : null;
    } catch (error) {
      logger.error('Error getting cache:', error);
      return null;
    }
  }

  async del(key) {
    try {
      if (!this.client) await this.initialize();
      if (!this.client) return false;

      await this.client.del(key);
      return true;
    } catch (error) {
      logger.error('Error deleting cache:', error);
      return false;
    }
  }

  // Rate Limiting Support
  async incrementCounter(key, ttl = 3600) {
    try {
      if (!this.client) await this.initialize();
      if (!this.client) return 0;

      const multi = this.client.multi();
      multi.incr(key);
      multi.expire(key, ttl);
      const results = await multi.exec();
      
      return results[0] || 0;
    } catch (error) {
      logger.error('Error incrementing counter:', error);
      return 0;
    }
  }

  // Real-time features
  async setUserOnline(userId) {
    try {
      if (!this.client) await this.initialize();
      if (!this.client) return false;

      const key = `user:online:${userId}`;
      await this.client.setEx(key, 300, Date.now()); // 5 minutes
      return true;
    } catch (error) {
      logger.error('Error setting user online:', error);
      return false;
    }
  }

  async isUserOnline(userId) {
    try {
      if (!this.client) await this.initialize();
      if (!this.client) return false;

      const key = `user:online:${userId}`;
      const result = await this.client.exists(key);
      return result === 1;
    } catch (error) {
      logger.error('Error checking user online status:', error);
      return false;
    }
  }

  async setUserOffline(userId) {
    try {
      if (!this.client) await this.initialize();
      if (!this.client) return false;

      const key = `user:online:${userId}`;
      await this.client.del(key);
      return true;
    } catch (error) {
      logger.error('Error setting user offline:', error);
      return false;
    }
  }

  // Pub/Sub for real-time messaging
  async publish(channel, message) {
    try {
      if (!this.client) await this.initialize();
      if (!this.client) return false;

      await this.client.publish(channel, JSON.stringify(message));
      return true;
    } catch (error) {
      logger.error('Error publishing message:', error);
      return false;
    }
  }

  // Health check
  async ping() {
    try {
      if (!this.client) await this.initialize();
      if (!this.client) return false;

      const pong = await this.client.ping();
      return pong === 'PONG';
    } catch (error) {
      logger.error('Redis ping failed:', error);
      return false;
    }
  }

  // Graceful shutdown
  async disconnect() {
    try {
      if (this.client) {
        await this.client.quit();
        this.client = null;
        logger.info('Redis service disconnected');
      }
    } catch (error) {
      logger.error('Error disconnecting Redis service:', error);
    }
  }
}

// Create singleton instance
const redisService = new RedisService();

module.exports = redisService; 