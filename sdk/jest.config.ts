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
    // Transform ESM-only @mysten/sui so Jest can load it
    "node_modules/@mysten/sui/.+\\.mjs$": [
      "ts-jest",
      {
        useESM: true,
        diagnostics: false,
      },
    ],
  },
  // Allow @mysten/sui to be transformed (it's ESM-only in v2)
  transformIgnorePatterns: [
    "node_modules/(?!@mysten/sui)",
  ],
  setupFilesAfterEnv: ['<rootDir>/tests/setup.ts'],
  testMatch: [
    "<rootDir>/tests/**/*.test.ts", // Then run all other test files
  ],
  testTimeout: 600000, // Set timeout to 300 seconds per test
};
export default config;
