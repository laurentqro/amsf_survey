# Data Model: Monorepo Structure Setup

**Date**: 2025-12-21
**Feature**: 001-monorepo-setup

## Entities

### Registry (Core Gem)

The registry tracks registered industry plugins and their taxonomy paths.

| Attribute | Type | Description |
|-----------|------|-------------|
| industry | Symbol | Unique identifier for the industry (e.g., `:real_estate`) |
| taxonomy_path | String | Absolute path to the taxonomy directory |

**State**: In-memory hash, populated at require time.

**Relationships**:
- One registry per Ruby process
- Many plugins can register with the registry

### Plugin Registration

| Attribute | Type | Description |
|-----------|------|-------------|
| industry | Symbol | Industry identifier passed to `register_plugin` |
| taxonomy_path | String | Path to `taxonomies/` directory in plugin gem |
| years | Array<Integer> | Detected years from taxonomy subdirectories (future) |

## Public API Methods

### Core Gem (`AmsfSurvey`)

| Method | Arguments | Returns | Description |
|--------|-----------|---------|-------------|
| `registered_industries` | none | `Array<Symbol>` | List of registered industry symbols |
| `registered?(industry)` | `industry: Symbol` | `Boolean` | Check if industry is registered |
| `supported_years(industry)` | `industry: Symbol` | `Array<Integer>` | Years available for industry (stub for now) |
| `register_plugin` | `industry: Symbol, taxonomy_path: String` | `void` | Register an industry plugin |

### Plugin Gem (`AmsfSurvey::RealEstate`)

No public methods - the plugin auto-registers when required.

## Validation Rules

| Rule | Entity | Description |
|------|--------|-------------|
| Unique industry | Registry | Cannot register same industry twice |
| Valid taxonomy path | Registration | Path must exist and be a directory |
| Required industry | Registration | Industry symbol must be provided |

## State Transitions

```
[Unregistered] --register_plugin--> [Registered]
```

Once registered, a plugin cannot be unregistered (no use case for this).
