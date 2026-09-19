"""
    interpolate(a, b, fraction; radius=EARTH_RADIUS_METERS) -> LatLon

Return the point `fraction` of the way along the shortest great-circle arc from
`a` to `b`. Fractions must be between zero and one. Antipodal endpoints are
rejected because their shortest path is not unique.
"""
function interpolate(a::LatLon, b::LatLon, fraction::Real; radius::Real=EARTH_RADIUS_METERS)
    t = Float64(fraction)
    isfinite(t) && 0.0 <= t <= 1.0 || throw(ArgumentError("fraction must be finite and in [0, 1]"))
    r = Float64(radius)
    isfinite(r) && r > 0 || throw(ArgumentError("radius must be a finite positive value"))
    t == 0.0 && return a
    t == 1.0 && return b
    δ = haversine_distance(a, b; radius=r) / r
    δ < sqrt(eps(Float64)) && return a
    sinδ = sin(δ)
    abs(sinδ) > sqrt(eps(Float64)) || throw(ArgumentError("antipodal coordinates have no unique great-circle path"))
    φ1, λ1 = _radians(a.latitude), _radians(a.longitude)
    φ2, λ2 = _radians(b.latitude), _radians(b.longitude)
    weight_a, weight_b = sin((1 - t) * δ) / sinδ, sin(t * δ) / sinδ
    x = weight_a * cos(φ1) * cos(λ1) + weight_b * cos(φ2) * cos(λ2)
    y = weight_a * cos(φ1) * sin(λ1) + weight_b * cos(φ2) * sin(λ2)
    z = weight_a * sin(φ1) + weight_b * sin(φ2)
    LatLon(rad2deg(atan(z, hypot(x, y))), normalize_longitude(rad2deg(atan(y, x))))
end

"""
    cross_track_distance(point, start, finish; radius=EARTH_RADIUS_METERS)

Signed shortest distance in metres from `point` to the infinite great-circle
through `start` and `finish`; a positive value is to the right of travel. For a
finite route leg, additionally compare the endpoint distances.
"""
function cross_track_distance(point::LatLon, start::LatLon, finish::LatLon; radius::Real=EARTH_RADIUS_METERS)
    r = Float64(radius)
    isfinite(r) && r > 0 || throw(ArgumentError("radius must be a finite positive value"))
    δ13 = haversine_distance(start, point; radius=r) / r
    δ12 = haversine_distance(start, finish; radius=r) / r
    δ12 > sqrt(eps(Float64)) || throw(ArgumentError("start and finish must be distinct"))
    θ13, θ12 = _radians(initial_bearing(start, point)), _radians(initial_bearing(start, finish))
    r * asin(clamp(sin(δ13) * sin(θ13 - θ12), -1.0, 1.0))
end

"""
    segment_distance(point, start, finish; radius=EARTH_RADIUS_METERS)

Shortest distance in metres from `point` to the finite great-circle leg from
`start` to `finish`. When the perpendicular projection is outside the leg, the
distance to the nearer endpoint is returned.
"""
function segment_distance(point::LatLon, start::LatLon, finish::LatLon; radius::Real=EARTH_RADIUS_METERS)
    r = Float64(radius)
    isfinite(r) && r > 0 || throw(ArgumentError("radius must be a finite positive value"))
    δ12 = haversine_distance(start, finish; radius=r) / r
    δ12 > sqrt(eps(Float64)) || throw(ArgumentError("start and finish must be distinct"))
    δ13 = haversine_distance(start, point; radius=r) / r
    θ13, θ12 = _radians(initial_bearing(start, point)), _radians(initial_bearing(start, finish))
    δxt = asin(clamp(sin(δ13) * sin(θ13 - θ12), -1.0, 1.0))
    δat = acos(clamp(cos(δ13) / cos(δxt), -1.0, 1.0))
    cos(θ13 - θ12) < 0 && (δat = -δat)
    if δat < 0
        haversine_distance(point, start; radius=r)
    elseif δat > δ12
        haversine_distance(point, finish; radius=r)
    else
        abs(δxt) * r
    end
end
