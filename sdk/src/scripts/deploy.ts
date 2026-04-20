import { deploy } from '../sdk/utils/deploy'
import { ADMIN_KEYPAIR } from '../easysui'

const VALID_TESTNET_ENVS = ['testnet_alpha', 'testnet_beta', 'testnet_gamma'] as const

function parseEnvArg(): string | undefined {
    const args = process.argv.slice(2)
    const idx = args.indexOf('--env')
    if (idx === -1) return undefined

    const value = args[idx + 1]
    if (!value) {
        console.error('Error: --env flag requires a value')
        console.error(`Usage: pnpm deploy_testnet --env <${VALID_TESTNET_ENVS.join('|')}>`)
        process.exit(1)
    }
    if (!VALID_TESTNET_ENVS.includes(value as (typeof VALID_TESTNET_ENVS)[number])) {
        console.error(`Error: Invalid environment "${value}"`)
        console.error(`Valid environments: ${VALID_TESTNET_ENVS.join(', ')}`)
        process.exit(1)
    }
    return value
}

// When deploying securitize contracts this allows when no argument is passed to default to the standard testnet environment,
// but also allows specifying a testnet environment when needed (e.g. for testing on testnet_alpha)
const envArg = parseEnvArg()
if (envArg) {
    process.env.SECURITIZE_TESTNET_ENV = envArg
    console.log(`Deploying to Move environment: ${envArg}`)
}

deploy(ADMIN_KEYPAIR!)
    .then(console.log)
    .catch((err) => {
        console.error('Deployment failed:', err.message)
        process.exit(1)
    })
