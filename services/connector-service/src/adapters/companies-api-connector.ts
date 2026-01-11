import { BaseConnector, ConnectorFeatures } from './base-connector';
import { ConnectorRequest } from '@credovo/shared-types';
import axios from 'axios';

/**
 * The Companies API Connector for Company Search
 * 
 * The Companies API provides:
 * - Company search with autocomplete
 * - UK company data and verification
 * - Company details and filings
 * - Lead verification
 * 
 * Documentation: https://www.thecompaniesapi.com/
 */
export class CompaniesApiConnector extends BaseConnector {
  protected providerName = 'companies-api';
  protected baseUrl = 'https://api.thecompaniesapi.com';

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
      throw new Error('The Companies API key not configured');
    }

    // Determine which endpoint to call
    if (request.endpoint?.includes('/search') || request.endpoint?.includes('/autocomplete')) {
      return this.handleCompanySearch(request, apiKey);
    } else if (request.endpoint?.includes('/company') || request.endpoint?.includes('/lookup')) {
      return this.handleCompanyLookup(request, apiKey);
    } else {
      // Generic API call
      return this.handleGenericRequest(request, apiKey);
    }
  }

  private async getApiKey(): Promise<string> {
    const secretName = `${this.providerName}-api-key`;
    return process.env[secretName.toUpperCase().replace(/-/g, '_')] || '';
  }

  /**
   * Company Search with Autocomplete
   * GET /v1/search?q=company+name&limit=10
   */
  private async handleCompanySearch(request: ConnectorRequest, apiKey: string): Promise<any> {
    const query = request.body?.query || request.body?.q || request.body?.name || '';
    
    if (!query || query.length < 2) {
      throw new Error('Company name or query is required (minimum 2 characters)');
    }

    try {
      // The Companies API typically uses query parameters
      const response = await axios.get(
        `${this.baseUrl}/v1/search`,
        {
          params: {
            q: query,
            limit: request.body?.limit || 10,
            api_key: apiKey,
          },
          headers: {
            'Accept': 'application/json',
          },
          timeout: 10000,
        }
      );

      // Transform response to standard format
      const companies = Array.isArray(response.data) ? response.data : 
                       response.data?.results || response.data?.companies || 
                       (response.data ? [response.data] : []);

      return {
        success: true,
        companies: companies.map((company: any) => this.transformCompany(company)),
        count: companies.length,
      };
    } catch (error: any) {
      if (error.response?.status === 404) {
        return {
          success: true,
          companies: [],
          count: 0,
        };
      }
      throw new Error(`The Companies API error: ${error.response?.data?.error || error.message}`);
    }
  }

  /**
   * Company Lookup by Name or Company Number
   * GET /v1/company?name=company+name or GET /v1/company?number=12345678
   */
  private async handleCompanyLookup(request: ConnectorRequest, apiKey: string): Promise<any> {
    const companyName = request.body?.name || request.body?.company_name;
    const companyNumber = request.body?.number || request.body?.company_number;

    if (!companyName && !companyNumber) {
      throw new Error('Company name or number is required');
    }

    try {
      const params: Record<string, any> = {
        api_key: apiKey,
      };

      if (companyNumber) {
        params.number = companyNumber;
      } else {
        params.name = companyName;
      }

      const response = await axios.get(
        `${this.baseUrl}/v1/company`,
        {
          params,
          headers: {
            'Accept': 'application/json',
          },
          timeout: 10000,
        }
      );

      return {
        success: true,
        company: this.transformCompany(response.data),
      };
    } catch (error: any) {
      if (error.response?.status === 404) {
        return {
          success: false,
          error: {
            code: 'COMPANY_NOT_FOUND',
            message: 'Company not found',
          },
        };
      }
      throw new Error(`The Companies API error: ${error.response?.data?.error || error.message}`);
    }
  }

  /**
   * Transform company data to standard format
   */
  private transformCompany(company: any): any {
    return {
      name: company.name || company.company_name || company.title,
      number: company.number || company.company_number || company.registration_number,
      jurisdiction: company.jurisdiction || company.country || 'GB',
      status: company.status || company.company_status,
      type: company.type || company.company_type,
      address: company.address || company.registered_address,
      incorporationDate: company.incorporation_date || company.date_of_incorporation,
      website: company.website || company.domain,
      description: company.description || company.nature_of_business,
      sicCodes: company.sic_codes || company.sic,
      // Preserve original data
      raw: company,
    };
  }

  /**
   * Generic The Companies API request handler
   */
  private async handleGenericRequest(request: ConnectorRequest, apiKey: string): Promise<any> {
    const endpoint = request.endpoint || '/v1/search';
    const method = request.method || 'GET';

    const params: Record<string, any> = {
      api_key: apiKey,
      ...request.body,
    };

    try {
      const response = await axios({
        method,
        url: `${this.baseUrl}${endpoint}`,
        params: method === 'GET' ? params : undefined,
        data: method !== 'GET' ? request.body : undefined,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          ...request.headers,
        },
        timeout: 10000,
      });

      return {
        success: true,
        data: response.data,
      };
    } catch (error: any) {
      if (error.response) {
        const apiError = error.response.data || {};
        throw new Error(`The Companies API error: ${apiError.error || error.message}`);
      }
      throw error;
    }
  }
}
