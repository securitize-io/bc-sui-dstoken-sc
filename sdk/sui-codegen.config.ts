import type { SuiCodegenConfig } from '@mysten/codegen';

const config: SuiCodegenConfig = {
	output: './src/generated',
	generateSummaries: true,
	prune: true,
	packages: [
		{
			package: '@securitize/securitize',
			path: '../move/securitize',
		},
	],
};

export default config;
