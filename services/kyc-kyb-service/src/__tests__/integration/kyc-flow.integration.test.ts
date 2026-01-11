/**
 * Integration tests for KYC flow
 * These tests verify the complete KYC verification flow end-to-end
 */

import { KYCService } from '../../services/kyc-service';
import { DataLakeService } from '../../services/data-lake-service';
import { ConnectorClient } from '../../services/connector-client';
import { KYCRequest } from '@credovo/shared-types';

describe('KYC Flow Integration Tests', () => {
  let kycService: KYCService;
  
  // These are integration tests that may require actual services
  // Set SKIP_INTEGRATION_TESTS=true to skip
  const skipIntegration = process.env.SKIP_INTEGRATION_TESTS === 'true';

  beforeAll(() => {
    if (skipIntegration) {
      console.log('Skipping integration tests (SKIP_INTEGRATION_TESTS=true)');
    }
  });

  beforeEach(() => {
    kycService = new KYCService();
  });

  describe('Complete KYC Verification Flow', () => {
    it.skip('should complete full KYC flow: initiate -> status check -> webhook', async () => {
      // This test would require:
      // 1. Real Shufti Pro sandbox credentials
      // 2. Real data lake bucket
      // 3. Mock webhook endpoint
      
      const request: KYCRequest = {
        applicationId: `test-kyc-${Date.now()}`,
        userId: 'test-user',
        type: 'individual',
        data: {
          firstName: 'John',
          lastName: 'Doe',
          email: 'john.doe@example.com',
          country: 'GB',
          dateOfBirth: '1990-01-01',
          address: {
            line1: '123 Test Street',
            city: 'London',
            postcode: 'SW1A 1AA',
            country: 'GB',
          },
        },
      };

      // Step 1: Initiate KYC
      const initiationResult = await kycService.initiateKYC(request);
      expect(initiationResult).toBeDefined();
      expect(initiationResult.applicationId).toBe(request.applicationId);

      // Step 2: Check status (should be pending initially)
      const statusResult = await kycService.getKYCStatus(request.applicationId, request.userId);
      expect(statusResult).toBeDefined();
      
      // Step 3: Simulate webhook callback (would be done by Shufti Pro)
      // This would update the status to approved/rejected
    });
  });

  describe('Status Check Flow', () => {
    it('should retrieve status from cache when available', async () => {
      // This test verifies caching behavior
      const applicationId = 'test-app-cache';
      const userId = 'test-user';

      // Mock cached response
      const mockCachedResponse = {
        applicationId,
        status: 'approved' as const,
        provider: 'shufti-pro',
        result: {
          score: 100,
          checks: [],
          metadata: {},
        },
        timestamp: new Date(),
      };

      jest.spyOn(DataLakeService.prototype, 'getKYCResponse')
        .mockResolvedValue(mockCachedResponse);

      const result = await kycService.getKYCStatus(applicationId, userId);

      expect(result).toEqual(mockCachedResponse);
      // Should not call connector if cached
      expect(ConnectorClient.prototype.call).not.toHaveBeenCalled();
    });
  });
});
