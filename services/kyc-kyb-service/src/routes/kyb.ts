import { Router, Request, Response } from 'express';
import { KYBRequest, KYBResponse } from '@credovo/shared-types';
import { createLogger } from '@credovo/shared-utils/logger';
import { KYBService } from '../services/kyb-service';
import { validateBody, validateParams } from '@credovo/shared-types/validation-middleware';
import { KYBRequestSchema, ApplicationIdParamSchema } from '@credovo/shared-types/validation';

const logger = createLogger('kyb-service');
export const KYBRouter = Router();
const kybService = new KYBService();

KYBRouter.post('/verify',
  validateBody(KYBRequestSchema.partial({ applicationId: true })),
  async (req: Request, res: Response) => {
    try {
      const request: KYBRequest = {
        ...req.body,
        applicationId: req.body.applicationId || `kyb-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`
      };

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

KYBRouter.get('/status/:applicationId',
  validateParams(ApplicationIdParamSchema),
  async (req: Request, res: Response) => {
    try {
      const { applicationId } = req.params;
    // For service-to-service calls, userId might not be present (req.service is set instead)
    // Use userId if available, otherwise use service identifier or applicationId as fallback
    const userId = req.userId || req.service || `service-${applicationId}`;

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

