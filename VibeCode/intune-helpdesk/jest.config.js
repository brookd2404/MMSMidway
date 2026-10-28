module.exports = {
  testEnvironment: 'jsdom',
  testMatch: ['<rootDir>/tests/**/*.test.js'],
  transform: {
    '^.+\\.tsx?$': '<rootDir>/tests/typescript-transformer.js',
  },
  clearMocks: true,
};
