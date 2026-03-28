Example `bitbucket-pipelines.yaml` file:

```
repos:
  # Update the repo URL below with the URL of your new Shared Core Scripts Repository!
  - repo: https://github.com/brucem1976/pre-commit-scripts
    rev: v1.0.7
    hooks:
      - id: prettier
      - id: eslint
      - id: jest
      - id: check-branch-name
      - id: check-commit-msg
      - id: block-dependency-changes
```