module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/src'],
  testMatch: ['**/__tests__/**/*.ts', '**/?(*.)+(spec|test).ts'],
  transform: {
    '^.+\\.ts$': 'ts-jest',
  },
  moduleNameMapper: {
    '^@credovo/shared-types$': '<rootDir>/../../shared/types/index.ts',
    '^@credovo/shared-auth$': '<rootDir>/../../shared/auth/index.ts',
    '^@credovo/shared-utils/(.*)$': '<rootDir>/../../shared/utils/$1.ts',
  },
  collectCoverageFrom: [
    'src/**/*.ts',
    '!src/**/*.d.ts',
    '!src/**/__tests__/**',
  ],
  setupFilesAfterEnv: ['<rootDir>/../../jest.setup.js'],
};
