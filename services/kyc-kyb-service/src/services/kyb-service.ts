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

      // Use SumSub for international KYB verification
      // SumSub handles company verification globally (200+ countries)
      const connectorRequest = {
        provider: 'sumsub',
        endpoint: '/resources/applicants',
        method: 'POST' as const,
        body: {
          externalUserId: `company-${request.applicationId}`,
          type: 'company', // SumSub company verification type
          info: {
            companyName: request.companyName,
            companyNumber: request.companyNumber,
            country: request.country || 'GB', // Default to UK if not specified
            // Additional company details if available
            ...(request.companyName && { companyName: request.companyName })
          }
        },
        retry: true
      };

      const connectorResponse = await this.connector.call(connectorRequest);

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

      // Map SumSub response to our KYBResponse format
      const response: KYBResponse = {
        applicationId: request.applicationId,
        companyNumber: request.companyNumber,
        status: companyData?.reviewResult?.reviewStatus === 'approved' ? 'verified' : 
                companyData?.reviewResult?.reviewStatus === 'pending' ? 'pending' : 'not_found',
        data: companyData ? {
          companyName: companyData.info?.companyName || request.companyName,
          status: companyData.reviewResult?.reviewStatus || 'unknown',
          incorporationDate: companyData.info?.incorporationDate,
          address: companyData.info?.address ? {
            line1: companyData.info.address.line1,
            line2: companyData.info.address.line2,
            city: companyData.info.address.city,
            postcode: companyData.info.address.postcode,
            country: companyData.info.address.country || request.country || 'GB'
          } : undefined,
          // SumSub provides beneficial owners and directors
          officers: companyData.info?.beneficialOwners || companyData.info?.directors,
          // Additional SumSub verification data
          verificationLevel: companyData.reviewResult?.reviewStatus,
          checks: companyData.reviewResult?.checks,
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

