import express from 'express';
import { validateBackendJwt, configureCors } from '@credovo/shared-auth';
import { createLogger } from '@credovo/shared-utils/logger';
import { BankingRouter } from './routes/banking';

const logger = createLogger('open-banking-service');
const app = express();
const PORT = process.env.PORT || 8080;

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

// Routes
// Use Supabase JWT validation if SUPABASE_JWKS_URI or SUPABASE_URL is set, otherwise use backend JWT
const authMiddleware = (process.env.SUPABASE_JWKS_URI || process.env.SUPABASE_URL)
  ? require('@credovo/shared-auth').validateSupabaseJwt 
  : validateBackendJwt;

app.use('/api/v1/banking', authMiddleware, BankingRouter);

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

app.listen(PORT, () => {
  logger.info(`Open Banking service started on port ${PORT}`);
});

export default app;
