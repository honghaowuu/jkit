# Multi-Tenant Standards

**Applies when:** `tenant.enabled: true` in `project-info.yaml`. Independent of `auth.toms.enabled`.

This file is the canonical home for the `character_code` + `key_id` identity scheme. [`redis.md`](redis.md) and [`auth-toms.md`](auth-toms.md) cross-reference here.

## 1. Tenant Identity

A tenant is identified by the **combination of two fields**:

| Field            | Type                  | Description                                                  |
|------------------|-----------------------|--------------------------------------------------------------|
| `character_code` | `VARCHAR(32) NOT NULL` | Tenant type (see enum below)                                 |
| `key_id`         | `BIGINT NOT NULL`     | Tenant instance primary key                                  |
| `user_id`        | `BIGINT NOT NULL`     | Currently logged-in user ID (not a tenant identifier, but recorded) |

Tenant type enum (`character_code`):

| character_code | Description                                                            |
|----------------|------------------------------------------------------------------------|
| `ADMIN`        | System administrator; manages all tenants                              |
| `OPERATOR`     | Operator: an enterprise that has purchased services or device products |
| `MERCHANT`     | Merchant: a physical merchant                                          |
| `DEV`          | ISV: independent software vendor                                       |

---

## 2. Which Tables Need Tenant Columns

### Tables that MUST include `character_code` + `key_id`

- **Business primary tables** — entities natively belonging to a tenant (e.g., parameter templates, orders, configs)
- **Denormalized child tables** — tables that copy tenant fields from a parent to avoid excessive JOINs (e.g., nodes, config items)

**Decision rule:** if a record naturally belongs to a tenant, the table MUST include the tenant columns.

### Tables that do NOT need tenant columns

- **System dictionary tables** — globally shared enums or configs that are not tenant-specific (e.g., country codes, currency types)
- **Pure M:N junction tables** — relationship-only tables that link to main tables already containing tenant fields
- **System log tables** — operation logs that may record `character_code` + `key_id` without enforcing tenant-isolated queries

---

## 3. Column Definitions

```sql
-- Main table example (a business entity directly owned by a tenant)
character_code  VARCHAR(32) NOT NULL COMMENT 'Tenant type: ADMIN/OPERATOR/MERCHANT/DEV',
key_id          BIGINT      NOT NULL COMMENT 'Tenant instance primary key',
```

**Rules:**
- `character_code`: `VARCHAR(32) NOT NULL`, no default value, must be supplied on insert
- `key_id`: `BIGINT NOT NULL`, no default value, must be supplied on insert
- The two fields **MUST always appear together** — never declare only one of them
- Comment style: English description plus enum values inline

---

## 4. Index Conventions

### 4.1 Main Tables (business primary tables)

**Required composite indexes:**

```sql
-- Tenant query primary index (supports paginated/filtered queries scoped to a tenant)
INDEX idx_{table}_tenant_status (character_code, key_id, status)

-- Within-tenant uniqueness constraint (e.g. unique name per tenant)
UNIQUE KEY uk_{table}_tenant_{field} (character_code, key_id, {unique_field})
```

**Composite-index field-order rule:**
1. `character_code` (highest selectivity, filter first)
2. `key_id`
3. Other filter fields (`status`, `type`, etc.)

### 4.2 Denormalized Child Tables

A child table relates to its parent via a FK column (e.g., `template_id`). The dominant access pattern is `WHERE template_id = ?`.

- **Required:** single-column index `idx_{table}_{fk_column}` on the FK
- If the child is also queried directly by tenant, add `idx_{table}_tenant_status` as well
- If there is no scenario for direct-by-tenant child queries, the tenant composite index can be omitted (but the columns themselves MUST stay)

---

## 5. Multi-tenant Query Rules

### 5.1 Main-table queries: pass tenant fields explicitly

```xml
<!-- ✅ CORRECT: explicit WHERE character_code + key_id -->
<select id="selectPageByTenant" resultMap="BaseResultMap">
    SELECT <include refid="Base_Column_List"/>
    FROM t_parameter_template
    WHERE character_code = #{characterCode}
      AND key_id = #{keyId}
      AND status != 3
    <if test="templateName != null and templateName != ''">
        AND template_name LIKE CONCAT('%', #{templateName}, '%')
    </if>
    ORDER BY cre_time DESC
</select>
```

### 5.2 Child-table queries: implicit isolation via the parent FK

```xml
<!-- ✅ CORRECT: implicit tenant isolation through template_id -->
<select id="selectByTemplateId" resultMap="BaseResultMap">
    SELECT <include refid="Base_Column_List"/>
    FROM t_template_node
    WHERE template_id = #{templateId}
    ORDER BY sort_order ASC, template_node_id ASC
</select>
```

### 5.3 Forbidden patterns

```xml
<!-- ❌ WRONG: main-table query without tenant filter -->
<select id="selectAll">
    SELECT * FROM t_parameter_template
</select>

<!-- ❌ WRONG: child-table full scan with no FK or tenant filter -->
<select id="selectByName">
    SELECT * FROM t_template_node WHERE node_key = #{nodeKey}
</select>
```

### 5.4 Uniqueness checks must include the tenant predicate

```java
// ✅ CORRECT: uniqueness checks must include characterCode + keyId
LambdaQueryWrapper<ParameterTemplate> wrapper =
    new LambdaQueryWrapper<ParameterTemplate>()
        .eq(ParameterTemplate::getCharacterCode, characterCode)
        .eq(ParameterTemplate::getKeyId, keyId)
        .eq(ParameterTemplate::getTemplateName, name);
```

---

## 6. Tenant Field Assignment for Denormalized Child Records

A child table inherits its parent's tenant via FK, but the tenant fields MUST still be set explicitly — sourced from the parent row, **not** from `UserContext`:

```java
// ✅ CORRECT: copy tenant fields from the parent record
TemplateNode node = new TemplateNode();
node.setCharacterCode(template.getCharacterCode());  // copied from parent
node.setKeyId(template.getKeyId());                  // copied from parent
```

```java
// ❌ WRONG: re-reading from UserContext (may diverge from the parent record)
node.setCharacterCode(UserContext.get().getCharacterCode());
```

---

## 7. Complete DDL Example

```sql
-- Main table (with composite tenant index)
CREATE TABLE IF NOT EXISTS t_parameter_template (
    parameter_template_id  BIGINT      NOT NULL AUTO_INCREMENT COMMENT 'Primary key',
    character_code         VARCHAR(32) NOT NULL COMMENT 'Tenant type: ADMIN/OPERATOR/MERCHANT/DEV',
    key_id                 BIGINT      NOT NULL COMMENT 'Tenant instance primary key',
    template_name          VARCHAR(128) NOT NULL COMMENT 'Template name',
    status                 TINYINT     NOT NULL DEFAULT 1 COMMENT 'Status: 1=NORMAL, 2=LOCKED, 3=SOFT_DELETED',
    cre_time               BIGINT      NOT NULL COMMENT 'Creation time (seconds)',
    cre_user_id            BIGINT      NOT NULL COMMENT 'Creator user ID',
    upd_time               BIGINT      NOT NULL COMMENT 'Update time (seconds)',
    upd_user_id            BIGINT      NOT NULL COMMENT 'Updater user ID',
    PRIMARY KEY (parameter_template_id),
    UNIQUE KEY uk_template_tenant_name (character_code, key_id, template_name),
    INDEX idx_template_tenant_status (character_code, key_id, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Parameter template';

-- Child table (FK column index; tenant columns retained but no composite tenant index)
CREATE TABLE IF NOT EXISTS t_template_node (
    template_node_id  BIGINT      NOT NULL AUTO_INCREMENT COMMENT 'Primary key',
    template_id       BIGINT      NOT NULL COMMENT 'Owning template ID',
    character_code    VARCHAR(32) NOT NULL COMMENT 'Tenant type (denormalized copy)',
    key_id            BIGINT      NOT NULL COMMENT 'Tenant instance primary key (denormalized copy)',
    node_key          VARCHAR(128) NOT NULL COMMENT 'Node key',
    cre_time          BIGINT      NOT NULL COMMENT 'Creation time (seconds)',
    cre_user_id       BIGINT      NOT NULL COMMENT 'Creator user ID',
    upd_time          BIGINT      NOT NULL COMMENT 'Update time (seconds)',
    upd_user_id       BIGINT      NOT NULL COMMENT 'Updater user ID',
    PRIMARY KEY (template_node_id),
    UNIQUE KEY uk_node_template_key (template_id, node_key),
    INDEX idx_node_template_id (template_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Template node';
```

---

## Checks
- [ ] Every business main table has both `character_code` (VARCHAR(32) NOT NULL) and `key_id` (BIGINT NOT NULL)
- [ ] No table has only one of the two columns
- [ ] Every business main table has a composite index starting with `(character_code, key_id, ...)`
- [ ] Every uniqueness query (find-by-name, find-by-code, etc.) includes `character_code` and `key_id` in the predicate
- [ ] Denormalized child tables copy `character_code`/`key_id` from the parent record, not from `UserContext`
- [ ] No main-table query lacks a tenant filter
