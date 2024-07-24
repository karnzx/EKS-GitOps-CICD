# Dummy nodejs

A dummy nodejs application use to demo with CI/CD (Github action, ArgoCD)

functions

- helloworld static web using expressJS
- simple functions and test

on Pull request, or manually run workflow

- Test application
- Build container image
- Scan container image
- Push to AWS ECR
- Deploy (Update) image tag on kubernetes manifest in GitOps workloads/dummy-nodejs
- Do webhooks
