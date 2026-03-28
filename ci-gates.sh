#!/bin/bash
set -e

echo "==== 0. Enforcing JIRA PR Compliance ===="
./pr-compliance.sh

echo "==== 1. Installing Clean Dependencies ===="
yarn install --frozen-lockfile

echo "==== 2. Validating TypeScript constraints ===="
yarn type-check

echo "==== 3. Enforcing Global Code Style (ESLint) ===="
yarn lint

echo "==== 4. Running Global Test Suites (Jest) ===="
yarn test

echo "==== 5. Auditing Security Vulnerabilities ===="
yarn audit --level critical

echo "✅ All CI Gates Passed Successfully!"
