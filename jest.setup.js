// Jest setup file for global test configuration

// Mock environment variables
process.env.NODE_ENV = 'test';
process.env.PORT = '8080';
process.env.SERVICE_JWT_SECRET = 'test-secret-key-for-jwt-signing';
process.env.SHUFTI_PRO_CLIENT_ID = 'test-client-id';
process.env.SHUFTI_PRO_SECRET_KEY = 'test-secret-key';
process.env.DATA_LAKE_BUCKET = 'test-data-lake-bucket';
process.env.KYC_SERVICE_URL = 'http://localhost:8081';
process.env.CONNECTOR_SERVICE_URL = 'http://localhost:8082';
process.env.ORCHESTRATION_SERVICE_URL = 'http://localhost:8080';

// Increase timeout for integration tests
jest.setTimeout(30000);

// Suppress console logs during tests (optional - uncomment if needed)
// global.console = {
//   ...console,
//   log: jest.fn(),
//   debug: jest.fn(),
//   info: jest.fn(),
//   warn: jest.fn(),
//   error: jest.fn(),
// };
