import { Router, Request, Response } from 'express';
import axios from 'axios';
import { createLogger } from '@credovo/shared-utils/logger';

const logger = createLogger('company-search-routes');
export const CompanySearchRouter = Router();

const CONNECTOR_SERVICE_URL = process.env.CONNECTOR_SERVICE_URL || 'http://connector-service:8080';

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
    { service: 'company-search-service', iat: Math.floor(Date.now() / 1000), exp: Math.floor(Date.now() / 1000) + 300 },
    serviceSecret,
    { algorithm: 'HS256' }
  );
}

/**
 * Company Search with Autocomplete
 * GET /api/v1/companies/search?query=company+name&limit=10
 */
CompanySearchRouter.get('/search', async (req: Request, res: Response) => {
  try {
    const query = req.query.query as string;
    const limit = parseInt(req.query.limit as string) || 10;

    if (!query || query.length < 2) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Query parameter is required and must be at least 2 characters'
      });
    }

    const identityToken = await getIdentityToken(CONNECTOR_SERVICE_URL);
    const serviceToken = createServiceToken();

    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'X-Service-Token': serviceToken,
    };
    if (identityToken) {
      headers['Authorization'] = `Bearer ${identityToken}`;
    }

    // Use Clearbit for company search (requires API key configuration)
    const connectorRequest = {
      provider: 'clearbit',
      endpoint: '/v2/companies/search',
      method: 'GET' as const,
      body: {
        query,
        limit,
      },
    };

    const response = await axios.post(
      `${CONNECTOR_SERVICE_URL}/api/v1/connector/call`,
      connectorRequest,
      { headers }
    );

    if (response.data.success) {
      res.json({
        companies: response.data.companies || [],
        count: response.data.count || 0,
      });
    } else {
      throw new Error(response.data.error?.message || 'Failed to search companies');
    }
  } catch (error: any) {
    logger.error('Failed to search companies', error);
    res.status(error.response?.status || 500).json({
      error: 'Failed to search companies',
      message: error.message
    });
  }
});

/**
 * Company Enrichment by Domain
 * GET /api/v1/companies/enrich?domain=example.com
 */
CompanySearchRouter.get('/enrich', async (req: Request, res: Response) => {
  try {
    const domain = req.query.domain as string;

    if (!domain) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Domain parameter is required'
      });
    }

    const identityToken = await getIdentityToken(CONNECTOR_SERVICE_URL);
    const serviceToken = createServiceToken();

    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'X-Service-Token': serviceToken,
    };
    if (identityToken) {
      headers['Authorization'] = `Bearer ${identityToken}`;
    }

    // Use Clearbit for domain lookup
    const connectorRequest = {
      provider: 'clearbit',
      endpoint: '/v1/domains/find',
      method: 'GET' as const,
      body: {
        domain,
      },
    };

    const response = await axios.post(
      `${CONNECTOR_SERVICE_URL}/api/v1/connector/call`,
      connectorRequest,
      { headers }
    );

    if (response.data.success) {
      res.json({
        company: response.data.company,
      });
    } else {
      res.status(404).json({
        error: 'Not Found',
        message: response.data.error?.message || 'Company not found'
      });
    }
  } catch (error: any) {
    logger.error('Failed to enrich company', error);
    res.status(error.response?.status || 500).json({
      error: 'Failed to enrich company',
      message: error.message
    });
  }
});
