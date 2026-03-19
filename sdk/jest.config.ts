import type { Config } from "@jest/types";

// Sync object
const config: Config.InitialOptions = {
  verbose: true,
  preset: "ts-jest/presets/default-esm",
  moduleNameMapper: {
    "^(\\.{1,2}/.*)\\.js$": "$1",
    "^@mysten/pas$": "<rootDir>/../pas/sdk/pas/dist/index.cjs",
    "^@mysten/pas/(.*)$": "<rootDir>/../pas/sdk/pas/dist/$1.cjs",
    "^@mysten/sui/(.*)$": "<rootDir>/node_modules/@mysten/sui/dist/cjs/$1/index.js",
  },
  transformIgnorePatterns: [
    "/node_modules/(?!(@mysten/pas|@mysten/sui|@mysten/bcs))"
  ],
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
