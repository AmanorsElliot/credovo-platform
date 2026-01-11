import express from 'express';
import { validateServiceJwt, configureCors } from '@credovo/shared-auth';
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

app.listen(PORT, () => {
  logger.info(`Open Banking service started on port ${PORT}`);
});

export default app;
