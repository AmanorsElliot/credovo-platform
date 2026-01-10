import { Router, Request, Response } from 'express';
import axios from 'axios';
import jwt from 'jsonwebtoken';
import { createLogger } from '@credovo/shared-utils/logger';

const logger = createLogger('orchestration-service');
export const ApplicationRouter = Router();

const KYC_SERVICE_URL = process.env.KYC_SERVICE_URL || 'http://kyc-kyb-service:8080';

// Helper function to create a service-to-service JWT token
function createServiceToken(): string {
  const serviceSecret = process.env.SERVICE_JWT_SECRET;
  if (!serviceSecret) {
    throw new Error('SERVICE_JWT_SECRET not configured');
  }
  
  return jwt.sign(
    {
      service: 'orchestration-service',
      iat: Math.floor(Date.now() / 1000),
      exp: Math.floor(Date.now() / 1000) + 300 // 5 minutes
    },
    serviceSecret,
    { algorithm: 'HS256' }
  );
}

ApplicationRouter.post('/:applicationId/kyc/initiate', async (req: Request, res: Response) => {
  try {
    const { applicationId } = req.params;
    
    const serviceToken = createServiceToken();
    
    const response = await axios.post(
      `${KYC_SERVICE_URL}/api/v1/kyc/initiate`,
      {
        ...req.body,
        applicationId,
        userId: req.userId
      },
      {
        headers: {
          'Authorization': `Bearer ${serviceToken}`
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
    
    const serviceToken = createServiceToken();
    
    const response = await axios.get(
      `${KYC_SERVICE_URL}/api/v1/kyc/status/${applicationId}`,
      {
        headers: {
          'Authorization': `Bearer ${serviceToken}`
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

