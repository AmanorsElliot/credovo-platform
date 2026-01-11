module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/src'],
  testMatch: ['**/__tests__/**/*.ts', '**/?(*.)+(spec|test).ts'],
  transform: {
    '^.+\\.ts$': 'ts-jest',
  },
  moduleNameMapper: {
    '^@credovo/shared-types$': '<rootDir>/../../shared/types/src',
    '^@credovo/shared-auth$': '<rootDir>/../../shared/auth/src',
    '^@credovo/shared-utils/(.*)$': '<rootDir>/../../shared/utils/src/$1',
  },
  collectCoverageFrom: [
    'src/**/*.ts',
    '!src/**/*.d.ts',
    '!src/**/__tests__/**',
  ],
  setupFilesAfterEnv: ['<rootDir>/../../jest.setup.js'],
};
