import { BaseConnector, ConnectorFeatures } from './base-connector';
import { ConnectorRequest } from '@credovo/shared-types';

export class ShuftiProConnector extends BaseConnector {
  protected providerName = 'shufti-pro';
  protected baseUrl = 'https://api.shuftipro.com';

  getFeatures(): ConnectorFeatures {
    return {
      kyc: true,
      kyb: true,
      aml: true
    };
  }

  async call(request: ConnectorRequest): Promise<any> {
    // Shufti Pro uses the root endpoint (/) for all requests
    // Different request types are distinguished by payload structure
    if (request.endpoint.startsWith('/verify') || request.endpoint === '/') {
      // Check if this is a KYB request (has companyNumber or business data)
      if (request.body?.companyNumber || request.body?.company_registration_number || request.body?.kyb) {
        return this.handleKYBRequest(request);
      }
      // Otherwise it's a KYC request
      return this.handleVerificationRequest(request);
    }

    // Handle KYB (company verification) endpoints
    if (request.endpoint.startsWith('/business')) {
      return this.handleKYBRequest(request);
    }

    // Handle status check endpoints
    if (request.endpoint.startsWith('/status')) {
      return this.handleStatusRequest(request);
    }

    return this.makeRequest(
      request.method,
      request.endpoint,
      request.headers,
      request.body
    );
  }

  private async handleVerificationRequest(request: ConnectorRequest): Promise<any> {
    // Shufti Pro KYC (individual verification)
    const clientId = await this.getClientId();
    const secretKey = await this.getSecretKey();

    if (!clientId || !secretKey) {
      throw new Error('Shufti Pro credentials not configured (need client_id and secret_key)');
    }

    // Shufti Pro uses Basic Auth with client_id and secret_key
    const authHeader = Buffer.from(`${clientId}:${secretKey}`).toString('base64');

    // Prepare KYC request with AML screening
    const kycData = {
      reference: request.body?.reference || `kyc-${Date.now()}`,
      callback_url: request.body?.callback_url,
      email: request.body?.email,
      country: request.body?.country || 'GB',
      language: request.body?.language || 'EN',
      verification_mode: request.body?.verification_mode || 'any',
      document: {
        proof: request.body?.document?.proof || '',
        supported_types: request.body?.document?.supported_types || ['passport', 'driving_license', 'id_card'],
        name: {
          first_name: request.body?.info?.firstName || request.body?.firstName,
          last_name: request.body?.info?.lastName || request.body?.lastName,
          middle_name: request.body?.info?.middleName
        },
        dob: request.body?.info?.dateOfBirth || request.body?.dateOfBirth,
        address: request.body?.info?.address || request.body?.address
      },
      face: {
        proof: request.body?.face?.proof || ''
      },
      // AML Screening (Anti-Money Laundering)
      risk_assessment: {
        name: {
          first_name: request.body?.info?.firstName || request.body?.firstName,
          last_name: request.body?.info?.lastName || request.body?.lastName,
          middle_name: request.body?.info?.middleName
        },
        dob: request.body?.info?.dateOfBirth || request.body?.dateOfBirth,
        // Optional: Enable ongoing AML monitoring
        ongoing: request.body?.aml_ongoing || 0
      }
    };

    const response = await this.makeRequest(
      'POST',
      '/',
      {
        'Authorization': `Basic ${authHeader}`,
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
      kycData
    );

    return response;
  }

  private async handleKYBRequest(request: ConnectorRequest): Promise<any> {
    // Shufti Pro KYB (company verification)
    // According to Shufti Pro API docs, KYB uses root endpoint (/) with kyb payload
    const clientId = await this.getClientId();
    const secretKey = await this.getSecretKey();

    if (!clientId || !secretKey) {
      throw new Error('Shufti Pro credentials not configured (need client_id and secret_key)');
    }

    const authHeader = Buffer.from(`${clientId}:${secretKey}`).toString('base64');

    // Extract company info from various possible locations in request
    const companyNumber = request.body?.companyNumber || 
                         request.body?.info?.companyNumber || 
                         request.body?.company_registration_number ||
                         request.body?.kyb?.company_registration_number;
    const companyName = request.body?.companyName || 
                       request.body?.info?.companyName;
    const jurisdictionCode = request.body?.country || 
                            request.body?.info?.country || 
                            request.body?.jurisdiction_code ||
                            request.body?.kyb?.company_jurisdiction_code || 
                            'GB';

    // Prepare KYB request according to Shufti Pro API structure
    const kybData: any = {
      reference: request.body?.reference || `kyb-${Date.now()}`,
      callback_url: request.body?.callback_url,
      country: request.body?.country || jurisdictionCode || 'GB',
      language: request.body?.language || 'EN',
      kyb: {
        company_registration_number: companyNumber,
        company_jurisdiction_code: jurisdictionCode
      }
    };

    // Add optional fields if provided
    if (request.body?.email) {
      kybData.email = request.body.email;
    }

    // AML Screening for businesses (optional)
    if (request.body?.aml_ongoing !== undefined) {
      kybData.risk_assessment = {
        business_name: companyName,
        ongoing: request.body.aml_ongoing || 0
      };
    }

    const response = await this.makeRequest(
      'POST',
      '/',
      {
        'Authorization': `Basic ${authHeader}`,
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
      kybData
    );

    return response;
  }

  private async getClientId(): Promise<string> {
    // In production, fetch from Secret Manager
    const secretName = `${this.providerName}-client-id`;
    return process.env[secretName.toUpperCase().replace(/-/g, '_')] || '';
  }

  private async handleStatusRequest(request: ConnectorRequest): Promise<any> {
    // Shufti Pro Status Check API
    const clientId = await this.getClientId();
    const secretKey = await this.getSecretKey();

    if (!clientId || !secretKey) {
      throw new Error('Shufti Pro credentials not configured (need client_id and secret_key)');
    }

    const authHeader = Buffer.from(`${clientId}:${secretKey}`).toString('base64');

    // Extract reference from endpoint (e.g., /status/kyc-123456 or /status?reference=kyc-123456)
    let reference = request.body?.reference;
    if (!reference && request.endpoint) {
      // Extract from path: /status/kyc-123456 or /status/kyb-123456
      const pathParts = request.endpoint.split('/');
      reference = pathParts[pathParts.length - 1];
    }

    if (!reference) {
      throw new Error('Reference is required for status check');
    }

    // Shufti Pro status check uses POST with reference in body
    const statusData = {
      reference: reference
    };

    try {
      const response = await this.makeRequest(
        'POST',
        '/status',
        {
          'Authorization': `Basic ${authHeader}`,
          'Content-Type': 'application/json'
        },
        statusData
      );

      return {
        success: true,
        reference: reference,
        ...response
      };
    } catch (error: any) {
      // Retry logic for status checks (up to 3 retries with exponential backoff)
      const maxRetries = request.retry !== false ? 3 : 0;
      let retries = 0;
      let lastError = error;

      while (retries < maxRetries) {
        retries++;
        const delay = Math.pow(2, retries) * 1000; // Exponential backoff: 2s, 4s, 8s
        
        await new Promise(resolve => setTimeout(resolve, delay));

        try {
          const retryResponse = await this.makeRequest(
            'POST',
            '/status',
            {
              'Authorization': `Basic ${authHeader}`,
              'Content-Type': 'application/json'
            },
            statusData
          );

          return {
            success: true,
            reference: reference,
            retries: retries,
            ...retryResponse
          };
        } catch (retryError: any) {
          lastError = retryError;
          if (retries === maxRetries) {
            break;
          }
        }
      }

      // If all retries failed, return error response
      return {
        success: false,
        reference: reference,
        error: {
          message: lastError.message || 'Status check failed after retries',
          code: lastError.response?.status || 500,
          retries: retries
        }
      };
    }
  }

  private async getSecretKey(): Promise<string> {
    // In production, fetch from Secret Manager
    const secretName = `${this.providerName}-secret-key`;
    return process.env[secretName.toUpperCase().replace(/-/g, '_')] || '';
  }
}


