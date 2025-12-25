export interface RateLimiterOptions {
  maxRequests: number;
  windowMs: number;
}

export class RateLimiter {
  private requests: number[] = [];
  private options: RateLimiterOptions;

  constructor(options: RateLimiterOptions) {
    this.options = options;
  }

  allow(): boolean {
    const now = Date.now();
    
    // Remove requests outside the time window
    this.requests = this.requests.filter(
      timestamp => now - timestamp < this.options.windowMs
    );

    // Check if we're under the limit
    if (this.requests.length >= this.options.maxRequests) {
      return false;
    }

    // Record this request
    this.requests.push(now);
    return true;
  }

  getRemainingRequests(): number {
    const now = Date.now();
    this.requests = this.requests.filter(
      timestamp => now - timestamp < this.options.windowMs
    );
    return Math.max(0, this.options.maxRequests - this.requests.length);
  }
}

