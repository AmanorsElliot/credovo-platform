import { Router, Request, Response } from 'express';
import { KYBRequest, KYBResponse } from '@credovo/shared-types';
import { createLogger } from '@credovo/shared-utils/logger';
import { KYBService } from '../services/kyb-service';

const logger = createLogger('kyb-service');
export const KYBRouter = Router();
const kybService = new KYBService();

KYBRouter.post('/verify', async (req: Request, res: Response) => {
  try {
    const request: KYBRequest = {
      ...req.body,
      applicationId: req.body.applicationId || `kyb-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`
    };

    if (!request.companyNumber) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Missing required field: companyNumber'
      });
    }

    logger.info('KYB verification requested', {
      applicationId: request.applicationId,
      companyNumber: request.companyNumber
    });

    const response = await kybService.verifyCompany(request);

    res.json(response);
  } catch (error: any) {
    logger.error('KYB verification failed', error, {
      body: req.body
    });
    
    res.status(500).json({
      error: 'Internal Server Error',
      message: error.message || 'Failed to verify company'
    });
  }
});

KYBRouter.get('/status/:applicationId', async (req: Request, res: Response) => {
  try {
    const { applicationId } = req.params;
    const userId = req.userId;

    if (!userId) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'User ID required'
      });
    }

    const status = await kybService.getKYBStatus(applicationId, userId);

    if (!status) {
      return res.status(404).json({
        error: 'Not Found',
        message: 'KYB application not found'
      });
    }

    res.json(status);
  } catch (error: any) {
    logger.error('KYB status check failed', error, {
      applicationId: req.params.applicationId
    });
    
    res.status(500).json({
      error: 'Internal Server Error',
      message: error.message || 'Failed to get KYB status'
    });
  }
});

