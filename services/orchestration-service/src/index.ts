console.log('[STARTUP] Starting orchestration service initialization...');

// Import modules with error handling
let express: any;
let validateBackendJwt: any;
let validateSupabaseJwt: any;
let configureCors: any;
let createLogger: any;
let ApplicationRouter: any;
let AuthRouter: any;
let WebhookRouter: any;
let BankingRouter: any;
let CompanySearchRouter: any;

try {
  console.log('[STARTUP] Importing express...');
  express = require('express');
  console.log('[STARTUP] Express imported successfully');
  
  console.log('[STARTUP] Importing shared-auth...');
  const sharedAuth = require('@credovo/shared-auth');
  validateBackendJwt = sharedAuth.validateBackendJwt;
  validateSupabaseJwt = sharedAuth.validateSupabaseJwt;
  configureCors = sharedAuth.configureCors;
  console.log('[STARTUP] shared-auth imported successfully');
  
  console.log('[STARTUP] Importing shared-utils/logger...');
  const sharedUtils = require('@credovo/shared-utils/logger');
  createLogger = sharedUtils.createLogger;
  console.log('[STARTUP] shared-utils/logger imported successfully');
  
  console.log('[STARTUP] Importing routes...');
  ApplicationRouter = require('./routes/application').ApplicationRouter;
  AuthRouter = require('./routes/auth').AuthRouter;
  WebhookRouter = require('./routes/webhooks').WebhookRouter;
  BankingRouter = require('./routes/banking').BankingRouter;
  CompanySearchRouter = require('./routes/company-search').CompanySearchRouter;
  console.log('[STARTUP] All routes imported successfully');
} catch (error: any) {
  console.error('[STARTUP] CRITICAL: Failed to import modules:', error);
  console.error('[STARTUP] Error message:', error.message);
  console.error('[STARTUP] Error stack:', error.stack);
  // Exit with error code so Cloud Run knows the container failed
  process.exit(1);
}

console.log('[STARTUP] Initializing logger...');
// Initialize logger with fallback
let logger: any;
try {
  logger = createLogger('orchestration-service');
  console.log('[STARTUP] Logger initialized successfully');
} catch (error) {
  // Fallback logger if shared-utils fails to load
  logger = {
    info: (...args: any[]) => console.log('[INFO]', ...args),
    error: (...args: any[]) => console.error('[ERROR]', ...args),
    warn: (...args: any[]) => console.warn('[WARN]', ...args),
    debug: (...args: any[]) => console.log('[DEBUG]', ...args),
    request: () => {},
  };
  console.error('[STARTUP] Failed to initialize logger, using console fallback', error);
}

console.log('[STARTUP] Creating Express app...');
const app = express();
const PORT = parseInt(process.env.PORT || '8080', 10);
console.log(`[STARTUP] PORT set to ${PORT}`);

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

console.log('[STARTUP] Setting up middleware...');
// Middleware
// Configure JSON parser with verify to preserve raw body for webhook signature verification
try {
  app.use(express.json({
    verify: (req: any, res, buf) => {
      // Preserve raw body for webhook signature verification
      if (req.path?.startsWith('/api/v1/webhooks')) {
        req.rawBody = buf.toString('utf8');
      }
    }
  }));
  console.log('[STARTUP] JSON middleware configured');
  
  app.use(configureCors());
  console.log('[STARTUP] CORS middleware configured');
} catch (error) {
  console.error('[STARTUP] Failed to configure middleware', error);
  throw error;
}

// Request logging
app.use((req, res, next) => {
  logger.request(req, res, { service: 'orchestration-service' });
  next();
});

console.log('[STARTUP] Setting up routes...');
try {
  // Auth routes (no auth required - this is where tokens are issued if using token exchange)
  app.use('/api/v1/auth', AuthRouter);
  console.log('[STARTUP] Auth routes configured');

  // Webhook routes (no auth required - webhooks come from external services)
  app.use('/api/v1/webhooks', WebhookRouter);
  console.log('[STARTUP] Webhook routes configured');

  // Application routes (require authentication)
  // Use Supabase JWT validation if SUPABASE_JWKS_URI or SUPABASE_URL is set, otherwise use backend JWT
  const authMiddleware = (process.env.SUPABASE_JWKS_URI || process.env.SUPABASE_URL)
    ? validateSupabaseJwt 
    : validateBackendJwt;
  console.log('[STARTUP] Auth middleware selected:', process.env.SUPABASE_JWKS_URI || process.env.SUPABASE_URL ? 'Supabase' : 'Backend');

  app.use('/api/v1/applications', authMiddleware, ApplicationRouter);
  app.use('/api/v1/applications', authMiddleware, BankingRouter);
  app.use('/api/v1/companies', authMiddleware, CompanySearchRouter);
  console.log('[STARTUP] Application routes configured');
} catch (error) {
  console.error('[STARTUP] Failed to configure routes', error);
  throw error;
}

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

