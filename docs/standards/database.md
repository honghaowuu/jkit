# Database Standards (MySQL + MyBatis-Plus)

**Applies when:** `database.enabled: true` and `database.type: mysql` in `project-info.yaml`.

The database name is taken from `project-info.yaml > database.name`.

## Database Operations

`mysql-schema.sql` MUST include the following operations (substitute `{database_name}` from `project-info.yaml > database.name`):

```sql
-- Create database if it does not exist
CREATE DATABASE IF NOT EXISTS `{database_name}` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;

-- Switch to target database
USE `{database_name}`;

-- Table names must be prefixed with database name: database_name.table_name
CREATE TABLE IF NOT EXISTS `{database_name}`.`{table_name}` (
    ...
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

- All `CREATE TABLE` statements must use `` `{database_name}`.`{table_name}` `` format

---

## ORM

- ORM: MyBatis-Plus only
- DAOs extend `BaseMapper<T>`
- FORBIDDEN annotations on DAO: `@Select`, `@Insert`, `@Update`, `@Delete`
- All SQL MUST be defined in XML mapper files
- XML namespace MUST match DAO interface package path

---

## Table Naming

- All table names MUST use `t_` prefix (e.g., `t_user`, `t_parameter_template`)

---

## Column

### Foreign-key

- Never use foreign keys

---

### Type

- Prohibition of unconditional use of TEXT type: For string-type fields, the `TEXT` (or `LONGTEXT`) type must not be used directly without analyzing the business scenario.
- Prioritize VARCHAR and specify a reasonable length:
    - Analyze the actual use of the field in the business and estimate its maximum possible length.
    - Choose the appropriate `VARCHAR` length based on the scenario, e.g.
        - Name class field: `VARCHAR(64)` or `VARCHAR(128)`
        - Address class field: `VARCHAR(256)` or `VARCHAR(512)`
        - Email: `VARCHAR(128)`
        - Mobile number: `VARCHAR(32)`
        - Short description: `VARCHAR(512)` or `VARCHAR(1024)`
        - Medium and long text (e.g. comments, remarks): if length is predictable and ≤ 1000 chars, still use `VARCHAR(1024)` or `VARCHAR(2048)`; `TEXT` is reserved for content that is explicitly necessary to store and uncontrollable in length (> ~4000 bytes).
- If a reasonable length cannot be inferred from the context (e.g., fields named `content` or `description` without a described business scenario), do one of:
    - Ask the user about the typical length range for the field, or
    - Use a looser but still controlled length (e.g. `VARCHAR(1024)`) and state in the generated DDL comment that "this length can be adjusted based on actual business".
- Exceptions where `TEXT` is allowed:
    - Fields explicitly used to store large rich text, article bodies, logs, or other content that cannot be estimated.
    - The `Special Instructions` field in business requirements that may exceed 4000 characters.
    - When using `TEXT`, the reason MUST be stated in the DDL comment.

---

### Primary Key

- INT/BIGINT PK: `{entity}_id` (e.g., `user_id`, `parameter_template_id`)
- VARCHAR PK: `{entity}_uuid` (e.g., `detail_uuid`, `trans_uuid`)

---

### Audit (Required)

Every table MUST include:
- `cre_time` BIGINT — creation time (seconds precision)
- `cre_user_id` — creator user ID; use `0` for system-generated rows

If rows can be updated, also include:
- `upd_time` BIGINT — update time (seconds precision)
- `upd_user_id` — updater user ID; use `0` for system-updated rows

---

### Nullability

- All columns are `NOT NULL` by default
- Nullable columns must be explicitly justified with a comment in the DDL

---

## DAO Model Rules

If the database column name is a MySQL reserved word, the entity field MUST be annotated with `@TableField` using backtick-quoted name. For example:

```java
@TableField("`desc`")
private String desc;
```

---

## SQL Rules

- NEVER use `SELECT *`; always specify columns
- Queries MUST use indexed columns whenever possible

---

## Tenant Notes

Multi-tenant column rules → see [`tenant.md`](tenant.md).

---

## Checks
- [ ] Every DAO interface extends `BaseMapper<T>`
- [ ] No `@Select` / `@Insert` / `@Update` / `@Delete` annotation on any DAO method
- [ ] Every XML mapper file's namespace matches the corresponding DAO interface package path
- [ ] Every table name uses `t_*` prefix
- [ ] Every `CREATE TABLE` is qualified as `{database_name}.{table_name}`
- [ ] Every table has all four audit columns (`cre_time`, `cre_user_id`, `upd_time`, `upd_user_id`) when rows can be updated
- [ ] No `FOREIGN KEY` clauses in any DDL
- [ ] No `SELECT *` in any XML mapper or `LambdaQueryWrapper`
- [ ] Every column declared `NOT NULL` unless its nullability is justified by a comment
- [ ] Every MySQL-reserved-word column has `@TableField("\`name\`")` on its entity field
- [ ] No `VARCHAR` field longer than 4000 without a comment justifying TEXT/LONGTEXT instead
