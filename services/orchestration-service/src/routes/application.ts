import { Router, Request, Response } from 'express';
import axios from 'axios';
import jwt from 'jsonwebtoken';
import { createLogger } from '@credovo/shared-utils/logger';
import { validateRequest, validateParams } from '@credovo/shared-types/validation-middleware';
import { ApplicationIdParamSchema, KYCRequestSchema, KYBRequestSchema } from '@credovo/shared-types/validation';
import { Application, ApplicationStatus } from '@credovo/shared-types';

const logger = createLogger('orchestration-service');
export const ApplicationRouter = Router();

const KYC_SERVICE_URL = process.env.KYC_SERVICE_URL || 'http://kyc-kyb-service:8080';

// Helper function to get Cloud Run identity token for service-to-service calls
// Uses the Metadata Server available in Cloud Run
async function getIdentityToken(audience: string): Promise<string | null> {
  try {
    const metadataServerTokenUrl = 'http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/identity';
    const response = await axios.get(metadataServerTokenUrl, {
      params: {
        audience: audience
      },
      headers: {
        'Metadata-Flavor': 'Google'
      },
      timeout: 5000
    });
    // The response should be the token as a string
    const token = typeof response.data === 'string' ? response.data.trim() : response.data;
    logger.debug('Successfully retrieved identity token from Metadata Server');
    return token;
  } catch (error: any) {
    logger.warn('Failed to get identity token from Metadata Server', {
      error: error.message,
      code: error.code
    });
    // Return null to indicate we should skip IAM token (services might be public)
    return null;
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

/**
 * Create a new application
 * POST /api/v1/applications
 */
ApplicationRouter.post('/', async (req: Request, res: Response) => {
  try {
    const userId = req.userId;
    
    if (!userId) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'User ID is required'
      });
    }

    // Generate application ID
    const applicationId = `app-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    
    // Create application object
    const application: Application = {
      id: applicationId,
      userId: userId,
      status: ApplicationStatus.PENDING,
      createdAt: new Date(),
      updatedAt: new Date(),
      data: {
        type: req.body.type || 'business_mortgage',
        ...req.body
      }
    };

    logger.info('Application created', {
      applicationId,
      userId,
      type: application.data.type
    });

    res.status(201).json({
      success: true,
      application: {
        id: application.id,
        userId: application.userId,
        status: application.status,
        createdAt: application.createdAt,
        updatedAt: application.updatedAt,
        data: application.data
      }
    });
  } catch (error: any) {
    logger.error('Failed to create application', error);
    res.status(500).json({
      error: 'Failed to create application',
      message: error.message
    });
  }
});

/**
 * Get application by ID
 * GET /api/v1/applications/:applicationId
 */
ApplicationRouter.get('/:applicationId', 
  validateParams(ApplicationIdParamSchema),
  async (req: Request, res: Response) => {
    try {
      const { applicationId } = req.params;
      const userId = req.userId;

      if (!userId) {
        return res.status(401).json({
          error: 'Unauthorized',
          message: 'User ID is required'
        });
      }

      // TODO: In the future, this would fetch from a database
      // For now, return a basic response
      logger.info('Application retrieved', { applicationId, userId });

      res.json({
        id: applicationId,
        userId: userId,
        status: ApplicationStatus.PENDING,
        createdAt: new Date(),
        updatedAt: new Date(),
        data: {}
      });
    } catch (error: any) {
      logger.error('Failed to get application', error);
      res.status(500).json({
        error: 'Failed to get application',
        message: error.message
      });
    }
  }
);

ApplicationRouter.post('/:applicationId/kyc/initiate', 
  validateParams(ApplicationIdParamSchema),
  validateRequest({ body: KYCRequestSchema.omit({ applicationId: true, userId: true }) }),
  async (req: Request, res: Response) => {
    try {
      const { applicationId } = req.params;
      
      // Try to get Cloud Run identity token for IAM authentication (optional if service is public)
      const identityToken = await getIdentityToken(KYC_SERVICE_URL);
      // Create application-level service token (required)
      const serviceToken = createServiceToken();
      
      // Build headers - include identity token if available, always include service token
      const headers: Record<string, string> = {
        'X-Service-Token': serviceToken // Application-level service token
      };
      
      if (identityToken) {
        headers['Authorization'] = `Bearer ${identityToken}`; // Cloud Run IAM token (if available)
      }
      
      // Combine validated body with applicationId and userId
      const validatedBody = {
        ...req.body,
        applicationId,
        userId: req.userId
      };
      
      const response = await axios.post(
        `${KYC_SERVICE_URL}/api/v1/kyc/initiate`,
        validatedBody,
        {
          headers
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
  }
);

ApplicationRouter.get('/:applicationId/kyc/status',
  validateParams(ApplicationIdParamSchema),
  async (req: Request, res: Response) => {
    try {
      const { applicationId } = req.params;
    
    // Try to get Cloud Run identity token for IAM authentication (optional if service is public)
    const identityToken = await getIdentityToken(KYC_SERVICE_URL);
    // Create application-level service token (required)
    const serviceToken = createServiceToken();
    
    // Build headers - include identity token if available, always include service token
    const headers: Record<string, string> = {
      'X-Service-Token': serviceToken // Application-level service token
    };
    
    if (identityToken) {
      headers['Authorization'] = `Bearer ${identityToken}`; // Cloud Run IAM token (if available)
    }
    
    const response = await axios.get(
      `${KYC_SERVICE_URL}/api/v1/kyc/status/${applicationId}`,
      {
        headers
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

ApplicationRouter.post('/:applicationId/kyb/verify',
  validateParams(ApplicationIdParamSchema),
  validateRequest({ body: KYBRequestSchema.omit({ applicationId: true }) }),
  async (req: Request, res: Response) => {
    try {
      const { applicationId } = req.params;
      
      // Try to get Cloud Run identity token for IAM authentication (optional if service is public)
      const identityToken = await getIdentityToken(KYC_SERVICE_URL);
      // Create application-level service token (required)
      const serviceToken = createServiceToken();
      
      // Build headers - include identity token if available, always include service token
      const headers: Record<string, string> = {
        'X-Service-Token': serviceToken // Application-level service token
      };
      
      if (identityToken) {
        headers['Authorization'] = `Bearer ${identityToken}`; // Cloud Run IAM token (if available)
      }
      
      // Combine validated body with applicationId
      const validatedBody = {
        ...req.body,
        applicationId
      };
      
      const response = await axios.post(
        `${KYC_SERVICE_URL}/api/v1/kyb/verify`,
        validatedBody,
        {
          headers
        }
      );

      res.json(response.data);
    } catch (error: any) {
      logger.error('Failed to verify KYB', error);
      res.status(error.response?.status || 500).json({
        error: 'Failed to verify KYB',
        message: error.message
      });
    }
  }
);

ApplicationRouter.get('/:applicationId/kyb/status',
  validateParams(ApplicationIdParamSchema),
  async (req: Request, res: Response) => {
    try {
      const { applicationId } = req.params;
    
    // Try to get Cloud Run identity token for IAM authentication (optional if service is public)
    const identityToken = await getIdentityToken(KYC_SERVICE_URL);
    // Create application-level service token (required)
    const serviceToken = createServiceToken();
    
    // Build headers - include identity token if available, always include service token
    const headers: Record<string, string> = {
      'X-Service-Token': serviceToken // Application-level service token
    };
    
    if (identityToken) {
      headers['Authorization'] = `Bearer ${identityToken}`; // Cloud Run IAM token (if available)
    }
    
    const response = await axios.get(
      `${KYC_SERVICE_URL}/api/v1/kyb/status/${applicationId}`,
      {
        headers
      }
    );

    res.json(response.data);
  } catch (error: any) {
    logger.error('Failed to get KYB status', error);
    res.status(error.response?.status || 500).json({
      error: 'Failed to get KYB status',
      message: error.message
    });
  }
});

