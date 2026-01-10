import { Router, Request, Response } from 'express';
import axios from 'axios';
import jwt from 'jsonwebtoken';
import { createLogger } from '@credovo/shared-utils/logger';

const logger = createLogger('orchestration-service');
export const ApplicationRouter = Router();

const KYC_SERVICE_URL = process.env.KYC_SERVICE_URL || 'http://kyc-kyb-service:8080';

// Helper function to get Cloud Run identity token for service-to-service calls
// Uses the Metadata Server available in Cloud Run
async function getIdentityToken(audience: string): Promise<string> {
  try {
    const metadataServerTokenUrl = 'http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/identity';
    const response = await axios.get(metadataServerTokenUrl, {
      params: {
        audience: audience,
        format: 'full'
      },
      headers: {
        'Metadata-Flavor': 'Google'
      },
      timeout: 5000
    });
    return response.data;
  } catch (error: any) {
    logger.warn('Failed to get identity token from Metadata Server, falling back to service token', {
      error: error.message
    });
    // Fallback to service JWT token if Metadata Server is not available (e.g., local development)
    return createServiceToken();
  }
}

// Helper function to create a service-to-service JWT token (fallback)
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
    
    // Get Cloud Run identity token for IAM authentication
    const identityToken = await getIdentityToken(KYC_SERVICE_URL);
    // Also create application-level service token
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
          'Authorization': `Bearer ${identityToken}`, // Cloud Run IAM token
          'X-Service-Token': serviceToken // Application-level service token
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
    
    // Get Cloud Run identity token for IAM authentication
    const identityToken = await getIdentityToken(KYC_SERVICE_URL);
    // Also create application-level service token
    const serviceToken = createServiceToken();
    
    const response = await axios.get(
      `${KYC_SERVICE_URL}/api/v1/kyc/status/${applicationId}`,
      {
        headers: {
          'Authorization': `Bearer ${identityToken}`, // Cloud Run IAM token
          'X-Service-Token': serviceToken // Application-level service token
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

