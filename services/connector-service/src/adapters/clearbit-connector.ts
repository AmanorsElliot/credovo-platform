import { BaseConnector, ConnectorFeatures } from './base-connector';
import { ConnectorRequest } from '@credovo/shared-types';
import axios from 'axios';

/**
 * Clearbit Connector for Company Search and Enrichment
 * 
 * Clearbit provides:
 * - Company search with autocomplete
 * - Company enrichment (employees, revenue, industry, etc.)
 * - Domain lookup
 * - Person enrichment
 * 
 * Documentation: https://clearbit.com/docs
 */
export class ClearbitConnector extends BaseConnector {
  protected providerName = 'clearbit';
  protected baseUrl = 'https://company.clearbit.com';

  getFeatures(): ConnectorFeatures {
    return {
      companySearch: true,
      companyEnrichment: true,
      autocomplete: true,
    };
  }

  async call(request: ConnectorRequest): Promise<any> {
    const apiKey = await this.getApiKey();

    if (!apiKey) {
      throw new Error('Clearbit API key not configured');
    }

    // Determine which Clearbit endpoint to call
    if (request.endpoint?.includes('/v2/companies/find') || request.endpoint?.includes('/v2/companies/search')) {
      return this.handleCompanySearch(request, apiKey);
    } else if (request.endpoint?.includes('/v1/domains/find')) {
      return this.handleDomainLookup(request, apiKey);
    } else {
      // Generic Clearbit API call
      return this.handleGenericRequest(request, apiKey);
    }
  }

  private async getApiKey(): Promise<string> {
    const secretName = `${this.providerName}-api-key`;
    return process.env[secretName.toUpperCase().replace(/-/g, '_')] || '';
  }

  /**
   * Company Search with Autocomplete
   * GET /v2/companies/search?query=company+name
   */
  private async handleCompanySearch(request: ConnectorRequest, apiKey: string): Promise<any> {
    const query = request.body?.query || request.body?.name || '';
    
    if (!query) {
      throw new Error('Company name or query is required');
    }

    try {
      const response = await axios.get(
        `${this.baseUrl}/v2/companies/search`,
        {
          params: {
            query: query,
            limit: request.body?.limit || 10,
          },
          headers: {
            'Authorization': `Bearer ${apiKey}`,
            'Accept': 'application/json',
          },
          timeout: 10000,
        }
      );

      return {
        success: true,
        companies: response.data,
        count: Array.isArray(response.data) ? response.data.length : 1,
      };
    } catch (error: any) {
      if (error.response?.status === 404) {
        return {
          success: true,
          companies: [],
          count: 0,
        };
      }
      throw error;
    }
  }

  /**
   * Company Enrichment by Domain
   * GET /v2/companies/find?domain=example.com
   */
  private async handleDomainLookup(request: ConnectorRequest, apiKey: string): Promise<any> {
    const domain = request.body?.domain;

    if (!domain) {
      throw new Error('Domain is required for company enrichment');
    }

    try {
      const response = await axios.get(
        `${this.baseUrl}/v2/companies/find`,
        {
          params: { domain },
          headers: {
            'Authorization': `Bearer ${apiKey}`,
            'Accept': 'application/json',
          },
          timeout: 10000,
        }
      );

      return {
        success: true,
        company: response.data,
      };
    } catch (error: any) {
      if (error.response?.status === 404) {
        return {
          success: false,
          error: {
            code: 'COMPANY_NOT_FOUND',
            message: 'Company not found for domain',
          },
        };
      }
      throw error;
    }
  }

  /**
   * Generic Clearbit API request handler
   */
  private async handleGenericRequest(request: ConnectorRequest, apiKey: string): Promise<any> {
    const endpoint = request.endpoint || '/';
    const method = request.method || 'GET';

    const headers: Record<string, string> = {
      'Authorization': `Bearer ${apiKey}`,
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      ...request.headers,
    };

    try {
      const response = await axios({
        method,
        url: `${this.baseUrl}${endpoint}`,
        headers,
        data: request.body,
        params: request.body?.params,
        timeout: 10000,
      });

      return {
        success: true,
        data: response.data,
      };
    } catch (error: any) {
      if (error.response) {
        const clearbitError = error.response.data || {};
        throw new Error(`Clearbit API error: ${clearbitError.error?.message || error.message}`);
      }
      throw error;
    }
  }
}
