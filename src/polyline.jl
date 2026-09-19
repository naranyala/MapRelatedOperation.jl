function _polyline_value!(io::IO, value::Integer)
    value = value < 0 ? ~(value << 1) : value << 1
    while value >= 0x20
        print(io, Char((0x20 | (value & 0x1f)) + 63)); value >>= 5
    end
    print(io, Char(value + 63))
end

"""Encode coordinates in Google's encoded-polyline algorithm. `precision=5` is the standard format."""
function polyline_encode(points::AbstractVector{<:LatLon}; precision::Integer=5)
    0 <= precision <= 10 || throw(DomainError(precision, "precision must be between 0 and 10"))
    scale, lastlat, lastlon, io = 10^precision, 0, 0, IOBuffer()
    for point in points
        lat, lon = round(Int, point.latitude * scale), round(Int, point.longitude * scale)
        _polyline_value!(io, lat - lastlat); _polyline_value!(io, lon - lastlon)
        lastlat, lastlon = lat, lon
    end
    return String(take!(io))
end

function _decode_value(bytes, index)
    value, shift = 0, 0
    while true
        index > length(bytes) && throw(ArgumentError("truncated polyline"))
        byte = Int(bytes[index]) - 63
        0 <= byte <= 63 || throw(ArgumentError("invalid polyline character"))
        index += 1; value |= (byte & 0x1f) << shift; shift += 5
        byte < 0x20 && return (isodd(value) ? ~(value >> 1) : value >> 1), index
        shift <= 60 || throw(ArgumentError("polyline value is too large"))
    end
end

"""Decode a Google encoded polyline into `LatLon` values."""
function polyline_decode(encoded::AbstractString; precision::Integer=5)
    0 <= precision <= 10 || throw(DomainError(precision, "precision must be between 0 and 10"))
    bytes, index, lat, lon, points = codeunits(encoded), 1, 0, 0, LatLon[]
    while index <= length(bytes)
        dlat, index = _decode_value(bytes, index); dlon, index = _decode_value(bytes, index)
        lat += dlat; lon += dlon; push!(points, LatLon(lat / 10.0^precision, lon / 10.0^precision))
    end
    return points
end
