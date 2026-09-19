# TODOs

Tasks are ordered by the pyramid in `PYRAMID-OF-INTENTS.md`. Checked items are fulfilled in the current codebase; unchecked items are deliberate future work, not implied commitments.

## P0: Foundation

- [x] Define WGS84 coordinate and longitude-normalization invariants.
- [x] Validate numeric inputs and reject degenerate geographic operations.
- [x] Test calculations, projections, encodings, URL construction, and error paths with `Pkg.test()`.
- [x] Document scope, units, accuracy limits, and non-goals.

## P1: Geographic Toolkit

- [x] Provide great-circle distance, bearing, destination, midpoint, interpolation, cross-track, and finite-leg distance calculations.
- [x] Provide antimeridian-aware bounds and route-length operations.
- [x] Provide normalized Web Mercator and XYZ tile utilities.
- [x] Provide Google encoded-polyline exchange.
- [x] Add deterministic randomized-invariant tests for coordinate round trips and antimeridian bounds.
- [x] Add reproducible microbenchmarks for hot-path calculations.
- [ ] Set performance regression thresholds after recording baseline results on CI hardware.

## P2: Interoperability

- [x] Define provider-neutral geocoding and routing contracts.
- [x] Provide pure URL builders for common Google Maps and Nominatim endpoints.
- [x] Document the adapter contract, security boundary, and reusable test
  expectations in `docs/PROVIDER-ADAPTERS.md`.
- [ ] Publish optional provider-adapter packages with explicit HTTP, authentication, retry, rate-limit, and attribution policies.
- [ ] Add optional GeoJSON conversion support in a separate extension.

## P3: Deliberately Deferred

- [ ] Add ellipsoidal geodesics through an optional, documented dependency.
- [ ] Add spatial indexes and large-dataset operations through a dedicated package.
- [ ] Add raster, tile-serving, rendering, and database integrations outside the core package.

## Release Gates

- [x] `julia --project=. -e 'using Pkg; Pkg.test()'` passes.
- [x] Add CI for the minimum supported and current Julia versions.
- [ ] Select a license, maintainers, changelog, and semantic-versioning policy before a public registry release.
