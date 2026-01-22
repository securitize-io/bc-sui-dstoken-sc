import {deploy as baseDeploy} from '../../easysui'
import {Config} from "./config";
import {deployPas} from "../deploy_pas";

export async function deploy() {
    await deployPas() // TODO: Delete when pas is deployed in MVR
    return baseDeploy(Config)
}