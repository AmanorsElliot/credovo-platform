import { ShuftiProConnector } from '../shufti-pro-connector';
import { ConnectorRequest } from '@credovo/shared-types';

// Mock axios
jest.mock('axios');
const axios = require('axios');

describe('ShuftiProConnector', () => {
  let connector: ShuftiProConnector;

  beforeEach(() => {
    jest.clearAllMocks();
    connector = new ShuftiProConnector();
    
    // Set up environment variables
    process.env.SHUFTI_PRO_CLIENT_ID = 'test-client-id';
    process.env.SHUFTI_PRO_SECRET_KEY = 'test-secret-key';
  });

  describe('handleVerificationRequest', () => {
    it('should create correct KYC request payload', async () => {
      const request: ConnectorRequest = {
        provider: 'shufti-pro',
        endpoint: '/',
        method: 'POST',
        body: {
          reference: 'kyc-test-123',
          callback_url: 'https://example.com/webhook',
          email: 'test@example.com',
          country: 'GB',
          language: 'EN',
          firstName: 'John',
          lastName: 'Doe',
          dateOfBirth: '1990-01-01',
        },
      };

      const mockResponse = {
        success: true,
        reference: 'kyc-test-123',
        event: 'verification.pending',
      };

      axios.post = jest.fn().mockResolvedValue({ data: mockResponse });

      const result = await (connector as any).handleVerificationRequest(request);

      expect(axios.post).toHaveBeenCalled();
      expect(result).toBeDefined();
    });

    it('should include AML screening in request', async () => {
      const request: ConnectorRequest = {
        provider: 'shufti-pro',
        endpoint: '/',
        method: 'POST',
        body: {
          reference: 'kyc-test-123',
          firstName: 'John',
          lastName: 'Doe',
          dateOfBirth: '1990-01-01',
        },
      };

      axios.post = jest.fn().mockResolvedValue({ data: { success: true } });

      await (connector as any).handleVerificationRequest(request);

      const callArgs = axios.post.mock.calls[0];
      const payload = callArgs[1];
      
      expect(payload.risk_assessment).toBeDefined();
      expect(payload.risk_assessment.name.first_name).toBe('John');
    });
  });

  describe('handleKYBRequest', () => {
    it('should create correct KYB request payload', async () => {
      const request: ConnectorRequest = {
        provider: 'shufti-pro',
        endpoint: '/',
        method: 'POST',
        body: {
          reference: 'kyb-test-123',
          callback_url: 'https://example.com/webhook',
          companyName: 'Test Company Ltd',
          companyNumber: '12345678',
          country: 'GB',
        },
      };

      const mockResponse = {
        success: true,
        reference: 'kyb-test-123',
        event: 'verification.accepted',
      };

      axios.post = jest.fn().mockResolvedValue({ data: mockResponse });

      const result = await (connector as any).handleKYBRequest(request);

      expect(axios.post).toHaveBeenCalled();
      const callArgs = axios.post.mock.calls[0];
      const payload = callArgs[1];
      
      expect(payload.kyb).toBeDefined();
      expect(payload.kyb.company_registration_number).toBe('12345678');
    });

    it('should validate company number is present', async () => {
      const request: ConnectorRequest = {
        provider: 'shufti-pro',
        endpoint: '/',
        method: 'POST',
        body: {
          reference: 'kyb-test-123',
          companyName: 'Test Company Ltd',
          // Missing companyNumber
        },
      };

      await expect((connector as any).handleKYBRequest(request)).rejects.toThrow();
    });
  });

  describe('handleStatusRequest', () => {
    it('should create correct status check request', async () => {
      const request: ConnectorRequest = {
        provider: 'shufti-pro',
        endpoint: '/status/kyc-test-123',
        method: 'POST',
        body: {
          reference: 'kyc-test-123',
        },
        retry: true,
      };

      const mockResponse = {
        reference: 'kyc-test-123',
        event: 'verification.accepted',
        verification_result: {
          event: 'verification.accepted',
        },
      };

      axios.post = jest.fn().mockResolvedValue({ data: mockResponse });

      const result = await (connector as any).handleStatusRequest(request);

      expect(axios.post).toHaveBeenCalled();
      expect(result.success).toBe(true);
      expect(result.reference).toBe('kyc-test-123');
    });

    it('should retry on failure', async () => {
      const request: ConnectorRequest = {
        provider: 'shufti-pro',
        endpoint: '/status/kyc-test-123',
        method: 'POST',
        body: {
          reference: 'kyc-test-123',
        },
        retry: true,
      };

      // First call fails, second succeeds
      axios.post = jest.fn()
        .mockRejectedValueOnce(new Error('Network error'))
        .mockResolvedValueOnce({ data: { reference: 'kyc-test-123', event: 'verification.accepted' } });

      // Mock setTimeout to speed up test
      jest.useFakeTimers();
      
      const resultPromise = (connector as any).handleStatusRequest(request);
      
      // Fast-forward through retry delays
      jest.advanceTimersByTime(10000);
      
      const result = await resultPromise;

      expect(axios.post).toHaveBeenCalledTimes(2);
      expect(result.success).toBe(true);
      
      jest.useRealTimers();
    });
  });
});
