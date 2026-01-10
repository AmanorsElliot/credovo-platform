import express from 'express';
import { validateJwt, configureCors } from '@credovo/shared-auth';
import { createLogger } from '@credovo/shared-utils/logger';
import { KYCRouter } from './routes/kyc';
import { KYBRouter } from './routes/kyb';
import { HealthRouter } from './routes/health';
import { WebhookRouter } from './routes/webhooks';

const logger = createLogger('kyc-kyb-service');
const app = express();
const PORT = process.env.PORT || 8080;

// Middleware
app.use(express.json());
app.use(configureCors());

// Request logging
app.use((req, res, next) => {
  logger.request(req, res, { service: 'kyc-kyb-service' });
  next();
});

// Routes
app.use('/health', HealthRouter);
app.use('/api/v1/kyc', validateJwt, KYCRouter);
app.use('/api/v1/kyb', validateJwt, KYBRouter);
// Webhook routes (no auth required - webhooks come from orchestration service)
app.use('/api/v1/webhooks', WebhookRouter);

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

// Start server
app.listen(PORT, () => {
  logger.info(`KYC/KYB service started on port ${PORT}`);
});

export default app;

