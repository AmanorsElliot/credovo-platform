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

app.listen(PORT, () => {
  logger.info(`Orchestration service started on port ${PORT}`);
});

export default app;

