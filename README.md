# EKS-GitOps-CICD

A repository dedicated to deploying and managing applications on AWS EKS using GitOps principles. Includes Terraform infrastructure code, ArgoCD configurations, and CI/CD pipelines.

Terraform 1.8.1 on AWS Cloud provider.

To get Kubeconfig file run

```shell
aws eks update-kubeconfig --name "ProjectU" --dry-run > .kubeconfig
```
