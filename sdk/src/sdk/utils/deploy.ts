import {deploy as baseDeploy} from '../../easysui'
import fs from "fs";
import path from "path";
import {Config} from "./config";
import {deployPas} from "../deploy_pas";

export async function deploy() {
    const pasConfig = await deployPas() // TODO: Delete when pas is deployed in MVR
    const result = await baseDeploy(Config)

    // Patch PAS fields into the env file (baseDeploy already wrote securitize fields)
    const env = process.env.NETWORK || 'localnet'
    const envFile = path.join(process.cwd(), `.env.${env}`)
    let content = fs.existsSync(envFile) ? fs.readFileSync(envFile, 'utf8') : ''
    for (const [key, value] of Object.entries(pasConfig)) {
        const escapedKey = key.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
        const regex = new RegExp(`^${escapedKey}=.*$`, 'm')
        if (regex.test(content)) {
            content = content.replace(regex, `${key}=${value}`)
        } else {
            content += `${content.endsWith('\n') || content === '' ? '' : '\n'}${key}=${value}\n`
        }
    }
    fs.writeFileSync(envFile, content, 'utf8')

    return result
}