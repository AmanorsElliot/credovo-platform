import { Router, Request, Response } from 'express';
import axios from 'axios';
import { createLogger } from '@credovo/shared-utils/logger';

const logger = createLogger('orchestration-service');
export const ApplicationRouter = Router();

const KYC_SERVICE_URL = process.env.KYC_SERVICE_URL || 'http://kyc-kyb-service:8080';

ApplicationRouter.post('/:applicationId/kyc/initiate', async (req: Request, res: Response) => {
  try {
    const { applicationId } = req.params;
    
    const response = await axios.post(
      `${KYC_SERVICE_URL}/api/v1/kyc/initiate`,
      {
        ...req.body,
        applicationId,
        userId: req.userId
      },
      {
        headers: {
          'Authorization': `Bearer ${process.env.SERVICE_JWT_SECRET}`
        }
      }
    );

    res.json(response.data);
  } catch (error: any) {
    logger.error('Failed to initiate KYC', error);
    res.status(error.response?.status || 500).json({
      error: 'Failed to initiate KYC',
      message: error.message
    });
  }
});

ApplicationRouter.get('/:applicationId/kyc/status', async (req: Request, res: Response) => {
  try {
    const { applicationId } = req.params;
    
    const response = await axios.get(
      `${KYC_SERVICE_URL}/api/v1/kyc/status/${applicationId}`,
      {
        headers: {
          'Authorization': `Bearer ${process.env.SERVICE_JWT_SECRET}`
        }
      }
    );

    res.json(response.data);
  } catch (error: any) {
    logger.error('Failed to get KYC status', error);
    res.status(error.response?.status || 500).json({
      error: 'Failed to get KYC status',
      message: error.message
    });
  }
});

