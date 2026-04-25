# Exception Handling Standards

**Applies always.**

## Exception Classification

Exception encapsulation is divided into the following four types; use as appropriate during code generation:

| Exception Type         | Description |
|------------------------|-------------|
| `AppBizException`      | Business exception: validation failure, business flow interruption |
| `AppRtException`       | Runtime exception: unknown system errors, NPE, illegal arguments |
| `PermissionException`  | Permission exception: permission check failure, access denied |
| `SQLException`         | SQL execution exception: catches unhandled database errors not intercepted by `AppBizException` |

The single global handler that maps these to HTTP responses lives in the class annotated `@RestControllerAdvice`. See [`api.md`](api.md) for the rule that this is the *only* place exceptions are caught.

## Global SQL Exception Handling

`SQLException` must be handled separately in the global exception handler:

```java
@ExceptionHandler(SQLException.class)
public Result<?> handleSqlException(SQLException e) {
    log.error("SQL execution error", e);
    return Result.fail(ErrorCode.DB_ERROR.getCode(), ErrorCode.DB_ERROR.getMessage(), null);
}
```

- This handler is at the outermost layer, catching all database exceptions not intercepted by `AppBizException`
- Full stack trace must be logged for troubleshooting

## Error Codes

All error codes MUST be defined in a single `ErrorCode` class/enum.

## Checks
- [ ] Every Service method that signals business failure throws `AppBizException`
- [ ] All error codes defined in a single `ErrorCode` class/enum
- [ ] Global handler has separate `@ExceptionHandler` for each of `AppBizException`, `AppRtException`, `PermissionException`, `SQLException`
- [ ] (cross-check [`api.md`](api.md)) No try/catch in any Controller class
