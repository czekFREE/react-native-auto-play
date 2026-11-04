module.exports = {
  rootDir: '..',
  roots: ['<rootDir>/tests'],
  testEnvironment: 'node',
  globals: { __DEV__: true },
  testMatch: ['**/__tests__/**/*.ios.test.ts'],
  transform: {
    '^.+\\.(js|ts|tsx)$': [
      'babel-jest',
      { babelrc: false, configFile: false, presets: ['module:@react-native/babel-preset'] },
    ],
  },
};
