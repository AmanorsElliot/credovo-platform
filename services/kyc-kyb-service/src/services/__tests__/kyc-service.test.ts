import { KYCService } from '../kyc-service';
import { DataLakeService } from '../data-lake-service';
import { ConnectorClient } from '../connector-client';
import { KYCRequest, KYCResponse } from '@credovo/shared-types';

// Mock dependencies
jest.mock('../data-lake-service');
jest.mock('../connector-client');
jest.mock('../pubsub-service');

describe('KYCService', () => {
  let kycService: KYCService;
  let mockDataLake: jest.Mocked<DataLakeService>;
  let mockConnector: jest.Mocked<ConnectorClient>;

  beforeEach(() => {
    jest.clearAllMocks();
    
    // Create mocks
    mockDataLake = {
      storeKYCRequest: jest.fn().mockResolvedValue(undefined),
      storeKYCResponse: jest.fn().mockResolvedValue(undefined),
      getKYCResponse: jest.fn(),
      storeRawAPIRequest: jest.fn().mockResolvedValue(undefined),
      storeRawAPIResponse: jest.fn().mockResolvedValue(undefined),
      getRawAPIRequest: jest.fn(),
    } as any;

    mockConnector = {
      call: jest.fn(),
    } as any;

    // Mock the services
    jest.spyOn(DataLakeService.prototype, 'storeKYCRequest').mockImplementation(mockDataLake.storeKYCRequest);
    jest.spyOn(DataLakeService.prototype, 'storeKYCResponse').mockImplementation(mockDataLake.storeKYCResponse);
    jest.spyOn(DataLakeService.prototype, 'getKYCResponse').mockImplementation(mockDataLake.getKYCResponse);
    jest.spyOn(ConnectorClient.prototype, 'call').mockImplementation(mockConnector.call);

    kycService = new KYCService();
  });

  describe('initiateKYC', () => {
    const mockKYCRequest: KYCRequest = {
      applicationId: 'test-app-123',
      userId: 'user-123',
      type: 'individual',
      data: {
        firstName: 'John',
        lastName: 'Doe',
        dateOfBirth: '1990-01-01',
        email: 'john.doe@example.com',
        country: 'GB',
        address: {
          line1: '123 Test Street',
          city: 'London',
          postcode: 'SW1A 1AA',
          country: 'GB',
        },
      },
    };

    it('should successfully initiate KYC verification', async () => {
      const mockConnectorResponse = {
        success: true,
        reference: 'kyc-test-app-123-1234567890',
        event: 'verification.pending',
        verification_result: {
          event: 'verification.pending',
        },
      };

      mockConnector.call.mockResolvedValue(mockConnectorResponse);

      const result = await kycService.initiateKYC(mockKYCRequest);

      expect(result).toBeDefined();
      expect(result.applicationId).toBe('test-app-123');
      expect(result.status).toBe('pending');
      expect(result.provider).toBe('shufti-pro');
      expect(mockDataLake.storeKYCRequest).toHaveBeenCalledWith(mockKYCRequest);
      expect(mockConnector.call).toHaveBeenCalled();
    });

    it('should handle connector service failure', async () => {
      mockConnector.call.mockResolvedValue({
        success: false,
        error: {
          code: 'CONNECTOR_ERROR',
          message: 'Connector service failed',
        },
      });

      await expect(kycService.initiateKYC(mockKYCRequest)).rejects.toThrow();
    });

    it('should map approved status correctly', async () => {
      const mockConnectorResponse = {
        success: true,
        reference: 'kyc-test-app-123-1234567890',
        event: 'verification.accepted',
        verification_result: {
          event: 'verification.accepted',
        },
      };

      mockConnector.call.mockResolvedValue(mockConnectorResponse);

      const result = await kycService.initiateKYC(mockKYCRequest);

      expect(result.status).toBe('approved');
    });

    it('should map rejected status correctly', async () => {
      const mockConnectorResponse = {
        success: true,
        reference: 'kyc-test-app-123-1234567890',
        event: 'verification.declined',
        verification_result: {
          event: 'verification.declined',
        },
      };

      mockConnector.call.mockResolvedValue(mockConnectorResponse);

      const result = await kycService.initiateKYC(mockKYCRequest);

      expect(result.status).toBe('rejected');
    });
  });

  describe('getKYCStatus', () => {
    const applicationId = 'test-app-123';
    const userId = 'user-123';

    it('should return cached status from data lake', async () => {
      const mockCachedResponse: KYCResponse = {
        applicationId,
        status: 'approved',
        provider: 'shufti-pro',
        result: {
          score: 100,
          checks: [],
          metadata: {},
        },
        timestamp: new Date(),
      };

      mockDataLake.getKYCResponse.mockResolvedValue(mockCachedResponse);

      const result = await kycService.getKYCStatus(applicationId, userId);

      expect(result).toEqual(mockCachedResponse);
      expect(mockDataLake.getKYCResponse).toHaveBeenCalledWith(applicationId);
      expect(mockConnector.call).not.toHaveBeenCalled();
    });

    it('should fetch status from provider if not cached', async () => {
      mockDataLake.getKYCResponse.mockResolvedValue(null);
      
      const mockRawRequest = {
        body: {
          reference: 'kyc-test-app-123-1234567890',
        },
      };
      mockDataLake.getRawAPIRequest.mockResolvedValue(mockRawRequest);

      const mockConnectorResponse = {
        success: true,
        reference: 'kyc-test-app-123-1234567890',
        event: 'verification.accepted',
        verification_result: {
          event: 'verification.accepted',
        },
      };
      mockConnector.call.mockResolvedValue(mockConnectorResponse);

      const result = await kycService.getKYCStatus(applicationId, userId);

      expect(result).toBeDefined();
      expect(result?.status).toBe('approved');
      expect(mockConnector.call).toHaveBeenCalled();
    });

    it('should return null if application not found', async () => {
      mockDataLake.getKYCResponse.mockResolvedValue(null);
      mockDataLake.getRawAPIRequest.mockResolvedValue(null);
      mockConnector.call.mockResolvedValue({
        success: false,
      });

      const result = await kycService.getKYCStatus(applicationId, userId);

      expect(result).toBeNull();
    });
  });
});
