import {deploy as baseDeploy} from '../../easysui'
import {Config} from "./config";

export async function deploy() {
    return await baseDeploy(Config)
}