using Test
using Random
using MapRelatedOperation

@testset "coordinates" begin
    @test LatLon(0, 0) == LatLon(0.0, 0.0)
    @test_throws ArgumentError LatLon(91, 0)
    @test_throws ArgumentError LatLon(0, 180)
    @test normalize_longitude(190) == -170.0
end

@testset "spherical calculations" begin
    origin = LatLon(0, 0)
    east = LatLon(0, 1)
    @test haversine_distance(origin, east) ≈ 111_195.08 atol=0.1
    @test initial_bearing(origin, east) ≈ 90.0 atol=1e-10
    @test destination(origin, 90, 111_195.08).latitude ≈ 0.0 atol=1e-5
    @test destination(origin, 90, 111_195.08).longitude ≈ 1.0 atol=1e-5
    @test route_length([origin, east]) ≈ haversine_distance(origin, east)
    @test route_length(LatLon[]) == 0.0
end

@testset "bounds" begin
    bounds = bounding_box([LatLon(10, 170), LatLon(-5, -175)])
    @test bounds.south == -5.0
    @test bounds.north == 10.0
    @test bounds.west == 170.0
    @test bounds.east == -175.0
    @test contains(bounds, LatLon(0, 179))
    @test contains(bounds, LatLon(0, -179))
    @test !contains(bounds, LatLon(0, 0))
    @test_throws ArgumentError bounding_box(LatLon[])
end

@testset "integration contracts" begin
    struct ExampleProvider <: AbstractMapProvider end
    provider = ExampleProvider()
    @test_throws MethodError geocode(provider, "Example")
    result = GeocodingResult(LatLon(1, 2), "Example"; metadata=Dict("id" => 1))
    @test result.display_name == "Example"
    response = Route([LatLon(0, 0), LatLon(0, 1)]; duration=20)
    @test response.duration == 20.0
end

@testset "additional map tools" begin
    points = [LatLon(38.5, -120.2), LatLon(40.7, -120.95), LatLon(43.252, -126.453)]
    encoded = polyline_encode(points)
    @test encoded == "_p~iF~ps|U_ulLnnqC_mqNvxq`@"
    @test polyline_decode(encoded) == points
    @test_throws ArgumentError polyline_decode("_")

    bounds = GeoBounds(-1, 170, 1, -170)
    @test crosses_antimeridian(bounds)
    @test midpoint(LatLon(0, 0), LatLon(0, 2)).longitude ≈ 1.0

    map_url = static_map_url(LatLon(-6.2088, 106.8456); api_key="secret")
    @test occursin("center=-6.2088%2C106.8456", map_url)
    @test occursin("mode=walking", directions_url(LatLon(0, 0), LatLon(1, 1); api_key="secret", mode=:walking))
    @test occursin("q=Monas%20Jakarta", geocode_url("Monas Jakarta"))
end

@testset "geodesic extensions" begin
    origin, east = LatLon(0, 0), LatLon(0, 2)
    @test interpolate(origin, east, 0.5).longitude ≈ 1.0 atol=1e-10
    @test interpolate(origin, east, 0) == origin
    @test interpolate(origin, east, 1) == east
    @test_throws ArgumentError interpolate(origin, east, 1.1)
    @test abs(cross_track_distance(LatLon(1, 1), origin, east)) ≈ 111_195 atol=100
    @test_throws ArgumentError cross_track_distance(origin, origin, origin)
    @test segment_distance(LatLon(1, 1), origin, east) ≈ 111_195 atol=100
    endpoint_outside = LatLon(1, 3)
    @test segment_distance(endpoint_outside, origin, east) ≈ haversine_distance(endpoint_outside, east) atol=1e-8
    @test_throws ArgumentError segment_distance(origin, origin, origin)
end

@testset "Web Mercator and tiles" begin
    jakarta = LatLon(-6.2088, 106.8456)
    world = web_mercator_project(jakarta)
    roundtrip = web_mercator_unproject(world.x, world.y)
    @test roundtrip.latitude ≈ jakarta.latitude atol=1e-12
    @test roundtrip.longitude ≈ jakarta.longitude atol=1e-12
    @test tile_indices(LatLon(0, 0), 1) == (1, 1)
    @test tile_bounds(1, 1, 1) == GeoBounds(-85.0511287798066, 0, 0, -180)
    @test_throws DomainError web_mercator_project(LatLon(86, 0))
    @test_throws ArgumentError tile_indices(LatLon(0, 0), 31)
    @test tile_center(1, 1, 1) == LatLon(-66.51326044311186, 90)
    @test ground_resolution(0, 0) ≈ 156_543.03392804097 atol=1e-8
    @test ground_resolution(60, 0) ≈ ground_resolution(0, 0) / 2 atol=1e-8
    @test_throws DomainError ground_resolution(86, 5)
    @test_throws ArgumentError ground_resolution(0, 5; tile_size=0)
end

@testset "validation and edge cases" begin
    @test_throws ArgumentError haversine_distance(LatLon(0, 0), LatLon(0, 1); radius=0)
    @test_throws ArgumentError destination(LatLon(0, 0), 90, -1)
    @test destination(LatLon(0, 179), 90, 222_390).longitude ≈ -179 atol=1e-4
    @test !crosses_antimeridian(GeoBounds(-1, -1, 1, 1))
    @test_throws ArgumentError midpoint(LatLon(0, 0), LatLon(0, -180))
    @test polyline_decode(polyline_encode([LatLon(-10.123456, 20.654321)]; precision=6); precision=6) == [LatLon(-10.123456, 20.654321)]
    @test_throws ArgumentError polyline_decode("\x01")
    @test_throws DomainError static_map_url(LatLon(0, 0); api_key="x", zoom=23)
    @test_throws ArgumentError directions_url(LatLon(0, 0), LatLon(1, 1); api_key="x", mode=:flying)
    @test_throws DomainError geocode_url("test"; limit=0)
    @test_throws ArgumentError Route(LatLon[]; duration=-1)
end

@testset "randomized geographic invariants" begin
    rng = MersenneTwister(0)
    for _ in 1:250
        point = LatLon(
            rand(rng) * 2 * WEB_MERCATOR_MAX_LATITUDE - WEB_MERCATOR_MAX_LATITUDE,
            rand(rng) * 360 - 180,
        )
        roundtrip = web_mercator_unproject(values(web_mercator_project(point))...)
        @test roundtrip.latitude ≈ point.latitude atol=1e-11
        @test roundtrip.longitude ≈ point.longitude atol=1e-11
        @test haversine_distance(point, point) == 0.0

        points = [point, LatLon(rand(rng) * 180 - 90, rand(rng) * 360 - 180), LatLon(rand(rng) * 180 - 90, rand(rng) * 360 - 180)]
        bounds = bounding_box(points)
        @test all(contains(bounds, candidate) for candidate in points)

        zoom = rand(rng, 0:20)
        x, y = tile_indices(point, zoom)
        @test contains(tile_bounds(x, y, zoom), tile_center(x, y, zoom))
    end
end
