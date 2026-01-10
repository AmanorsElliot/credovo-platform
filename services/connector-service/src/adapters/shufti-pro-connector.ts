import { BaseConnector, ConnectorFeatures } from './base-connector';
import { ConnectorRequest } from '@credovo/shared-types';

export class ShuftiProConnector extends BaseConnector {
  protected providerName = 'shufti-pro';
  protected baseUrl = 'https://api.shuftipro.com';

  getFeatures(): ConnectorFeatures {
    return {
      kyc: true,
      kyb: true
    };
  }

  async call(request: ConnectorRequest): Promise<any> {
    // Shufti Pro uses different endpoints for KYC and KYB
    if (request.endpoint.startsWith('/verify')) {
      return this.handleVerificationRequest(request);
    }

    // Handle KYB (company verification) endpoints
    if (request.endpoint.startsWith('/business') || request.body?.reference) {
      return this.handleKYBRequest(request);
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

    // Prepare KYC request
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
      }
    };

    const response = await this.makeRequest(
      'POST',
      '/verify',
      {
        'Authorization': `Basic ${authHeader}`,
        'Content-Type': 'application/json'
      },
      kycData
    );

    return response;
  }

  private async handleKYBRequest(request: ConnectorRequest): Promise<any> {
    // Shufti Pro KYB (company verification)
    const clientId = await this.getClientId();
    const secretKey = await this.getSecretKey();

    if (!clientId || !secretKey) {
      throw new Error('Shufti Pro credentials not configured (need client_id and secret_key)');
    }

    const authHeader = Buffer.from(`${clientId}:${secretKey}`).toString('base64');

    // Prepare KYB request
    const kybData = {
      reference: request.body?.reference || `kyb-${Date.now()}`,
      callback_url: request.body?.callback_url,
      email: request.body?.email,
      country: request.body?.country || request.body?.info?.country || 'GB',
      language: request.body?.language || 'EN',
      business: {
        name: request.body?.info?.companyName || request.body?.companyName,
        registration_number: request.body?.info?.companyNumber || request.body?.companyNumber,
        jurisdiction_code: request.body?.info?.country || request.body?.country || 'GB',
        ...request.body?.business
      }
    };

    const response = await this.makeRequest(
      'POST',
      '/business',
      {
        'Authorization': `Basic ${authHeader}`,
        'Content-Type': 'application/json'
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

  private async getSecretKey(): Promise<string> {
    // In production, fetch from Secret Manager
    const secretName = `${this.providerName}-secret-key`;
    return process.env[secretName.toUpperCase().replace(/-/g, '_')] || '';
  }
}

