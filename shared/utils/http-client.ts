import axios, { AxiosInstance, AxiosRequestConfig } from 'axios';
import { createLogger } from './logger';
import https from 'https';

const logger = createLogger('http-client');

/**
 * Create an HTTP client with connection pooling and optimized settings
 */
export function createHttpClient(baseURL?: string, options?: {
  timeout?: number;
  maxConnections?: number;
  keepAlive?: boolean;
}): AxiosInstance {
  const {
    timeout = 30000,
    maxConnections = 50,
    keepAlive = true
  } = options || {};

  // Create HTTP agent with connection pooling
  const httpsAgent = new https.Agent({
    keepAlive: keepAlive,
    maxSockets: maxConnections,
    maxFreeSockets: 10,
    timeout: timeout,
    // Reuse connections
    scheduling: 'fifo'
  });

  const client = axios.create({
    baseURL,
    timeout,
    httpsAgent,
    // Optimize for performance
    maxRedirects: 5,
    validateStatus: (status) => status < 500, // Don't throw on 4xx
    // Headers
    headers: {
      'Connection': 'keep-alive',
      'Accept': 'application/json',
      'Accept-Encoding': 'gzip, deflate'
    }
  });

  // Request interceptor for logging
  client.interceptors.request.use(
    (config) => {
      logger.debug('HTTP request', {
        method: config.method,
        url: config.url,
        baseURL: config.baseURL
      });
      return config;
    },
    (error) => {
      logger.error('HTTP request error', error);
      return Promise.reject(error);
    }
  );

  // Response interceptor for error handling
  client.interceptors.response.use(
    (response) => {
      return response;
    },
    (error) => {
      if (error.response) {
        logger.warn('HTTP response error', {
          status: error.response.status,
          url: error.config?.url,
          message: error.message
        });
      } else if (error.request) {
        logger.error('HTTP request failed (no response)', {
          url: error.config?.url,
          message: error.message
        });
      } else {
        logger.error('HTTP error', error);
      }
      return Promise.reject(error);
    }
  );

  return client;
}

/**
 * Global HTTP client instances with connection pooling
 */
export const defaultHttpClient = createHttpClient();
export const connectorHttpClient = createHttpClient(undefined, {
  timeout: 30000,
  maxConnections: 20,
  keepAlive: true
});
