import express from 'express';
import { validateServiceJwt, configureCors } from '@credovo/shared-auth';
import { createLogger } from '@credovo/shared-utils/logger';
import { CompanySearchRouter } from './routes/company-search';

// Initialize logger with fallback
let logger: any;
try {
  logger = createLogger('company-search-service');
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
  logger.request(req, res, { service: 'company-search-service' });
  next();
});

// Custom middleware to handle dual authentication
const validateServiceAuth = (req: express.Request, res: express.Response, next: express.NextFunction) => {
  if (req.headers['x-service-token']) {
    return validateServiceJwt(req, res, next);
  } else {
    next();
  }
};

// Routes
app.use('/api/v1/companies', validateServiceAuth, CompanySearchRouter);

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'company-search-service' });
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
    const message = `Company Search service started successfully on port ${PORT}`;
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
  const errorMsg = `Failed to start company search service: ${error.message || error}`;
  logger.error(errorMsg, error);
  console.error(errorMsg, error);
  process.exit(1);
}

export default app;
