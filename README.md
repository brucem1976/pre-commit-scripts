# Pre-Commit Scripts

A collection of reusable pre-commit hooks and CI scripts for JIRA-compliant development workflows.

## Example `bitbucket-pipelines.yaml` file (using pre-commit hooks):
```
image: node:20

pipelines:
  pull-requests:
    '**': # Runs on ALL pull requests regardless of branch
      - step:
          name: PR Quality Gates
          caches:
            - node
          script:
            - pip install pre-commit
            # Phase 1: Install dependencies first (must complete before other checks)
            - pre-commit run install-dependencies --hook-stage=manual
            # Phase 2: PR compliance checks (run sequentially after dependencies)
            - pre-commit run pr-compliance check-pr-approvers --hook-stage=manual
            # Phase 3: Quality checks in parallel (4x speedup on multi-core systems)
            - pre-commit run type-check lint test audit --hook-stage=manual --parallel
```

## Example `.pre-commit-config.yaml` file (React/Node):
```
repos:
  # Update the repo URL below with the URL of your new Shared Core Scripts Repository!
  - repo: https://github.com/brucem1976/pre-commit-scripts
    rev: v1.0.11
    hooks:
      # Commit-time hooks (run on `git commit`)
      - id: check-branch-name
      - id: check-commit-msg
      - id: block-dependency-changes
      - id: prettier
      - id: eslint
      - id: jest
      - id: patch-coverage
          args: ['--threshold=80']
          verbose: true
      
      # CI/PR-time hooks (run in three phases for optimal parallelism)
      # Phase 1: Dependencies (runs first, sequentially)
      - id: install-dependencies
      
      # Phase 2: PR compliance (run sequentially after dependencies)
      - id: pr-compliance
      - id: check-pr-approvers
      
      # Phase 3: Quality checks (run in parallel after Phase 1 & 2)
      - id: type-check
      - id: lint
      - id: test
      - id: audit
```

## Example postinstall script for `package.json`
```
"postinstall": "pre-commit install --hook-type pre-commit --hook-type commit-msg --hook-type post-merge"
```

## Example `.pre-commit-config.yaml` file (PHP):
```
repos:
  # Update the repo URL below with the URL of your new Shared Core Scripts Repository!
  - repo: https://github.com/brucem1976/pre-commit-scripts
    rev: v1.0.11
    hooks:
      # Commit-time hooks (run on `git commit`)
      - id: check-branch-name
      - id: check-commit-msg
      - id: patch-coverage
        args: ['--threshold=80']
        verbose: true
      
      # CI/PR-time hooks
      - id: pr-compliance
      - id: check-pr-approvers
```