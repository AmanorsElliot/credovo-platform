import express from 'express';
import { validateBackendJwt, validateSupabaseJwt, configureCors } from '@credovo/shared-auth';
import { createLogger } from '@credovo/shared-utils/logger';
import { ApplicationRouter } from './routes/application';
import { AuthRouter } from './routes/auth';
import { WebhookRouter } from './routes/webhooks';
import { BankingRouter } from './routes/banking';
import { CompanySearchRouter } from './routes/company-search';

// Initialize logger with fallback
let logger: any;
try {
  logger = createLogger('orchestration-service');
} catch (error) {
  // Fallback logger if shared-utils fails to load
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

// Log startup information
try {
  logger.info('Starting orchestration service', {
    port: PORT,
    environment: process.env.ENVIRONMENT,
    nodeEnv: process.env.NODE_ENV,
    hasKycServiceUrl: !!process.env.KYC_SERVICE_URL,
    hasConnectorServiceUrl: !!process.env.CONNECTOR_SERVICE_URL,
    hasServiceJwtSecret: !!process.env.SERVICE_JWT_SECRET,
    hasLovableJwksUri: !!process.env.LOVABLE_JWKS_URI,
    hasLovableAudience: !!process.env.LOVABLE_AUDIENCE,
  });
} catch (error) {
  console.error('Failed to log startup info', error);
}

// Middleware
// Configure JSON parser with verify to preserve raw body for webhook signature verification
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
  logger.request(req, res, { service: 'orchestration-service' });
  next();
});

// Auth routes (no auth required - this is where tokens are issued if using token exchange)
app.use('/api/v1/auth', AuthRouter);

// Webhook routes (no auth required - webhooks come from external services)
app.use('/api/v1/webhooks', WebhookRouter);

// Application routes (require authentication)
// Use Supabase JWT validation if SUPABASE_JWKS_URI or SUPABASE_URL is set, otherwise use backend JWT
const authMiddleware = (process.env.SUPABASE_JWKS_URI || process.env.SUPABASE_URL)
  ? validateSupabaseJwt 
  : validateBackendJwt;

app.use('/api/v1/applications', authMiddleware, ApplicationRouter);
app.use('/api/v1/applications', authMiddleware, BankingRouter);
app.use('/api/v1/companies', authMiddleware, CompanySearchRouter);

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'orchestration-service' });
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
    const message = `Orchestration service started successfully on port ${PORT}`;
    logger.info(message);
    console.log(message); // Also log to console for Cloud Run logs
  });

  // Handle server errors
  server.on('error', (error: any) => {
    const errorMsg = `Server error: ${error.message || error}`;
    logger.error(errorMsg, error);
    console.error(errorMsg, error);
    if (error.code === 'EADDRINUSE') {
      const portMsg = `Port ${PORT} is already in use`;
      logger.error(portMsg);
      console.error(portMsg);
      process.exit(1);
    } else {
      logger.error('Unexpected server error', error);
      console.error('Unexpected server error', error);
      process.exit(1);
    }
  });

  // Handle uncaught exceptions
  process.on('uncaughtException', (error: Error) => {
    const errorMsg = `Uncaught exception: ${error.message || error}`;
    logger.error(errorMsg, error);
    console.error(errorMsg, error);
    process.exit(1);
  });

  // Handle unhandled promise rejections
  process.on('unhandledRejection', (reason: any, promise: Promise<any>) => {
    const errorMsg = `Unhandled promise rejection: ${reason}`;
    logger.error(errorMsg, { reason, promise });
    console.error(errorMsg, { reason, promise });
    process.exit(1);
  });
} catch (error: any) {
  const errorMsg = `Failed to start orchestration service: ${error.message || error}`;
  logger.error(errorMsg, error);
  console.error(errorMsg, error);
  process.exit(1);
}

export default app;

