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
  // setupFilesAfterEnv: ['./setup-jest.ts'],
  testMatch: [
    "**/publish.test.ts", // Run publish.test.ts first
    "**/*.test.ts", // Then run all other test files
    "**/*.steps.ts", // Finally run step files
  ],
  testTimeout: 600000, // Set timeout to 300 seconds per test
};
export default config;
