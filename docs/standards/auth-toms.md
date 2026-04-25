# TOMS Authorization Standards

**Applies when:** `auth.toms.enabled: true` in `project-info.yaml`.

The Maven dependency version comes from `project-info.yaml > auth.toms.api-version`. Tenant identifiers (`character_code`, `key_id`, `CharacterEnum`) follow the canonical scheme defined in [`tenant.md`](tenant.md).

---

## 1. Maven Dependency

Add the following dependency to `pom.xml` before generating any auth-related code. Set `<authorization-api-version>` in `<properties>` to the value from `project-info.yaml > auth.toms.api-version`.

```xml
<dependency>
    <groupId>com.newland.modules</groupId>
    <artifactId>authorization-api</artifactId>
    <version>${authorization-api-version}</version>
</dependency>
```

---

## 2. PlatformWebAuthInterceptor — Registration

Register `com.newland.modules.authorizationapi.PlatformWebAuthInterceptor` as a Spring MVC interceptor. This interceptor automatically validates `@Permission` annotations on every incoming request. Register `UserContextInterceptor` (defined in §3) immediately after it, so user info is available to handlers.

```java
@Configuration
public class WebMvcConfig implements WebMvcConfigurer {

    private final StringRedisTemplate redisTemplate;

    public WebMvcConfig(StringRedisTemplate redisTemplate) {
        this.redisTemplate = redisTemplate;
    }

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(new PlatformWebAuthInterceptor())
                .addPathPatterns("/**");
        registry.addInterceptor(new UserContextInterceptor(redisTemplate))
                .addPathPatterns("/**");
    }
}
```

> Do NOT add `excludePathPatterns` unless the API explicitly requires public access (e.g., health check).

---

## 3. UserContextInterceptor — User Info Extraction

Implement an interceptor that captures user info from `web-token` (request header or cookie), looks it up in Redis, deserializes to `com.newland.modules.authorizationapi.UserInfo`, and stores it in `UserContext`.

```java
@Component
public class UserContextInterceptor implements HandlerInterceptor {

    private final StringRedisTemplate redisTemplate;

    public UserContextInterceptor(StringRedisTemplate redisTemplate) {
        this.redisTemplate = redisTemplate;
    }

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
        String token = request.getHeader("web-token");
        if (token == null || token.isBlank()) {
            token = getCookieValue(request, "web-token");
        }
        if (token == null || token.isBlank()) {
            throw new AppBizException(ErrorCode.UNAUTHORIZED);
        }
        String json = redisTemplate.opsForValue().get(token);
        if (json == null || json.isBlank()) {
            throw new AppBizException(ErrorCode.UNAUTHORIZED);
        }
        try {
            UserInfo userInfo = JsonUtils.parseObject(json, UserInfo.class);
            UserContext.set(userInfo);
        } catch (Exception e) {
            throw new AppBizException(ErrorCode.UNAUTHORIZED);
        }
        return true;
    }

    @Override
    public void afterCompletion(HttpServletRequest request, HttpServletResponse response,
                                Object handler, Exception ex) {
        UserContext.clear();
    }

    private String getCookieValue(HttpServletRequest request, String name) {
        if (request.getCookies() == null) return null;
        for (Cookie cookie : request.getCookies()) {
            if (name.equals(cookie.getName())) return cookie.getValue();
        }
        return null;
    }
}
```

---

## 4. UserContext — Thread-Local Store

```java
public final class UserContext {

    private static final ThreadLocal<UserInfo> HOLDER = new ThreadLocal<>();

    private UserContext() {}

    public static void set(UserInfo user) {
        HOLDER.set(user);
    }

    public static UserInfo get() {
        UserInfo user = HOLDER.get();
        if (user == null) {
            throw new AppBizException(ErrorCode.UNAUTHORIZED);
        }
        return user;
    }

    public static void clear() {
        HOLDER.remove();
    }
}
```

**Prohibition:** `UserContext.get()` MUST NOT contain any default/mock fallback branch. A missing user MUST always throw `AppBizException(ErrorCode.UNAUTHORIZED)`.

---

## 5. @Permission Annotation — Generation Flow

Controller `@Permission` annotations MUST be driven exclusively by the permission table in `docs/domains/*/api-implement-logic.md`. Never guess or hardcode.

```
Read permission table in api-implement-logic.md
      │
      ├── "限制访问租户" column
      │     ├── value present  → add characters[] (see §5.2)
      │     └── ANY / blank    → use bare @Permission (login-only check)
      │
      └── "功能权限" column
            ├── value present  → add powers[] referencing PowerConst (see §6)
            └── blank          → omit powers[], characterEnum only
```

### 5.1 Tenant Name → CharacterEnum Mapping

Tenant identifiers follow [`tenant.md`](tenant.md). Mapping to `CharacterEnum`:

| Document value        | CharacterEnum              |
|-----------------------|----------------------------|
| `DEV` / `DEVELOPER`   | `CharacterEnum.DEVELOPER`  |
| `OPERATOR` / `OPS`    | `CharacterEnum.OPERATOR`   |
| `ADMIN`               | `CharacterEnum.ADMIN`      |
| `ANY` / blank         | No characters (login only) |

> For any tenant name not listed above, read `CharacterEnum` source before proceeding. Do NOT guess.

### 5.2 Login-only (no tenant restriction)

```java
@Permission
@GetMapping("/ndp/template-library")
public ApiResponse<List<TemplateResponse>> list() { ... }
```

### 5.3 Tenant restriction, no function permission

```java
@Permission(
    characters = {
        @Permission.Character(characterEnum = CharacterEnum.DEVELOPER)
    }
)
@PostMapping("/ndp/template-library/upload")
public ApiResponse<TemplateResponse> upload(...) { ... }
```

### 5.4 Tenant restriction + function permission

```java
// Document: 124012.DEVELOPER_TEMPLATE_ADD → PowerConst.DEVELOPER.TEMPLATE_ADD
@Permission(
    characters = {
        @Permission.Character(
            characterEnum = CharacterEnum.DEVELOPER,
            powers = { PowerConst.DEVELOPER.TEMPLATE_ADD }
        )
    }
)
@PostMapping("/ndp/template-library/upload")
public ApiResponse<TemplateResponse> upload(...) { ... }
```

### 5.5 Public endpoint (no login required)

```java
@Permission(login = false)
@GetMapping("/public/health")
public ApiResponse<String> health() { ... }
```

### 5.6 Multi-tenant shared endpoint

```java
@Permission(
    characters = {
        @Permission.Character(
            characterEnum = CharacterEnum.DEVELOPER,
            powers = { PowerConst.DEVELOPER.TEMPLATE_VIEW }
        ),
        @Permission.Character(
            characterEnum = CharacterEnum.OPERATOR,
            powers = { PowerConst.OPERATOR.TEMPLATE_VIEW }
        )
    }
)
@GetMapping("/ndp/template-library/{id}")
public ApiResponse<TemplateResponse> getById(...) { ... }
```

---

## 6. PowerConst — Function Permission Constants

> **Example values only.** The codes shown below (`124012.MANAGE`, etc.) are illustrations. Real codes come from `docs/domains/*/api-implement-logic.md` per project.

### 6.1 Location

`src/main/java/com/newland/{appName}/common/constant/PowerConst.java`

### 6.2 Derivation Rule

```
Raw permission code:  {moduleCode}.{OPERATION}
                              │            │
                              │            └─ constant field name (keep uppercase)
                              │
                              └─ prefix of the string value (not used in constant name)

Examples:
  124012.ADD
    → class:  PowerConst.DEVELOPER
    → field:  TEMPLATE_MANAGE
    → value:  "124012.MANAGE"

  124012.EDIT
    → class:  PowerConst.DEVELOPER
    → field:  APP_TEMPLATE_ADD
    → value:  "124013.EDIT"
```

Split the part after `.` on the **first** `_`: left part = inner class, remainder = field name.

### 6.3 Class Structure

```java
public final class PowerConst {

    private PowerConst() {}

    public static final class DEVELOPER {
        private DEVELOPER() {}

        public static final String TEMPLATE_MANAGE   = "124012.MANAGE";
        public static final String TEMPLATE_ADD      = "124012.ADD";
        public static final String TEMPLATE_EDIT     = "124012.EDIT";
        public static final String TEMPLATE_DELETE   = "124012.DELETE";
        public static final String TEMPLATE_EXPORT   = "124012.EXPORT";
        public static final String TEMPLATE_VALIDATE = "124012.VALIDATE";
    }

    public static final class OPERATOR {
        private OPERATOR() {}
        // Add OPERATOR constants as needed
    }

    public static final class ADMIN {
        private ADMIN() {}
        // Add ADMIN constants as needed
    }
}
```

---

## 7. Prohibitions

### Production Code

- **MUST NOT** add any mock/fallback branch in `UserContext.get()`
- **MUST NOT** hardcode tenant values (`"DEV"`, `1L`, etc.) in any layer
- **MUST NOT** omit `@Permission` on any Controller method that calls `UserContext.get()`
- **MUST NOT** implement token parsing logic outside `UserContextInterceptor`
- **MUST NOT** bypass interceptors via `excludePathPatterns` or `@Permission(login=false)` on protected endpoints
- **MUST NOT** write raw string literals in `@Permission(powers=...)` — always reference `PowerConst`
- **MUST NOT** configure `@Permission` without reading `api-implement-logic.md` first

### Test Code

- **MUST NOT** disable or mock `UserContextInterceptor` to bypass auth in tests
- **MUST NOT** add temporary auth exemption logic to production code to make tests pass
- Unit tests that need a user context MUST call `UserContext.set()` in `@BeforeEach` and `UserContext.clear()` in `@AfterEach`
- Integration tests MUST supply a real `WEB-TOKEN` header backed by a Redis entry; interceptors MUST remain active

---

## Checks

- [ ] `authorization-api` dependency present in `pom.xml` with version from `project-info.yaml > auth.toms.api-version`
- [ ] `PlatformWebAuthInterceptor` registered in `WebMvcConfig` (first interceptor)
- [ ] `UserContextInterceptor` registered after `PlatformWebAuthInterceptor`
- [ ] `UserContext.get()` throws on null — no mock fallback
- [ ] Every Controller method annotated with `@Permission` matching the permission table
- [ ] All `powers` values reference `PowerConst` constants, not string literals
- [ ] `PowerConst` constants derived from `api-implement-logic.md` permission table only
