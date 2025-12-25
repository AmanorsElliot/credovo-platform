import { Router, Request, Response } from 'express';

export const HealthRouter = Router();

HealthRouter.get('/', (req: Request, res: Response) => {
  res.json({
    status: 'healthy',
    service: 'kyc-kyb-service',
    timestamp: new Date().toISOString()
  });
});

HealthRouter.get('/ready', (req: Request, res: Response) => {
  // Add readiness checks here (e.g., GCS, BigQuery connectivity)
  res.json({
    status: 'ready',
    service: 'kyc-kyb-service',
    timestamp: new Date().toISOString()
  });
});

HealthRouter.get('/live', (req: Request, res: Response) => {
  res.json({
    status: 'alive',
    service: 'kyc-kyb-service',
    timestamp: new Date().toISOString()
  });
});

