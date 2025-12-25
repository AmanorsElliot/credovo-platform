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
      companyNumber: request.companyNumber
    });

    try {
      // Store request in data lake
      await this.dataLake.storeKYBRequest(request);

      // Call Companies House API via connector service
      const connectorRequest = {
        provider: 'companies-house',
        endpoint: `/company/${request.companyNumber}`,
        method: 'GET' as const,
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

      const response: KYBResponse = {
        applicationId: request.applicationId,
        companyNumber: request.companyNumber,
        status: companyData ? 'verified' : 'not_found',
        data: companyData ? {
          companyName: companyData.company_name,
          status: companyData.company_status,
          incorporationDate: companyData.date_of_creation,
          address: companyData.registered_office_address ? {
            line1: companyData.registered_office_address.address_line_1,
            line2: companyData.registered_office_address.address_line_2,
            city: companyData.registered_office_address.locality,
            postcode: companyData.registered_office_address.postal_code,
            country: companyData.registered_office_address.country || 'GB'
          } : undefined,
          officers: companyData.officers
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

