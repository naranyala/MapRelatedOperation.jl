# MapRelatedOperation.jl

A dependency-free Julia foundation for WGS84 coordinate validation, spherical map calculations, antimeridian-aware bounds, route metrics, and provider-neutral integration contracts.

Project scope, non-goals, and acceptance criteria are recorded in
[PYRAMID-OF-INTENTS.md](PYRAMID-OF-INTENTS.md). The intent-linked implementation
backlog is maintained in [TODOS.md](TODOS.md).

## Install

```julia
pkg> add "https://github.com/naranyala/MapRelatedOperation.jl"
```

## Quick start

```julia
using MapRelatedOperation

london = LatLon(51.5074, -0.1278)
paris = LatLon(48.8566, 2.3522)

distance_metres = haversine_distance(london, paris)
bearing_degrees = initial_bearing(london, paris)
arrival = destination(london, bearing_degrees, distance_metres)
```

`LatLon` accepts decimal degrees and validates latitude in `[-90, 90]` and longitude in `[-180, 180)`. Distances use the IUGG mean Earth radius and are expressed in metres. `midpoint(a, b)` returns the great-circle midpoint (and reports an error for antipodal points, where one is not unique).

## Bounds and routes

`bounding_box(points)` finds the smallest longitude interval that contains the supplied points, including intervals that cross the antimeridian. `contains(bounds, point)` understands those wrapped bounds. `route_length(points)` sums consecutive great-circle legs.

`interpolate(a, b, fraction)` follows the shortest great-circle arc. `cross_track_distance(point, start, finish)` measures signed distance to an infinite great-circle route line, while `segment_distance(point, start, finish)` clamps that calculation to a finite route leg. These reject ambiguous antipodal/degenerate paths.

## Web Mercator and tiles

`web_mercator_project(point)` and `web_mercator_unproject(x, y)` convert between WGS84 and normalized EPSG:3857 world coordinates. `tile_indices(point, zoom)`, `tile_bounds(x, y, zoom)`, and `tile_center(x, y, zoom)` support zero-based XYZ/slippy-map tiles through zoom 30. `ground_resolution(latitude, zoom)` returns metres per pixel for a configurable tile size. Web Mercator intentionally rejects latitudes outside ±85.0511287798066°.

## Exchange and API helpers

`polyline_encode(points)` and `polyline_decode(encoded)` implement the standard Google encoded-polyline format without any external dependencies.

The package also offers URL builders for common external APIs:

```julia
static_map_url(london; api_key=ENV["GOOGLE_MAPS_API_KEY"])
directions_url(london, paris; api_key=ENV["GOOGLE_MAPS_API_KEY"], mode=:transit)
geocode_url("10 Downing Street, London") # OpenStreetMap Nominatim query URL
```

These functions only build request URLs. Applications must keep credentials out of source control and provide their own HTTP client, retry strategy, and compliance with each provider's usage policies.

## Provider integrations

Implement `geocode`, `reverse_geocode`, and `route` for a subtype of `AbstractMapProvider`. The package deliberately has no HTTP or provider dependency: adapters can select their own transport, authentication, retries, and response schema while returning `GeocodingResult` and `Route` where appropriate.

```julia
struct MyProvider <: AbstractMapProvider
    api_key::String
end

function MapRelatedOperation.geocode(provider::MyProvider, query::AbstractString; kwargs...)
    # Call the provider and convert its response.
    return [GeocodingResult(LatLon(51.5074, -0.1278), "London")]
end
```

See the [provider adapter guide](docs/PROVIDER-ADAPTERS.md) for neutral-data
contracts, security responsibilities, and a recommended adapter test matrix.

## Development

Run the test suite with:

```sh
julia --project=. -e 'using Pkg; Pkg.test()'
```

Run the dependency-free microbenchmarks with:

```sh
julia --project=. benchmark/benchmarks.jl
```
