import { Router, Request, Response } from 'express';
import axios from 'axios';
import { createLogger } from '@credovo/shared-utils/logger';
import { validateQuery } from '@credovo/shared-types/validation-middleware';
import { CompanySearchQuerySchema } from '@credovo/shared-types/validation';

const logger = createLogger('orchestration-company-search');
export const CompanySearchRouter = Router();

const COMPANY_SEARCH_SERVICE_URL = process.env.COMPANY_SEARCH_SERVICE_URL || 'http://company-search-service:8080';

// Helper function to get Cloud Run identity token
async function getIdentityToken(audience: string): Promise<string | null> {
  try {
    const metadataServerTokenUrl = 'http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/identity';
    const response = await axios.get(metadataServerTokenUrl, {
      params: { audience },
      headers: { 'Metadata-Flavor': 'Google' },
      timeout: 5000
    });
    return typeof response.data === 'string' ? response.data.trim() : response.data;
  } catch (error: any) {
    logger.warn('Failed to get identity token', { error: error.message });
    return null;
  }
}

// Helper function to create service token
function createServiceToken(): string {
  const serviceSecret = process.env.SERVICE_JWT_SECRET;
  if (!serviceSecret) {
    throw new Error('SERVICE_JWT_SECRET not configured');
  }
  const jwt = require('jsonwebtoken');
  return jwt.sign(
    { service: 'orchestration-service', iat: Math.floor(Date.now() / 1000), exp: Math.floor(Date.now() / 1000) + 300 },
    serviceSecret,
    { algorithm: 'HS256' }
  );
}

/**
 * Company Search with Autocomplete
 * GET /api/v1/companies/search?query=company+name&limit=10
 */
CompanySearchRouter.get('/search',
  validateQuery(CompanySearchQuerySchema),
  async (req: Request, res: Response) => {
    try {
      // Check if company search service is configured
      if (!COMPANY_SEARCH_SERVICE_URL || COMPANY_SEARCH_SERVICE_URL.includes('company-search-service:8080')) {
        return res.status(503).json({
          error: 'Service Unavailable',
          message: 'Company search service is not configured. Please deploy company-search-service first.'
        });
      }

      const identityToken = await getIdentityToken(COMPANY_SEARCH_SERVICE_URL);
      const serviceToken = createServiceToken();

      const headers: Record<string, string> = {
        'Content-Type': 'application/json',
        'X-Service-Token': serviceToken,
      };
      if (identityToken) {
        headers['Authorization'] = `Bearer ${identityToken}`;
      }

      const response = await axios.get(
        `${COMPANY_SEARCH_SERVICE_URL}/api/v1/companies/search`,
        {
          params: req.query,
          headers,
          timeout: 10000,
        }
      );

      res.json(response.data);
    } catch (error: any) {
      logger.error('Failed to search companies', error);
      
      // Handle service not available gracefully
      if (error.code === 'ECONNREFUSED' || error.code === 'ENOTFOUND' || error.response?.status === 404) {
        return res.status(503).json({
          error: 'Service Unavailable',
          message: 'Company search service is not available. Please ensure company-search-service is deployed.'
        });
      }
      
      res.status(error.response?.status || 500).json({
        error: 'Failed to search companies',
        message: error.message
      });
    }
  }
);

/**
 * Company Enrichment by Domain
 * GET /api/v1/companies/enrich?domain=example.com
 */
CompanySearchRouter.get('/enrich', async (req: Request, res: Response) => {
  try {
    // Check if company search service is configured
    if (!COMPANY_SEARCH_SERVICE_URL || COMPANY_SEARCH_SERVICE_URL.includes('company-search-service:8080')) {
      return res.status(503).json({
        error: 'Service Unavailable',
        message: 'Company search service is not configured. Please deploy company-search-service first.'
      });
    }

    const identityToken = await getIdentityToken(COMPANY_SEARCH_SERVICE_URL);
    const serviceToken = createServiceToken();

    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'X-Service-Token': serviceToken,
    };
    if (identityToken) {
      headers['Authorization'] = `Bearer ${identityToken}`;
    }

    const response = await axios.get(
      `${COMPANY_SEARCH_SERVICE_URL}/api/v1/companies/enrich`,
      {
        params: req.query,
        headers,
        timeout: 10000,
      }
    );

    res.json(response.data);
  } catch (error: any) {
    logger.error('Failed to enrich company', error);
    
    // Handle service not available gracefully
    if (error.code === 'ECONNREFUSED' || error.code === 'ENOTFOUND' || error.response?.status === 404) {
      return res.status(503).json({
        error: 'Service Unavailable',
        message: 'Company search service is not available. Please ensure company-search-service is deployed.'
      });
    }
    
    res.status(error.response?.status || 500).json({
      error: 'Failed to enrich company',
      message: error.message
    });
  }
});
