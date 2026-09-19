_query_escape(value) = replace(string(value), "%" => "%25", " " => "%20", "," => "%2C", "|" => "%7C", ":" => "%3A", "/" => "%2F", "#" => "%23", "?" => "%3F", "&" => "%26", "=" => "%3D")
_coordinate_query(point::LatLon) = string(point.latitude, ",", point.longitude)
function _url(base::AbstractString, parameters::Pair...)
    query = join((string(first(p), "=", _query_escape(last(p))) for p in parameters if !isnothing(last(p))), "&")
    return isempty(query) ? String(base) : string(base, "?", query)
end

"""Build a Google Maps Static API URL. The caller owns API-key storage and HTTP execution."""
function static_map_url(center::LatLon; api_key::AbstractString, zoom::Integer=12, size::Tuple{<:Integer,<:Integer}=(600, 400), maptype::Symbol=:roadmap)
    0 <= zoom <= 22 || throw(DomainError(zoom, "zoom must be between 0 and 22"))
    1 <= size[1] <= 640 && 1 <= size[2] <= 640 || throw(DomainError(size, "each size dimension must be between 1 and 640"))
    maptype in (:roadmap, :satellite, :terrain, :hybrid) || throw(ArgumentError("unsupported map type"))
    return _url("https://maps.googleapis.com/maps/api/staticmap", "center" => _coordinate_query(center), "zoom" => zoom, "size" => "$(size[1])x$(size[2])", "maptype" => maptype, "key" => api_key)
end

"""Build a Google Maps Directions API URL for two points."""
function directions_url(origin::LatLon, destination::LatLon; api_key::AbstractString, mode::Symbol=:driving)
    mode in (:driving, :walking, :bicycling, :transit) || throw(ArgumentError("unsupported travel mode"))
    _url("https://maps.googleapis.com/maps/api/directions/json", "origin" => _coordinate_query(origin), "destination" => _coordinate_query(destination), "mode" => mode, "key" => api_key)
end

"""Build a Nominatim search URL. Set an identifying `email` when making production requests."""
function geocode_url(query::AbstractString; base_url::AbstractString="https://nominatim.openstreetmap.org/search", limit::Integer=1, email::Union{Nothing,AbstractString}=nothing)
    limit > 0 || throw(DomainError(limit, "limit must be positive"))
    _url(base_url, "q" => query, "format" => "jsonv2", "limit" => limit, "email" => email)
end
