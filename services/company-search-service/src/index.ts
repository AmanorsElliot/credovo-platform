import express from 'express';
import { validateServiceJwt, configureCors } from '@credovo/shared-auth';
import { createLogger } from '@credovo/shared-utils/logger';
import { CompanySearchRouter } from './routes/company-search';

const logger = createLogger('company-search-service');
const app = express();
const PORT = process.env.PORT || 8080;

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

app.listen(PORT, () => {
  logger.info(`Company Search service started on port ${PORT}`);
});

export default app;
