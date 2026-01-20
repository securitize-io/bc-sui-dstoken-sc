import {PublishSingleton} from "../src";
import {deployPas} from "../src/sdk/deploy_pas";


export default async function () {
    PublishSingleton.cleanPubFile()
    await deployPas(); // TODO: Delete when pas is deployed in MVR
}
