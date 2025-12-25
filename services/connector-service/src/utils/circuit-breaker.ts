export interface CircuitBreakerOptions {
  failureThreshold: number;
  resetTimeout: number;
  monitoringPeriod: number;
}

export class CircuitBreaker {
  private state: 'closed' | 'open' | 'half-open' = 'closed';
  private failureCount = 0;
  private lastFailureTime = 0;
  private successCount = 0;
  private options: CircuitBreakerOptions;

  constructor(options: CircuitBreakerOptions) {
    this.options = options;
  }

  allow(): boolean {
    const now = Date.now();

    if (this.state === 'open') {
      // Check if we should transition to half-open
      if (now - this.lastFailureTime >= this.options.resetTimeout) {
        this.state = 'half-open';
        this.successCount = 0;
        return true;
      }
      return false;
    }

    return true;
  }

  recordSuccess() {
    if (this.state === 'half-open') {
      this.successCount++;
      // If we have enough successes, close the circuit
      if (this.successCount >= 3) {
        this.state = 'closed';
        this.failureCount = 0;
        this.successCount = 0;
      }
    } else if (this.state === 'closed') {
      // Reset failure count on success
      this.failureCount = 0;
    }
  }

  recordFailure() {
    this.failureCount++;
    this.lastFailureTime = Date.now();

    if (this.state === 'half-open') {
      // If we fail in half-open, go back to open
      this.state = 'open';
      this.failureCount = 0;
      this.successCount = 0;
    } else if (this.state === 'closed' && this.failureCount >= this.options.failureThreshold) {
      // Open the circuit
      this.state = 'open';
    }
  }

  getState(): string {
    return this.state;
  }
}

