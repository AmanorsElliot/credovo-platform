import express from 'express';
import { validateServiceJwt, configureCors } from '@credovo/shared-auth';
import { createLogger } from '@credovo/shared-utils/logger';
import { ConnectorRouter } from './routes/connector';
import { HealthRouter } from './routes/health';

// Initialize logger with fallback
let logger: any;
try {
  logger = createLogger('connector-service');
} catch (error) {
  logger = {
    info: (...args: any[]) => console.log('[INFO]', ...args),
    error: (...args: any[]) => console.error('[ERROR]', ...args),
    warn: (...args: any[]) => console.warn('[WARN]', ...args),
    debug: (...args: any[]) => console.log('[DEBUG]', ...args),
    request: () => {},
  };
  console.error('Failed to initialize logger, using console fallback', error);
}

const app = express();
const PORT = parseInt(process.env.PORT || '8080', 10);

// Middleware
app.use(express.json());
app.use(configureCors());

// Request logging
app.use((req, res, next) => {
  logger.request(req, res, { service: 'connector-service' });
  next();
});

// Custom middleware to handle dual authentication:
// 1. Cloud Run IAM token in Authorization header (handled by Cloud Run)
// 2. Application-level service token in X-Service-Token header
const validateServiceAuth = (req: express.Request, res: express.Response, next: express.NextFunction) => {
  // Check for application-level service token in X-Service-Token header
  // (Cloud Run IAM is already validated by Cloud Run itself)
  if (req.headers['x-service-token']) {
    // Use the service token validator for application-level auth
    return validateServiceJwt(req, res, next);
  } else {
    // If no X-Service-Token, just proceed (Cloud Run IAM is sufficient)
    // This allows flexibility for different callers
    next();
  }
};

// Routes
app.use('/health', HealthRouter);
// Use dual authentication: Cloud Run IAM + application service token
app.use('/api/v1/connector', validateServiceAuth, ConnectorRouter);

// Error handling
app.use((err: any, req: express.Request, res: express.Response, next: express.NextFunction) => {
  logger.error('Unhandled error', err, {
    path: req.path,
    method: req.method
  });
  
  res.status(err.statusCode || 500).json({
    error: 'Internal Server Error',
    message: process.env.NODE_ENV === 'production' ? 'An error occurred' : err.message
  });
});

// Start server with error handling
try {
  const server = app.listen(PORT, '0.0.0.0', () => {
    const message = `Connector service started successfully on port ${PORT}`;
    logger.info(message);
    console.log(message);
  });

  server.on('error', (error: any) => {
    const errorMsg = `Server error: ${error.message || error}`;
    logger.error(errorMsg, error);
    console.error(errorMsg, error);
    process.exit(1);
  });

  process.on('uncaughtException', (error: Error) => {
    logger.error('Uncaught exception', error);
    console.error('Uncaught exception', error);
    process.exit(1);
  });

  process.on('unhandledRejection', (reason: any) => {
    logger.error('Unhandled promise rejection', { reason });
    console.error('Unhandled promise rejection', { reason });
    process.exit(1);
  });
} catch (error: any) {
  const errorMsg = `Failed to start connector service: ${error.message || error}`;
  logger.error(errorMsg, error);
  console.error(errorMsg, error);
  process.exit(1);
}

export default app;

