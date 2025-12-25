import express from 'express';
import { validateJwt, configureCors } from '@credovo/shared-auth';
import { createLogger } from '@credovo/shared-utils/logger';
import { ApplicationRouter } from './routes/application';

const logger = createLogger('orchestration-service');
const app = express();
const PORT = process.env.PORT || 8080;

// Middleware
app.use(express.json());
app.use(configureCors());

// Request logging
app.use((req, res, next) => {
  logger.request(req, res, { service: 'orchestration-service' });
  next();
});

// Routes
app.use('/api/v1/applications', validateJwt, ApplicationRouter);

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

