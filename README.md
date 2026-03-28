Example `bitbucket-pipelines.yaml` file (using pre-commit hooks):
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
            - pre-commit run --all-files --hook-stage=manual
```

Example `.pre-commit-config.yaml` file:
```
repos:
  # Update the repo URL below with the URL of your new Shared Core Scripts Repository!
  - repo: https://github.com/brucem1976/pre-commit-scripts
    rev: v1.0.7
    hooks:
      # Commit-time hooks (run on `git commit`)
      - id: prettier
      - id: eslint
      - id: jest
      - id: check-branch-name
      - id: check-commit-msg
      - id: block-dependency-changes
      
      # CI/PR-time hooks (run with `pre-commit run --hook-stage=manual`)
      - id: pr-compliance
      - id: check-pr-approvers
      - id: install-dependencies
      - id: type-check
      - id: lint
      - id: test
      - id: audit
```