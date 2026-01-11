import { KYBRequest, KYBResponse } from '@credovo/shared-types';
import { createLogger } from '@credovo/shared-utils/logger';
import { DataLakeService } from './data-lake-service';
import { PubSubService } from './pubsub-service';
import { ConnectorClient } from './connector-client';

const logger = createLogger('kyb-service');

export class KYBService {
  private dataLake: DataLakeService;
  private pubsub: PubSubService;
  private connector: ConnectorClient;

  constructor() {
    this.dataLake = new DataLakeService();
    this.pubsub = new PubSubService();
    this.connector = new ConnectorClient();
  }

  async verifyCompany(request: KYBRequest): Promise<KYBResponse> {
    logger.info('Verifying company', {
      applicationId: request.applicationId,
      companyNumber: request.companyNumber,
      companyName: request.companyName,
      country: request.country
    });

    try {
      // Store request in data lake
      await this.dataLake.storeKYBRequest(request);

      // Build callback URL for webhook (Shufti Pro will call this when verification completes)
      const orchestrationServiceUrl = process.env.ORCHESTRATION_SERVICE_URL || 'https://orchestration-service-saz24fo3sa-ew.a.run.app';
      const callbackUrl = `${orchestrationServiceUrl}/api/v1/webhooks/shufti-pro`;

      // Use Shufti Pro for international KYB verification (240+ countries, 150+ languages)
      const connectorRequest = {
        provider: 'shufti-pro',
        endpoint: '/',
        method: 'POST' as const,
        body: {
          reference: `kyb-${request.applicationId}-${Date.now()}`,
          callback_url: callbackUrl, // Webhook URL for async results
          country: request.country || 'GB',
          language: 'EN',
          companyName: request.companyName,
          companyNumber: request.companyNumber,
          info: {
            companyName: request.companyName,
            companyNumber: request.companyNumber,
            country: request.country || 'GB'
          },
          business: {
            name: request.companyName,
            registration_number: request.companyNumber,
            jurisdiction_code: request.country || 'GB'
          },
          // Enable AML screening for businesses
          aml_ongoing: 0 // Set to 1 for ongoing monitoring
        },
        retry: true
      };

      // Store raw API request in data lake
      await this.dataLake.storeRawAPIRequest('kyb', request.applicationId, {
        ...connectorRequest,
        timestamp: new Date()
      });

      const connectorResponse = await this.connector.call(connectorRequest);

      // Store raw API response in data lake
      await this.dataLake.storeRawAPIResponse('kyb', request.applicationId, {
        ...connectorResponse,
        timestamp: new Date()
      });

      if (!connectorResponse.success) {
        const errorResponse: KYBResponse = {
          applicationId: request.applicationId,
          companyNumber: request.companyNumber,
          status: 'error',
          timestamp: new Date()
        };

        await this.dataLake.storeKYBResponse(errorResponse);
        throw new Error(connectorResponse.error?.message || 'Company verification failed');
      }

      const companyData = connectorResponse.data;

      // Map Shufti Pro response to our KYBResponse format
      const verificationResult = companyData?.verification_result || companyData;
      const event = companyData?.event || verificationResult?.event;
      const isVerified = event === 'verification.accepted' || event === 'approved';
      const isPending = event === 'verification.pending' || event === 'pending';

      const response: KYBResponse = {
        applicationId: request.applicationId,
        companyNumber: request.companyNumber,
        status: isVerified ? 'verified' : 
                isPending ? 'pending' : 'not_found',
        data: verificationResult?.business || companyData ? {
          companyName: verificationResult?.business?.name || 
                       companyData?.business?.name || 
                       request.companyName,
          status: event || verificationResult?.business?.status || 'unknown',
          incorporationDate: verificationResult?.business?.incorporation_date || 
                            companyData?.business?.incorporation_date,
          address: verificationResult?.business?.address || companyData?.business?.address ? {
            line1: (verificationResult?.business?.address || companyData?.business?.address)?.line1,
            line2: (verificationResult?.business?.address || companyData?.business?.address)?.line2,
            city: (verificationResult?.business?.address || companyData?.business?.address)?.city,
            postcode: (verificationResult?.business?.address || companyData?.business?.address)?.postcode,
            country: (verificationResult?.business?.address || companyData?.business?.address)?.country || 
                    request.country || 'GB'
          } : undefined,
          // Shufti Pro provides beneficial owners and directors
          officers: verificationResult?.business?.directors || 
                   verificationResult?.business?.beneficial_owners ||
                   companyData?.business?.directors,
          // Additional Shufti Pro verification data
          verificationLevel: event,
          checks: verificationResult?.business?.checks,
          metadata: companyData
        } : undefined,
        timestamp: new Date()
      };

      // Store response in data lake
      await this.dataLake.storeKYBResponse(response);

      // Publish event
      await this.pubsub.publishKYBEvent({
        applicationId: request.applicationId,
        event: 'kyb_verified',
        status: response.status,
        timestamp: new Date()
      });

      return response;
    } catch (error: any) {
      logger.error('Company verification failed', error);
      throw error;
    }
  }
}

