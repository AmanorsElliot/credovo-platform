import { Router, Request, Response } from 'express';
import { KYCRequest, KYCResponse } from '@credovo/shared-types';
import { createLogger } from '@credovo/shared-utils/logger';
import { KYCService } from '../services/kyc-service';

const logger = createLogger('kyc-service');
export const KYCRouter = Router();
const kycService = new KYCService();

KYCRouter.post('/initiate', async (req: Request, res: Response) => {
  try {
    const request: KYCRequest = {
      ...req.body,
      userId: req.userId || req.body.userId
    };

    if (!request.applicationId || !request.userId) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Missing required fields: applicationId, userId'
      });
    }

    logger.info('KYC initiation requested', {
      applicationId: request.applicationId,
      userId: request.userId,
      type: request.type
    });

    const response = await kycService.initiateKYC(request);

    res.status(202).json(response);
  } catch (error: any) {
    logger.error('KYC initiation failed', error, {
      body: req.body
    });
    
    res.status(500).json({
      error: 'Internal Server Error',
      message: error.message || 'Failed to initiate KYC process'
    });
  }
});

KYCRouter.get('/status/:applicationId', async (req: Request, res: Response) => {
  try {
    const { applicationId } = req.params;
    const userId = req.userId;

    if (!userId) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'User ID required'
      });
    }

    const status = await kycService.getKYCStatus(applicationId, userId);

    if (!status) {
      return res.status(404).json({
        error: 'Not Found',
        message: 'KYC application not found'
      });
    }

    res.json(status);
  } catch (error: any) {
    logger.error('KYC status check failed', error, {
      applicationId: req.params.applicationId
    });
    
    res.status(500).json({
      error: 'Internal Server Error',
      message: error.message || 'Failed to get KYC status'
    });
  }
});

