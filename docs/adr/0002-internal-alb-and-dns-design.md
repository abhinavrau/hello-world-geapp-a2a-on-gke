# Multi-Zone Standalone NEG Binding, DNS Zone Integration, and State Migration

We decided on dynamic multi-zone NEG backend attachment, dual-mode Cloud DNS handling, and in-place Terraform state migration via `moved {}` blocks.

## Context
In GKE Autopilot, pods are distributed dynamically across all zones in the target region. The Internal Application Load Balancer needs to reliably route to Standalone NEGs across all active zones. Additionally, existing deployments must be upgradeable without downtime or cluster recreations.

## Decision
1. **Dynamic Multi-Zone NEGs**: The `internal-lb` module dynamically iterates over all compute zones in the GKE region to attach the Standalone NEG for each zone to the regional backend service.
2. **Flexible DNS Zone Resolution**: The `dns` module supports an `enable_create_dns_zone` flag, allowing it to either provision a new Cloud DNS zone or bind authorization and A records into an existing managed zone.
3. **Seamless State Migration**: Provide `moved.tf` in `deployment/terraform/single-project/` mapping all legacy resource addresses to their new modular locations, preventing resource destruction on `terraform apply`.
4. **Permissive Initial Gateway Authz**: Default IAP Authorization Extension to `DRY_RUN` with an `iap_enforcement_mode` variable for zero-friction initial rollout.
