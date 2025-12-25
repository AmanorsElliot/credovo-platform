import { Router, Request, Response } from 'express';
import { ConnectorRequest, ConnectorResponse } from '@credovo/shared-types';
import { createLogger } from '@credovo/shared-utils/logger';
import { ConnectorManager } from '../services/connector-manager';

const logger = createLogger('connector-service');
export const ConnectorRouter = Router();
const connectorManager = new ConnectorManager();

ConnectorRouter.post('/call', async (req: Request, res: Response) => {
  try {
    const request: ConnectorRequest = req.body;
    
    if (!request.provider || !request.endpoint || !request.method) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Missing required fields: provider, endpoint, method'
      });
    }

    logger.info('Connector request received', {
      provider: request.provider,
      endpoint: request.endpoint,
      method: request.method,
      service: req.service
    });

    const response = await connectorManager.call(request);

    res.json(response);
  } catch (error: any) {
    logger.error('Connector request failed', error, {
      body: req.body
    });
    
    res.status(500).json({
      success: false,
      error: {
        code: 'CONNECTOR_ERROR',
        message: error.message || 'Failed to process connector request'
      }
    });
  }
});

ConnectorRouter.get('/providers', (req: Request, res: Response) => {
  const providers = connectorManager.getAvailableProviders();
  res.json({
    providers: providers.map(p => ({
      name: p.name,
      status: p.status,
      features: p.features
    }))
  });
});

