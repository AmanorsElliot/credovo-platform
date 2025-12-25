import { Request, Response } from 'express';

export enum LogLevel {
  DEBUG = 'debug',
  INFO = 'info',
  WARN = 'warn',
  ERROR = 'error'
}

export interface LogContext {
  requestId?: string;
  userId?: string;
  applicationId?: string;
  service?: string;
  [key: string]: any;
}

class Logger {
  private serviceName: string;

  constructor(serviceName: string) {
    this.serviceName = serviceName;
  }

  private log(level: LogLevel, message: string, context?: LogContext) {
    const logEntry = {
      timestamp: new Date().toISOString(),
      level,
      service: this.serviceName,
      message,
      ...context
    };

    // In production, this will be picked up by Cloud Logging
    if (process.env.NODE_ENV === 'production') {
      console.log(JSON.stringify(logEntry));
    } else {
      console.log(`[${level.toUpperCase()}] ${message}`, context || '');
    }
  }

  debug(message: string, context?: LogContext) {
    this.log(LogLevel.DEBUG, message, context);
  }

  info(message: string, context?: LogContext) {
    this.log(LogLevel.INFO, message, context);
  }

  warn(message: string, context?: LogContext) {
    this.log(LogLevel.WARN, message, context);
  }

  error(message: string, error?: Error | any, context?: LogContext) {
    const errorContext = {
      ...context,
      error: {
        message: error?.message || error,
        stack: error?.stack,
        ...(error?.code && { code: error.code })
      }
    };
    this.log(LogLevel.ERROR, error?.message || 'Unknown error', errorContext);
  }

  request(req: Request, res: Response, context?: LogContext) {
    const requestId = req.headers['x-request-id'] as string || 
                     req.headers['x-correlation-id'] as string ||
                     `req-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    
    const startTime = Date.now();
    
    res.on('finish', () => {
      const duration = Date.now() - startTime;
      this.info('HTTP Request', {
        ...context,
        requestId,
        method: req.method,
        path: req.path,
        statusCode: res.statusCode,
        duration,
        userAgent: req.get('user-agent'),
        ip: req.ip
      });
    });
  }
}

export function createLogger(serviceName: string): Logger {
  return new Logger(serviceName);
}

