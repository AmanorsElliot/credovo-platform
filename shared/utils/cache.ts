import { createLogger } from './logger';

const logger = createLogger('cache');

/**
 * Simple in-memory cache with TTL (Time To Live)
 * Suitable for single-instance deployments
 * For distributed systems, consider Redis or Memcached
 */
export class InMemoryCache<T> {
  private cache: Map<string, { value: T; expiresAt: number }> = new Map();
  private defaultTTL: number;

  constructor(defaultTTLSeconds: number = 300) {
    this.defaultTTL = defaultTTLSeconds * 1000; // Convert to milliseconds
    // Clean up expired entries every minute
    setInterval(() => this.cleanup(), 60000);
  }

  /**
   * Get value from cache
   */
  get(key: string): T | null {
    const entry = this.cache.get(key);
    
    if (!entry) {
      return null;
    }
    
    // Check if expired
    if (Date.now() > entry.expiresAt) {
      this.cache.delete(key);
      return null;
    }
    
    return entry.value;
  }

  /**
   * Set value in cache with optional TTL override
   */
  set(key: string, value: T, ttlSeconds?: number): void {
    const ttl = (ttlSeconds || this.defaultTTL / 1000) * 1000;
    const expiresAt = Date.now() + ttl;
    
    this.cache.set(key, { value, expiresAt });
  }

  /**
   * Delete value from cache
   */
  delete(key: string): void {
    this.cache.delete(key);
  }

  /**
   * Clear all cache entries
   */
  clear(): void {
    this.cache.clear();
  }

  /**
   * Get cache statistics
   */
  getStats(): { size: number; keys: string[] } {
    return {
      size: this.cache.size,
      keys: Array.from(this.cache.keys())
    };
  }

  /**
   * Remove expired entries
   */
  private cleanup(): void {
    const now = Date.now();
    let cleaned = 0;
    
    for (const [key, entry] of this.cache.entries()) {
      if (now > entry.expiresAt) {
        this.cache.delete(key);
        cleaned++;
      }
    }
    
    if (cleaned > 0) {
      logger.debug(`Cleaned up ${cleaned} expired cache entries`);
    }
  }
}

/**
 * Global cache instances for different use cases
 */
export const statusCache = new InMemoryCache<any>(300); // 5 minutes for status checks
export const responseCache = new InMemoryCache<any>(600); // 10 minutes for API responses
