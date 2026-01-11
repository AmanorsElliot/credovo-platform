import express from 'express';
import { validateBackendJwt, validateSupabaseJwt, configureCors } from '@credovo/shared-auth';
import { createLogger } from '@credovo/shared-utils/logger';
import { ApplicationRouter } from './routes/application';
import { AuthRouter } from './routes/auth';
import { WebhookRouter } from './routes/webhooks';
import { BankingRouter } from './routes/banking';
import { CompanySearchRouter } from './routes/company-search';

const logger = createLogger('orchestration-service');
const app = express();
const PORT = process.env.PORT || 8080;

// Log startup information
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
  const server = app.listen(PORT, () => {
    logger.info(`Orchestration service started successfully on port ${PORT}`);
  });

  // Handle server errors
  server.on('error', (error: any) => {
    logger.error('Server error', error);
    if (error.code === 'EADDRINUSE') {
      logger.error(`Port ${PORT} is already in use`);
      process.exit(1);
    } else {
      logger.error('Unexpected server error', error);
      process.exit(1);
    }
  });

  // Handle uncaught exceptions
  process.on('uncaughtException', (error: Error) => {
    logger.error('Uncaught exception', error);
    process.exit(1);
  });

  // Handle unhandled promise rejections
  process.on('unhandledRejection', (reason: any, promise: Promise<any>) => {
    logger.error('Unhandled promise rejection', { reason, promise });
    process.exit(1);
  });
} catch (error: any) {
  logger.error('Failed to start orchestration service', error);
  process.exit(1);
}

export default app;

