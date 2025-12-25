import { Storage } from '@google-cloud/storage';
import { KYCRequest, KYCResponse, KYBRequest, KYBResponse } from '@credovo/shared-types';
import { createLogger } from '@credovo/shared-utils/logger';

const logger = createLogger('data-lake-service');

export class DataLakeService {
  private storage: Storage;
  private bucketName: string;

  constructor() {
    this.storage = new Storage();
    this.bucketName = process.env.DATA_LAKE_BUCKET || 'credovo-data-lake-raw';
  }

  async storeKYCRequest(request: KYCRequest): Promise<void> {
    const path = `kyc/requests/${request.applicationId}/${Date.now()}.json`;
    const file = this.storage.bucket(this.bucketName).file(path);
    
    await file.save(JSON.stringify(request, null, 2), {
      contentType: 'application/json',
      metadata: {
        applicationId: request.applicationId,
        userId: request.userId,
        type: 'kyc-request'
      }
    });

    logger.info('Stored KYC request to data lake', { path, applicationId: request.applicationId });
  }

  async storeKYCResponse(response: KYCResponse): Promise<void> {
    const path = `kyc/responses/${response.applicationId}/${Date.now()}.json`;
    const file = this.storage.bucket(this.bucketName).file(path);
    
    await file.save(JSON.stringify(response, null, 2), {
      contentType: 'application/json',
      metadata: {
        applicationId: response.applicationId,
        status: response.status,
        provider: response.provider,
        type: 'kyc-response'
      }
    });

    logger.info('Stored KYC response to data lake', { path, applicationId: response.applicationId });
  }

  async getKYCResponse(applicationId: string): Promise<KYCResponse | null> {
    const prefix = `kyc/responses/${applicationId}/`;
    const [files] = await this.storage.bucket(this.bucketName).getFiles({ prefix });
    
    if (files.length === 0) {
      return null;
    }

    // Get the most recent file
    const latestFile = files.sort((a, b) => {
      const timeA = a.metadata.timeCreated || '';
      const timeB = b.metadata.timeCreated || '';
      return timeB.localeCompare(timeA);
    })[0];

    const [content] = await latestFile.download();
    return JSON.parse(content.toString());
  }

  async storeKYBRequest(request: KYBRequest): Promise<void> {
    const path = `kyb/requests/${request.applicationId}/${Date.now()}.json`;
    const file = this.storage.bucket(this.bucketName).file(path);
    
    await file.save(JSON.stringify(request, null, 2), {
      contentType: 'application/json',
      metadata: {
        applicationId: request.applicationId,
        companyNumber: request.companyNumber,
        type: 'kyb-request'
      }
    });

    logger.info('Stored KYB request to data lake', { path, applicationId: request.applicationId });
  }

  async storeKYBResponse(response: KYBResponse): Promise<void> {
    const path = `kyb/responses/${response.applicationId}/${Date.now()}.json`;
    const file = this.storage.bucket(this.bucketName).file(path);
    
    await file.save(JSON.stringify(response, null, 2), {
      contentType: 'application/json',
      metadata: {
        applicationId: response.applicationId,
        companyNumber: response.companyNumber,
        status: response.status,
        type: 'kyb-response'
      }
    });

    logger.info('Stored KYB response to data lake', { path, applicationId: response.applicationId });
  }
}

