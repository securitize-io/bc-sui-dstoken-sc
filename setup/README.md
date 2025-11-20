# Steps to execute the integration tests

## First setup the sui local environment and test address
1. Run a localnet with 
```
sui start --with-faucet --force-regenesis
```
2. Switch to the localnet environment with 
```
sui client switch --env localnet
```
**If localnet is not defined, create it and then switch to localnet.**
```
sui client new-env --alias localnet --rpc http://127.0.0.1:9000
sui client switch --env localnet
```
3. Import an address that is created for testing purposes and is used within the contracts with 
```
sui keytool import --alias admin suiprivkey1qpq4r2l7ed3n5vrtt56qah5nj576hj6ppjexztq38x43n03cxjmhqp7rz6q ed25519
```
4. Switch to that address and get some sui tokens to publish the contracts and run the transactions 
```
sui client switch --address admin
sui client faucet
```

## Lastly create the env file and run the integration tests
1. Create the initial .env file with required variables
```
    touch .env
    echo "NETWORK=localnet" >> .env
    echo "ADMIN_PRIVATE_KEY=suiprivkey1qpq4r2l7ed3n5vrtt56qah5nj576hj6ppjexztq38x43n03cxjmhqp7rz6q" >> .env
    echo "FULLNODE_URL=http://127.0.0.1:9000" >> .env
    echo "DENY_LIST_ID=0x403" >> .env
```
2. Install the dependencies with 
```
pnpm install
```
3. Run publish test first 
```
pnpm test publish.test.ts
```
You will see that in the .env file some addresses were added which correspond to the shared objects created on publish.
Also you will notice the ./src/gen folder which contains all the generated interfaces.
4. Then run all other tests 
```
pnpm test "**/*.test.ts" -- --testPathIgnorePatterns=publish.test.ts
```
