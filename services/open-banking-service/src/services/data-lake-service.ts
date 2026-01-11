import { Storage } from '@google-cloud/storage';
import { createLogger } from '@credovo/shared-utils/logger';

const logger = createLogger('data-lake-service');

export class DataLakeService {
  private storage: Storage;
  private bucketName: string;

  constructor() {
    this.storage = new Storage();
    this.bucketName = process.env.DATA_LAKE_BUCKET || 'credovo-eu-apps-nonprod-data-lake-raw';
  }

  async storePlaidRequest(type: string, applicationId: string, data: any): Promise<void> {
    try {
      const fileName = `plaid/${type}/requests/${applicationId}/${Date.now()}.json`;
      const file = this.storage.bucket(this.bucketName).file(fileName);
      
      await file.save(JSON.stringify(data, null, 2), {
        contentType: 'application/json',
        metadata: {
          applicationId,
          type: 'plaid-request',
          timestamp: new Date().toISOString(),
        },
      });

      logger.debug('Stored Plaid request in data lake', { fileName, applicationId });
    } catch (error: any) {
      logger.error('Failed to store Plaid request in data lake', error);
      throw error;
    }
  }

  async storePlaidResponse(type: string, applicationId: string, data: any): Promise<void> {
    try {
      const fileName = `plaid/${type}/responses/${applicationId}/${Date.now()}.json`;
      const file = this.storage.bucket(this.bucketName).file(fileName);
      
      await file.save(JSON.stringify(data, null, 2), {
        contentType: 'application/json',
        metadata: {
          applicationId,
          type: 'plaid-response',
          timestamp: new Date().toISOString(),
        },
      });

      logger.debug('Stored Plaid response in data lake', { fileName, applicationId });
    } catch (error: any) {
      logger.error('Failed to store Plaid response in data lake', error);
      throw error;
    }
  }

  async storeRawAPIRequest(provider: string, applicationId: string, data: any): Promise<void> {
    try {
      const fileName = `${provider}/api/requests/${applicationId}/${Date.now()}.json`;
      const file = this.storage.bucket(this.bucketName).file(fileName);
      
      await file.save(JSON.stringify(data, null, 2), {
        contentType: 'application/json',
        metadata: {
          applicationId,
          provider,
          type: 'api-request',
          timestamp: new Date().toISOString(),
        },
      });

      logger.debug('Stored raw API request in data lake', { fileName, applicationId, provider });
    } catch (error: any) {
      logger.error('Failed to store raw API request in data lake', error);
      throw error;
    }
  }

  async storeRawAPIResponse(provider: string, applicationId: string, data: any): Promise<void> {
    try {
      const fileName = `${provider}/api/responses/${applicationId}/${Date.now()}.json`;
      const file = this.storage.bucket(this.bucketName).file(fileName);
      
      await file.save(JSON.stringify(data, null, 2), {
        contentType: 'application/json',
        metadata: {
          applicationId,
          provider,
          type: 'api-response',
          timestamp: new Date().toISOString(),
        },
      });

      logger.debug('Stored raw API response in data lake', { fileName, applicationId, provider });
    } catch (error: any) {
      logger.error('Failed to store raw API response in data lake', error);
      throw error;
    }
  }
}
