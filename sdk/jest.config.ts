import type { Config } from "@jest/types";

// Sync object
const config: Config.InitialOptions = {
  verbose: true,
  preset: "ts-jest/presets/default-esm",
  moduleNameMapper: {
    "^(\\.{1,2}/.*)\\.js$": "$1",
  },
  transform: {
    "^.+\\.(ts|tsx)?$": [
      "ts-jest",
      {
        useESM: true,
        diagnostics: { ignoreCodes: ["TS151001"] },
      },
    ],
  },
  setupFilesAfterEnv: ['<rootDir>/tests/setup.ts'],
  testMatch: [
    "<rootDir>/tests/**/*.test.ts", // Then run all other test files
  ],
  testTimeout: 600000, // Set timeout to 300 seconds per test
};
export default config;
