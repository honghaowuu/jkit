# Redis Standards

**Applies when:** `redis.enabled: true` in `project-info.yaml`.

## Standards

### Key Naming

A tenant is identified by the combination of `character_code` + `key_id` — see [`tenant.md`](tenant.md) for the canonical identity scheme.

| Scope  | Key Format                                       | Example                       |
|--------|--------------------------------------------------|-------------------------------|
| Global | `{entity}`                                       | `config:all`                  |
| Tenant | `{character_code}:{key_id}:{entity}`             | `CORP_A:K001:device:all`      |
| User   | `{character_code}:{key_id}:{user_id}:{entity}`   | `CORP_A:K001:U007:session`    |

### Expiry
- ALL cached objects MUST have an expiry (default: 24 hours)
- Large-data caches: MUST add a risk comment in code noting the data size concern

## Checks
- [ ] Every Redis write sets a TTL
- [ ] No Redis key is a bare entity name without scope prefix (unless explicitly Global scope)
- [ ] Tenant-scoped keys include both `character_code` and `key_id`
- [ ] User-scoped keys include `character_code`, `key_id`, and `user_id`
- [ ] Large-data caches have a risk comment
