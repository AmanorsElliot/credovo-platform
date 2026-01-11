import request from 'supertest';
import express from 'express';
import { ApplicationRouter } from '../application';
import { validateBackendJwt } from '@credovo/shared-auth';

// Mock dependencies
jest.mock('@credovo/shared-auth');
jest.mock('axios');

const axios = require('axios');

describe('Application Routes', () => {
  let app: express.Application;

  beforeEach(() => {
    jest.clearAllMocks();
    app = express();
    app.use(express.json());
    
    // Mock auth middleware to pass through
    (validateBackendJwt as jest.Mock).mockImplementation((req, res, next) => {
      (req as any).userId = 'test-user-123';
      next();
    });

    app.use('/api/v1/applications', validateBackendJwt, ApplicationRouter);
  });

  describe('POST /api/v1/applications/:applicationId/kyc/initiate', () => {
    it('should initiate KYC verification', async () => {
      const mockKYCResponse = {
        applicationId: 'test-app-123',
        status: 'pending',
        provider: 'shufti-pro',
      };

      axios.post = jest.fn().mockResolvedValue({ data: mockKYCResponse });

      const response = await request(app)
        .post('/api/v1/applications/test-app-123/kyc/initiate')
        .send({
          type: 'individual',
          data: {
            firstName: 'John',
            lastName: 'Doe',
            email: 'john.doe@example.com',
            country: 'GB',
          },
        })
        .expect(200);

      expect(response.body).toMatchObject({
        applicationId: 'test-app-123',
        status: 'pending',
      });
      expect(axios.post).toHaveBeenCalled();
    });

    it('should return 400 for missing required fields', async () => {
      const response = await request(app)
        .post('/api/v1/applications/test-app-123/kyc/initiate')
        .send({
          type: 'individual',
          // Missing data field
        })
        .expect(400);

      expect(response.body).toHaveProperty('error');
    });
  });

  describe('GET /api/v1/applications/:applicationId/kyc/status', () => {
    it('should return KYC status', async () => {
      const mockStatusResponse = {
        applicationId: 'test-app-123',
        status: 'approved',
        provider: 'shufti-pro',
      };

      axios.get = jest.fn().mockResolvedValue({ data: mockStatusResponse });

      const response = await request(app)
        .get('/api/v1/applications/test-app-123/kyc/status')
        .expect(200);

      expect(response.body).toMatchObject({
        applicationId: 'test-app-123',
        status: 'approved',
      });
    });

    it('should return 404 for non-existent application', async () => {
      axios.get = jest.fn().mockRejectedValue({
        response: { status: 404 },
      });

      await request(app)
        .get('/api/v1/applications/non-existent/kyc/status')
        .expect(404);
    });
  });

  describe('POST /api/v1/applications/:applicationId/kyb/verify', () => {
    it('should verify KYB', async () => {
      const mockKYBResponse = {
        applicationId: 'test-app-123',
        companyNumber: '12345678',
        status: 'verified',
      };

      axios.post = jest.fn().mockResolvedValue({ data: mockKYBResponse });

      const response = await request(app)
        .post('/api/v1/applications/test-app-123/kyb/verify')
        .send({
          companyNumber: '12345678',
          companyName: 'Test Company Ltd',
          country: 'GB',
        })
        .expect(200);

      expect(response.body).toMatchObject({
        applicationId: 'test-app-123',
        status: 'verified',
      });
    });
  });
});
