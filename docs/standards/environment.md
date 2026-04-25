# Environment Variable Standards

**Applies always.**

## Constraints

- MUST NOT hardcode host, port, username, or password anywhere in code
- All environment-dependent config (MySQL, Redis, MQ, service discovery) MUST come from environment variables

## Detection Priority

Check project root in this order:

1. `.env.dev.*` → use if found
2. `.env.test.*` → use if found
3. `.env.inte.*` → use if found
4. None found → MUST ask the user to supply config; MUST NOT assume defaults

This priority is referenced by [`spring-cloud.md`](spring-cloud.md), [`database.md`](database.md), and [`redis.md`](redis.md) for component server addresses.

## Checks
- [ ] No plaintext host / port / username / password in any `application*.yml`
- [ ] No plaintext host / port / username / password in any `*.java` source
- [ ] `.env.*` files listed in `.gitignore`
- [ ] No `.env.*` files committed to git
