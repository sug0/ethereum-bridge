check:
	VIAIR=true npx hardhat check

lint:
	npx solhint 'contracts/**/*.sol'
	npx prettier --check 'contracts/**/*.sol'

lint-fix:
	npx solhint 'contracts/**/*.sol' --fix
	npx prettier --write 'contracts/**/*.sol'

build:
	npx hardhat clean
	RUNS=10000 VIAIR=true npx hardhat compile --force

build-size:
	npx hardhat clean
	RUNS=10000 VIAIR=true npx hardhat compile --force
	npx hardhat size-contracts

clean:
	npx hardhat clean

benchmark:
	npx hardhat run --network localhost benchmarks/index.js

node:
	npx hardhat node

node-deploy:
	npx hardhat run --network localhost scripts/deploy.js

test:
	RUNS=10 VIAIR=true npx hardhat --network localhost test
	
test-gas:
	RUNS=10000 VIAIR=true REPORT_GAS=true npx hardhat test

test-coverage:
	VIAIR=false REPORT_GAS=false npx hardhat coverage

deps:
	npm install

ci:
	npm ci

.PHONY: check build clean test test-gas test-coverage lint lint-fix deps build-size check ci node benchmark node-deploy
