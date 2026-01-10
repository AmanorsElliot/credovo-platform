import { ConnectorRequest, ConnectorResponse } from '@credovo/shared-types';
import { createLogger } from '@credovo/shared-utils/logger';
import { BaseConnector } from '../adapters/base-connector';
import { SumSubConnector } from '../adapters/sumsub-connector';
import { CompaniesHouseConnector } from '../adapters/companies-house-connector';
import { ShuftiProConnector } from '../adapters/shufti-pro-connector';
import { CircuitBreaker } from '../utils/circuit-breaker';
import { RateLimiter } from '../utils/rate-limiter';

const logger = createLogger('connector-manager');

export class ConnectorManager {
  private connectors: Map<string, BaseConnector>;
  private circuitBreakers: Map<string, CircuitBreaker>;
  private rateLimiters: Map<string, RateLimiter>;

  constructor() {
    this.connectors = new Map();
    this.circuitBreakers = new Map();
    this.rateLimiters = new Map();

    // Initialize connectors
    // Shufti Pro is the primary provider (240+ countries, 150+ languages)
    this.registerConnector('shufti-pro', new ShuftiProConnector());
    // SumSub kept as fallback/secondary provider
    this.registerConnector('sumsub', new SumSubConnector());
    this.registerConnector('companies-house', new CompaniesHouseConnector());
  }

  private registerConnector(name: string, connector: BaseConnector) {
    this.connectors.set(name, connector);
    this.circuitBreakers.set(name, new CircuitBreaker({
      failureThreshold: 5,
      resetTimeout: 60000, // 1 minute
      monitoringPeriod: 300000 // 5 minutes
    }));
    this.rateLimiters.set(name, new RateLimiter({
      maxRequests: 100,
      windowMs: 60000 // 1 minute
    }));
  }

  async call(request: ConnectorRequest): Promise<ConnectorResponse> {
    const startTime = Date.now();
    const connector = this.connectors.get(request.provider);

    if (!connector) {
      return {
        success: false,
        error: {
          code: 'PROVIDER_NOT_FOUND',
          message: `Provider ${request.provider} is not available`
        }
      };
    }

    // Check rate limit
    const rateLimiter = this.rateLimiters.get(request.provider)!;
    if (!rateLimiter.allow()) {
      return {
        success: false,
        error: {
          code: 'RATE_LIMIT_EXCEEDED',
          message: `Rate limit exceeded for provider ${request.provider}`
        }
      };
    }

    // Check circuit breaker
    const circuitBreaker = this.circuitBreakers.get(request.provider)!;
    if (!circuitBreaker.allow()) {
      return {
        success: false,
        error: {
          code: 'CIRCUIT_BREAKER_OPEN',
          message: `Circuit breaker is open for provider ${request.provider}`
        }
      };
    }

    try {
      const result = await connector.call(request);
      const latency = Date.now() - startTime;

      circuitBreaker.recordSuccess();

      return {
        success: true,
        data: result,
        metadata: {
          provider: request.provider,
          latency,
          retries: 0
        }
      };
    } catch (error: any) {
      const latency = Date.now() - startTime;
      circuitBreaker.recordFailure();

      logger.error(`Connector call failed for ${request.provider}`, error);

      // Retry logic if requested
      if (request.retry && error.retryable) {
        return this.retryCall(request, 1);
      }

      return {
        success: false,
        error: {
          code: error.code || 'CONNECTOR_ERROR',
          message: error.message || 'Unknown error',
          details: error.details
        },
        metadata: {
          provider: request.provider,
          latency,
          retries: 0
        }
      };
    }
  }

  private async retryCall(request: ConnectorRequest, attempt: number): Promise<ConnectorResponse> {
    const maxRetries = 3;
    if (attempt >= maxRetries) {
      return {
        success: false,
        error: {
          code: 'MAX_RETRIES_EXCEEDED',
          message: `Failed after ${maxRetries} retry attempts`
        }
      };
    }

    // Exponential backoff
    const delay = Math.min(1000 * Math.pow(2, attempt), 10000);
    await new Promise(resolve => setTimeout(resolve, delay));

    return this.call({ ...request, retry: attempt < maxRetries - 1 });
  }

  getAvailableProviders() {
    return Array.from(this.connectors.entries()).map(([name, connector]) => ({
      name,
      status: 'available',
      features: connector.getFeatures()
    }));
  }
}

