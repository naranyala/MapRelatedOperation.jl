# Pyramid Of Intents

## Purpose

MapRelatedOperation.jl is a small, dependable foundation for common map-coordinate calculations and map-service interoperability in Julia. Its primary value is predictable semantics, explicit units, and safe geographic edge-case handling.

## Intent Stack

### 1. Non-Negotiable Foundation

- Represent WGS84 coordinates with validated decimal-degree inputs.
- State units in every public calculation. Distances are metres; bearings are degrees.
- Handle the antimeridian, poles, degenerate paths, and Web Mercator limits explicitly rather than silently returning misleading values.
- Keep core functionality dependency-free and covered by automated tests.

### 2. Geographic Calculation Toolkit

- Provide spherical great-circle operations: distance, bearing, destination, midpoint, interpolation, cross-track distance, and finite-leg distance.
- Provide antimeridian-aware bounds and route metrics.
- Provide normalized Web Mercator and XYZ tile calculations for web-map workflows.

### 3. Interchange And Provider Boundaries

- Support encoded polylines for compact route exchange.
- Define provider-neutral geocoding and routing result contracts.
- Build request URLs without performing network I/O or owning credentials.

### 4. Ecosystem Extensions

- Allow separate packages to add concrete provider clients, HTTP transports, caching, and provider response parsing.
- Add optional format and projection integrations only when their maintenance and dependency costs are justified.

## Explicit Non-Goals

- This package does not execute HTTP requests, store API keys, implement retries, or enforce third-party service policies.
- This package is not a GIS database, map renderer, tile server, or geocoder.
- Core spherical calculations are not a replacement for an ellipsoidal geodesy engine when survey-grade precision is required.
- GeoJSON, shapefiles, raster processing, and spatial indexing are deferred to focused packages or optional extensions.

## Contribution Rules

- New public APIs must document coordinate reference system, units, edge-case behavior, and failure modes.
- Keep provider-specific behavior behind adapters or pure request builders.
- Add deterministic tests for normal, boundary, and invalid inputs before considering an intent complete.
- Prefer optional integrations over expanding the dependency-free core.
