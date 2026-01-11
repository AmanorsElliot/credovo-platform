import { Router, Request, Response } from 'express';
import { KYCRequest, KYCResponse } from '@credovo/shared-types';
import { createLogger } from '@credovo/shared-utils/logger';
import { KYCService } from '../services/kyc-service';
import { validateBody, validateParams } from '@credovo/shared-types/validation-middleware';
import { KYCRequestSchema, ApplicationIdParamSchema } from '@credovo/shared-types/validation';

const logger = createLogger('kyc-service');
export const KYCRouter = Router();
const kycService = new KYCService();

KYCRouter.post('/initiate',
  validateBody(KYCRequestSchema),
  async (req: Request, res: Response) => {
    try {
      const request: KYCRequest = {
        ...req.body,
        userId: req.userId || req.body.userId
      };

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

KYCRouter.get('/status/:applicationId',
  validateParams(ApplicationIdParamSchema),
  async (req: Request, res: Response) => {
    try {
      const { applicationId } = req.params;
    // For service-to-service calls, userId might not be present (req.service is set instead)
    // Use userId if available, otherwise use service identifier or applicationId as fallback
    const userId = req.userId || req.service || `service-${applicationId}`;

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

