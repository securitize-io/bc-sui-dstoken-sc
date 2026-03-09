import {createTestToken} from "../../tests/test_utils";

const VALID_TESTNET_ENVS = ['testnet_alpha', 'testnet_beta', 'testnet_gamma'] as const;

function parseEnvArg(): string | undefined {
    const args = process.argv.slice(2);
    const idx = args.indexOf('--env');
    if (idx === -1) return undefined;

    const value = args[idx + 1];
    if (!value) {
        console.error('Error: --env flag requires a value');
        console.error(`Usage: pnpm deploy_test_token --env <${VALID_TESTNET_ENVS.join('|')}>`);
        process.exit(1);
    }
    if (!VALID_TESTNET_ENVS.includes(value as typeof VALID_TESTNET_ENVS[number])) {
        console.error(`Error: Invalid environment "${value}"`);
        console.error(`Valid environments: ${VALID_TESTNET_ENVS.join(', ')}`);
        process.exit(1);
    }
    return value;
}

const envArg = parseEnvArg();
if (envArg) {
    // Override NETWORK to testnet when --env is provided
    process.env.NETWORK = 'testnet';
    process.env.SECURITIZE_TESTNET_ENV = envArg;
    console.log(`Deploying test token to Move environment: ${envArg}`);
}

export async function deployToken() {
    const tokenId = await createTestToken()
    return `Token deployed with tokenAddress: ${tokenId}`
}

deployToken().then(console.log).catch(console.error)