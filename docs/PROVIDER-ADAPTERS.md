# Provider Adapter Guide

MapRelatedOperation.jl deliberately does not make HTTP requests. A provider
adapter is responsible for transport, authentication, retries, response
decoding, rate limits, attribution, and the provider's terms of use. Keep that
responsibility in a separate package or application module.

## Minimal adapter

Define a subtype and implement only the operations the provider supports:

```julia
using MapRelatedOperation

struct ExampleMaps <: AbstractMapProvider
    token::String
    endpoint::String
end

function MapRelatedOperation.geocode(provider::ExampleMaps, query::AbstractString; kwargs...)
    # Build and execute a provider request in this adapter.
    # Parse its response, then return neutral data.
    [GeocodingResult(LatLon(51.5074, -0.1278), "London";
                     metadata=Dict("provider_id" => "example:123"))]
end

function MapRelatedOperation.route(provider::ExampleMaps, origin::LatLon,
                                   destination::LatLon; kwargs...)
    # Return route geometry in WGS84, distance in metres, duration in seconds.
    Route([origin, destination])
end
```

Unsupported operations should retain the inherited `MethodError`, or throw a
specific documented adapter error. Do not add provider network code to the core
package.

## Contract rules

- Inputs and returned `LatLon` values are WGS84 decimal degrees.
- `Route.distance` is metres and `Route.duration` is seconds.
- Preserve provider-only identifiers, confidence values, raw status codes, and
  attribution metadata under the result's `metadata` dictionary.
- Never place API keys in `metadata`, errors, logs, fixtures, or committed
  source. Read them from the adapter's configuration at runtime.
- Translate provider failures into adapter-specific exceptions that preserve
  enough context for callers without leaking secrets.
- The adapter owns pagination, retry/backoff, timeouts, quota behavior, and
  compliance with attribution and usage requirements.

## Recommended contract tests

An adapter should test the following against mocked transport or recorded,
redacted fixtures:

1. Geocoding results contain valid `LatLon` values and a nonempty display name.
2. Routes use metres/seconds and preserve the returned geometry order.
3. Invalid provider responses, authentication failures, quota responses, and
   timeouts result in documented errors.
4. Requests percent-encode user input and never emit credential values in logs.
5. Provider responses near ±180° preserve antimeridian semantics.

The core package tests only its neutral contracts and pure URL builders. Each
adapter package must own integration tests for its provider.
