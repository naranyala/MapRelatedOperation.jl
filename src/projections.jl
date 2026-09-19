"""Largest latitude representable by the Web Mercator (EPSG:3857) projection."""
const WEB_MERCATOR_MAX_LATITUDE = 85.0511287798066
const _WEB_MERCATOR_RADIUS_METERS = 6_378_137.0

function _validate_zoom(zoom::Integer)
    0 <= zoom <= 30 || throw(ArgumentError("zoom must be between 0 and 30"))
    Int(zoom)
end

"""
    web_mercator_project(point) -> (x, y)

Project WGS84 coordinates into normalized Web Mercator world coordinates. Both
components are in [0, 1], with `(0, 0)` at the north-west corner. Latitudes
beyond the projection limit are rejected rather than silently clipped.
"""
function web_mercator_project(point::LatLon)
    abs(point.latitude) <= WEB_MERCATOR_MAX_LATITUDE || throw(DomainError(point.latitude, "latitude is outside Web Mercator's usable range"))
    x = (point.longitude + 180.0) / 360.0
    y = (1.0 - asinh(tan(_radians(point.latitude))) / π) / 2.0
    (x=x, y=y)
end

"""Invert normalized Web Mercator world coordinates returned by `web_mercator_project`."""
function web_mercator_unproject(x::Real, y::Real)
    xf, yf = Float64(x), Float64(y)
    isfinite(xf) && isfinite(yf) && 0.0 <= xf <= 1.0 && 0.0 <= yf <= 1.0 ||
        throw(ArgumentError("x and y must be finite normalized coordinates in [0, 1]"))
    longitude = xf * 360.0 - 180.0
    latitude = rad2deg(atan(sinh(π * (1.0 - 2.0 * yf))))
    # 1.0 maps to the valid upper longitude boundary; preserve LatLon's half-open range.
    LatLon(latitude, normalize_longitude(longitude))
end

"""Return zero-based `(x, y)` XYZ tile indices containing `point` at `zoom`."""
function tile_indices(point::LatLon, zoom::Integer)
    z = _validate_zoom(zoom)
    world = web_mercator_project(point)
    count = 1 << z
    (min(floor(Int, world.x * count), count - 1), min(floor(Int, world.y * count), count - 1))
end

"""Return the WGS84 bounds of a zero-based XYZ tile at `zoom`."""
function tile_bounds(x::Integer, y::Integer, zoom::Integer)
    z = _validate_zoom(zoom)
    count = 1 << z
    0 <= x < count && 0 <= y < count || throw(ArgumentError("tile indices must be in 0:$(count - 1) at zoom $z"))
    northwest = web_mercator_unproject(x / count, y / count)
    southeast = web_mercator_unproject((x + 1) / count, (y + 1) / count)
    GeoBounds(southeast.latitude, northwest.longitude, northwest.latitude, southeast.longitude)
end

"""Return the WGS84 coordinate at the visual center of a zero-based XYZ tile."""
function tile_center(x::Integer, y::Integer, zoom::Integer)
    z = _validate_zoom(zoom)
    count = 1 << z
    0 <= x < count && 0 <= y < count || throw(ArgumentError("tile indices must be in 0:$(count - 1) at zoom $z"))
    web_mercator_unproject((x + 0.5) / count, (y + 0.5) / count)
end

"""
    ground_resolution(latitude, zoom; tile_size=256) -> Float64

Return metres represented by one pixel at `latitude` for a Web Mercator XYZ
map. The calculation uses the EPSG:3857 sphere radius and rejects latitudes
outside the projection's usable range.
"""
function ground_resolution(latitude::Real, zoom::Integer; tile_size::Integer=256)
    lat = Float64(latitude)
    isfinite(lat) && abs(lat) <= WEB_MERCATOR_MAX_LATITUDE ||
        throw(DomainError(latitude, "latitude is outside Web Mercator's usable range"))
    tile_size > 0 || throw(ArgumentError("tile_size must be positive"))
    z = _validate_zoom(zoom)
    cos(_radians(lat)) * 2π * _WEB_MERCATOR_RADIUS_METERS / (tile_size * (1 << z))
end

ground_resolution(point::LatLon, zoom::Integer; tile_size::Integer=256) =
    ground_resolution(point.latitude, zoom; tile_size)
