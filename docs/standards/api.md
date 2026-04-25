# API Standards

**Applies always.**

## Standards
- Use standard HTTP verbs: GET, POST, PUT, DELETE
- Resource paths MUST be plural nouns (e.g., `/devices`, `/devices/{id}`)
- Return business data directly on success; MUST NOT wrap in a common response envelope
- List responses: `{ "items": [], "total": N }`
- Error format: `{ "code": <int>, "message": "<string>", "data": null }`
- ALL exceptions MUST be handled by a global `@RestControllerAdvice` (canonical home for this rule)
- Controllers MUST NOT catch exceptions directly (canonical home for this rule)
- Use `jakarta.validation` annotations: `@NotNull`, `@NotBlank`, `@Size`, `@Min`, `@Max`
- Validation errors MUST return the standard error response format

See [`exception.md`](exception.md) for the exception taxonomy and `ErrorCode` enum used inside the global handler.

## Checks
- [ ] No controller method wraps its return value in a response envelope
- [ ] List-returning endpoints return `{ "items": [...], "total": N }`
- [ ] One class annotated `@RestControllerAdvice` exists and handles all exceptions
- [ ] No try/catch blocks in any Controller class
- [ ] All request body parameters use `jakarta.validation` annotations
- [ ] `@Validated` present on all controller request body parameters
