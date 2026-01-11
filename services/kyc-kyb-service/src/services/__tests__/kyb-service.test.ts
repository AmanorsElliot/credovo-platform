import { KYBService } from '../kyb-service';
import { DataLakeService } from '../data-lake-service';
import { ConnectorClient } from '../connector-client';
import { KYBRequest, KYBResponse } from '@credovo/shared-types';

// Mock dependencies
jest.mock('../data-lake-service');
jest.mock('../connector-client');
jest.mock('../pubsub-service');

describe('KYBService', () => {
  let kybService: KYBService;
  let mockDataLake: jest.Mocked<DataLakeService>;
  let mockConnector: jest.Mocked<ConnectorClient>;

  beforeEach(() => {
    jest.clearAllMocks();
    
    mockDataLake = {
      storeKYBRequest: jest.fn().mockResolvedValue(undefined),
      storeKYBResponse: jest.fn().mockResolvedValue(undefined),
      getKYBResponse: jest.fn(),
      storeRawAPIRequest: jest.fn().mockResolvedValue(undefined),
      storeRawAPIResponse: jest.fn().mockResolvedValue(undefined),
      getRawAPIRequest: jest.fn(),
    } as any;

    mockConnector = {
      call: jest.fn(),
    } as any;

    jest.spyOn(DataLakeService.prototype, 'storeKYBRequest').mockImplementation(mockDataLake.storeKYBRequest);
    jest.spyOn(DataLakeService.prototype, 'storeKYBResponse').mockImplementation(mockDataLake.storeKYBResponse);
    jest.spyOn(DataLakeService.prototype, 'getKYBResponse').mockImplementation(mockDataLake.getKYBResponse);
    jest.spyOn(ConnectorClient.prototype, 'call').mockImplementation(mockConnector.call);

    kybService = new KYBService();
  });

  describe('verifyCompany', () => {
    const mockKYBRequest: KYBRequest = {
      applicationId: 'test-app-123',
      companyNumber: '12345678',
      companyName: 'Test Company Ltd',
      country: 'GB',
    };

    it('should successfully verify company', async () => {
      const mockConnectorResponse = {
        success: true,
        reference: 'kyb-test-app-123-1234567890',
        event: 'verification.accepted',
        business: {
          name: 'Test Company Ltd',
          registration_number: '12345678',
          status: 'active',
        },
      };

      mockConnector.call.mockResolvedValue(mockConnectorResponse);

      const result = await kybService.verifyCompany(mockKYBRequest);

      expect(result).toBeDefined();
      expect(result.applicationId).toBe('test-app-123');
      expect(result.status).toBe('verified');
      expect(result.companyNumber).toBe('12345678');
      expect(mockDataLake.storeKYBRequest).toHaveBeenCalledWith(mockKYBRequest);
      expect(mockConnector.call).toHaveBeenCalled();
    });

    it('should handle missing company number', async () => {
      const invalidRequest = {
        ...mockKYBRequest,
        companyNumber: '',
      };

      await expect(kybService.verifyCompany(invalidRequest as KYBRequest)).rejects.toThrow();
    });

    it('should handle connector service failure', async () => {
      mockConnector.call.mockResolvedValue({
        success: false,
        error: {
          code: 'CONNECTOR_ERROR',
          message: 'Connector service failed',
        },
      });

      await expect(kybService.verifyCompany(mockKYBRequest)).rejects.toThrow();
    });
  });

  describe('getKYBStatus', () => {
    const applicationId = 'test-app-123';
    const userId = 'user-123';

    it('should return cached status from data lake', async () => {
      const mockCachedResponse: KYBResponse = {
        applicationId,
        companyNumber: '12345678',
        status: 'verified',
        timestamp: new Date(),
      };

      mockDataLake.getKYBResponse.mockResolvedValue(mockCachedResponse);

      const result = await kybService.getKYBStatus(applicationId, userId);

      expect(result).toEqual(mockCachedResponse);
      expect(mockDataLake.getKYBResponse).toHaveBeenCalledWith(applicationId);
    });

    it('should fetch status from provider if not cached', async () => {
      mockDataLake.getKYBResponse.mockResolvedValue(null);
      
      const mockRawRequest = {
        body: {
          reference: 'kyb-test-app-123-1234567890',
        },
      };
      mockDataLake.getRawAPIRequest.mockResolvedValue(mockRawRequest);

      const mockConnectorResponse = {
        success: true,
        reference: 'kyb-test-app-123-1234567890',
        event: 'verification.accepted',
        business: {
          name: 'Test Company Ltd',
          registration_number: '12345678',
        },
      };
      mockConnector.call.mockResolvedValue(mockConnectorResponse);

      const result = await kybService.getKYBStatus(applicationId, userId);

      expect(result).toBeDefined();
      expect(result?.status).toBe('verified');
      expect(mockConnector.call).toHaveBeenCalled();
    });
  });
});
