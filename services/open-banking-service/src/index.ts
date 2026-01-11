import express from 'express';
import { validateServiceJwt, configureCors } from '@credovo/shared-auth';
import { createLogger } from '@credovo/shared-utils/logger';
import { BankingRouter } from './routes/banking';

// Initialize logger with fallback
let logger: any;
try {
  logger = createLogger('open-banking-service');
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
app.use(express.json({
  verify: (req: any, res, buf) => {
    // Preserve raw body for webhook signature verification
    if (req.path?.startsWith('/api/v1/webhooks')) {
      req.rawBody = buf.toString('utf8');
    }
  }
}));
app.use(configureCors());

// Request logging
app.use((req, res, next) => {
  logger.request(req, res, { service: 'open-banking-service' });
  next();
});

// Custom middleware to handle dual authentication (like KYC-KYB service):
// 1. Cloud Run IAM token in Authorization header (handled by Cloud Run)
// 2. Application-level service token in X-Service-Token header
const validateServiceAuth = (req: express.Request, res: express.Response, next: express.NextFunction) => {
  // Check for application-level service token in X-Service-Token header
  if (req.headers['x-service-token']) {
    return validateServiceJwt(req, res, next);
  } else {
    // If no X-Service-Token, just proceed (Cloud Run IAM is sufficient)
    next();
  }
};

// Routes
app.use('/api/v1/banking', validateServiceAuth, BankingRouter);

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'open-banking-service' });
});

// Error handling
app.use((err: any, req: express.Request, res: express.Response, next: express.NextFunction) => {
  logger.error('Unhandled error', err);
  res.status(err.statusCode || 500).json({
    error: 'Internal Server Error',
    message: process.env.NODE_ENV === 'production' ? 'An error occurred' : err.message
  });
});

// Start server with error handling
try {
  const server = app.listen(PORT, '0.0.0.0', () => {
    const message = `Open Banking service started successfully on port ${PORT}`;
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
  const errorMsg = `Failed to start open banking service: ${error.message || error}`;
  logger.error(errorMsg, error);
  console.error(errorMsg, error);
  process.exit(1);
}

export default app;
