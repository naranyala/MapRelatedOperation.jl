module MapRelatedOperation

import Base: contains

export LatLon, GeoBounds, EARTH_RADIUS_METERS, normalize_longitude, haversine_distance,
       initial_bearing, destination, midpoint, interpolate, cross_track_distance, segment_distance,
       bounding_box, contains, crosses_antimeridian, route_length,
       WEB_MERCATOR_MAX_LATITUDE, web_mercator_project, web_mercator_unproject, tile_indices, tile_bounds,
       tile_center, ground_resolution,
       polyline_encode, polyline_decode, static_map_url, directions_url, geocode_url,
       AbstractMapProvider, GeocodingResult, Route, geocode, reverse_geocode, route

"Mean Earth radius in metres, as defined by the IUGG."
const EARTH_RADIUS_METERS = 6_371_008.8

"A validated WGS84 latitude/longitude coordinate, stored in decimal degrees."
struct LatLon
    latitude::Float64
    longitude::Float64

    function LatLon(latitude::Real, longitude::Real)
        lat = Float64(latitude)
        lon = Float64(longitude)
        isfinite(lat) || throw(ArgumentError("latitude must be finite"))
        isfinite(lon) || throw(ArgumentError("longitude must be finite"))
        -90.0 <= lat <= 90.0 || throw(ArgumentError("latitude must be in [-90, 90] degrees"))
        -180.0 <= lon < 180.0 || throw(ArgumentError("longitude must be in [-180, 180) degrees"))
        new(lat, lon)
    end
end

"Normalize a longitude to the half-open interval [-180, 180)."
normalize_longitude(longitude::Real) = mod(Float64(longitude) + 180.0, 360.0) - 180.0

"A latitude/longitude rectangle. `west > east` denotes a rectangle crossing the antimeridian."
struct GeoBounds
    south::Float64
    west::Float64
    north::Float64
    east::Float64

    function GeoBounds(south::Real, west::Real, north::Real, east::Real)
        s, w, n, e = Float64.((south, west, north, east))
        isfinite(s) && isfinite(w) && isfinite(n) && isfinite(e) || throw(ArgumentError("bounds must be finite"))
        -90.0 <= s <= n <= 90.0 || throw(ArgumentError("latitudes must satisfy -90 <= south <= north <= 90"))
        -180.0 <= w < 180.0 || throw(ArgumentError("west must be in [-180, 180) degrees"))
        -180.0 <= e < 180.0 || throw(ArgumentError("east must be in [-180, 180) degrees"))
        new(s, w, n, e)
    end
end

_radians(degrees::Real) = deg2rad(Float64(degrees))

"Great-circle distance between two coordinates in metres, using the haversine formula."
function haversine_distance(a::LatLon, b::LatLon; radius::Real=EARTH_RADIUS_METERS)
    r = Float64(radius)
    isfinite(r) && r > 0 || throw(ArgumentError("radius must be a finite positive value"))
    dlat = _radians(b.latitude - a.latitude)
    dlon = _radians(b.longitude - a.longitude)
    h = sin(dlat / 2)^2 + cos(_radians(a.latitude)) * cos(_radians(b.latitude)) * sin(dlon / 2)^2
    2r * asin(min(1.0, sqrt(h)))
end

"Initial great-circle bearing from `a` to `b`, clockwise from true north in [0, 360) degrees."
function initial_bearing(a::LatLon, b::LatLon)
    dlon = _radians(b.longitude - a.longitude)
    y = sin(dlon) * cos(_radians(b.latitude))
    x = cos(_radians(a.latitude)) * sin(_radians(b.latitude)) -
        sin(_radians(a.latitude)) * cos(_radians(b.latitude)) * cos(dlon)
    mod(rad2deg(atan(y, x)), 360.0)
end

"Coordinate reached after travelling `distance` metres on an initial `bearing` in degrees."
function destination(start::LatLon, bearing::Real, distance::Real; radius::Real=EARTH_RADIUS_METERS)
    r, d = Float64(radius), Float64(distance)
    isfinite(r) && r > 0 || throw(ArgumentError("radius must be a finite positive value"))
    isfinite(d) && d >= 0 || throw(ArgumentError("distance must be finite and non-negative"))
    isfinite(bearing) || throw(ArgumentError("bearing must be finite"))
    angular_distance = d / r
    θ = _radians(bearing)
    φ1, λ1 = _radians(start.latitude), _radians(start.longitude)
    φ2 = asin(sin(φ1) * cos(angular_distance) + cos(φ1) * sin(angular_distance) * cos(θ))
    λ2 = λ1 + atan(sin(θ) * sin(angular_distance) * cos(φ1), cos(angular_distance) - sin(φ1) * sin(φ2))
    LatLon(rad2deg(φ2), normalize_longitude(rad2deg(λ2)))
end

"Great-circle midpoint of two coordinates. Antipodal inputs do not have a unique midpoint."
function midpoint(a::LatLon, b::LatLon)
    φ1, λ1 = _radians(a.latitude), _radians(a.longitude)
    φ2, λ2 = _radians(b.latitude), _radians(b.longitude)
    bx, by = cos(φ2) * cos(λ2 - λ1), cos(φ2) * sin(λ2 - λ1)
    denominator = hypot(cos(φ1) + bx, by)
    denominator > sqrt(eps(Float64)) || throw(ArgumentError("antipodal coordinates have no unique midpoint"))
    φ3 = atan(sin(φ1) + sin(φ2), denominator)
    λ3 = λ1 + atan(by, cos(φ1) + bx)
    LatLon(rad2deg(φ3), normalize_longitude(rad2deg(λ3)))
end

"Whether `point` lies within `bounds`, including its edges."
function contains(bounds::GeoBounds, point::LatLon)
    bounds.south <= point.latitude <= bounds.north || return false
    bounds.west <= bounds.east ? bounds.west <= point.longitude <= bounds.east :
        point.longitude >= bounds.west || point.longitude <= bounds.east
end

"Whether `bounds` crosses the ±180° meridian."
crosses_antimeridian(bounds::GeoBounds) = bounds.west > bounds.east

"The smallest antimeridian-aware bounding rectangle containing `points`."
function bounding_box(points::AbstractVector{<:LatLon})
    isempty(points) && throw(ArgumentError("cannot compute bounds for an empty collection"))
    south = minimum(point.latitude for point in points)
    north = maximum(point.latitude for point in points)
    longitudes = sort(collect(mod(point.longitude, 360.0) for point in points))
    if length(longitudes) == 1
        lon = normalize_longitude(only(longitudes))
        return GeoBounds(south, lon, north, lon)
    end
    gaps = [longitudes[index + 1] - longitudes[index] for index in 1:(length(longitudes) - 1)]
    push!(gaps, longitudes[1] + 360.0 - longitudes[end])
    gap_index = argmax(gaps)
    west = gap_index == length(longitudes) ? longitudes[1] : longitudes[gap_index + 1]
    east = longitudes[gap_index]
    GeoBounds(south, normalize_longitude(west), north, normalize_longitude(east))
end

"Total great-circle length of consecutive coordinates in metres."
function route_length(points::AbstractVector{<:LatLon}; radius::Real=EARTH_RADIUS_METERS)
    sum(haversine_distance(points[index], points[index + 1]; radius) for index in 1:(length(points) - 1); init=0.0)
end

"Base type for integrations with map, geocoding, and routing providers."
abstract type AbstractMapProvider end

"A provider-independent geocoding result. Provider-specific fields belong in `metadata`."
struct GeocodingResult
    coordinate::LatLon
    display_name::String
    metadata::Dict{String,Any}
end

GeocodingResult(coordinate::LatLon, display_name::AbstractString; metadata=Dict{String,Any}()) =
    GeocodingResult(coordinate, String(display_name), Dict{String,Any}(metadata))

"A provider-independent route response. Distances are metres and duration is seconds when available."
struct Route
    points::Vector{LatLon}
    distance::Float64
    duration::Union{Nothing,Float64}
    metadata::Dict{String,Any}
end

function Route(points::AbstractVector{<:LatLon}; distance::Real=route_length(points), duration::Union{Nothing,Real}=nothing, metadata=Dict{String,Any}())
    d = Float64(distance)
    isfinite(d) && d >= 0 || throw(ArgumentError("distance must be finite and non-negative"))
    elapsed = isnothing(duration) ? nothing : Float64(duration)
    isnothing(elapsed) || (isfinite(elapsed) && elapsed >= 0) || throw(ArgumentError("duration must be finite and non-negative"))
    Route(collect(points), d, elapsed, Dict{String,Any}(metadata))
end

"Geocode `query`. Provider packages implement this method for their `AbstractMapProvider` subtype."
geocode(provider::AbstractMapProvider, query::AbstractString; kwargs...) = throw(MethodError(geocode, (provider, query)))

"Reverse-geocode `coordinate`. Provider packages implement this method for their subtype."
reverse_geocode(provider::AbstractMapProvider, coordinate::LatLon; kwargs...) = throw(MethodError(reverse_geocode, (provider, coordinate)))

"Request a route between coordinates. Provider packages implement this method for their subtype."
route(provider::AbstractMapProvider, origin::LatLon, destination::LatLon; kwargs...) = throw(MethodError(route, (provider, origin, destination)))

include("polyline.jl")
include("providers.jl")
include("projections.jl")
include("geodesic_extensions.jl")

end
