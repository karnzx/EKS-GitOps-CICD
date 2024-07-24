# GitOps

Use to provide ArgoCD application to continuous delivery for kubernetes in declarative way.

these are root app which deployed by argocd-app from Helm (deployed by Terraform)

- addons (cluster addons)
- workload (cluster workloads)

## Guestbook Page

![guestbook page](../images/guestbook_page.png)

## Inflate scale

leverage karpenter to scale node when pod increase

replica 3

![inflate replica 3](../images/inflate_replica_3.png)

replica 15

![inflate replica 15](../images/inflate_replica_15.png)

replica 30

![inflate replica 30](../images/inflate_replica_30.png)
