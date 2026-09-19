using MapRelatedOperation

function elapsed(label::AbstractString, iterations::Integer, operation::Function)
    operation() # Compile before measuring.
    duration = @elapsed for _ in 1:iterations
        operation()
    end
    println("$(label): $(round(duration * 1e9 / iterations; digits=1)) ns/op")
end

origin = LatLon(-6.2088, 106.8456)
destination_point = LatLon(1.3521, 103.8198)
route = [origin, LatLon(-3.0, 105.0), destination_point]

elapsed("haversine_distance", 100_000) do
    haversine_distance(origin, destination_point)
end
elapsed("destination", 100_000) do
    destination(origin, 315, 1_000)
end
elapsed("route_length (three points)", 50_000) do
    route_length(route)
end
elapsed("Web Mercator projection", 100_000) do
    web_mercator_project(origin)
end
elapsed("polyline encoding", 50_000) do
    polyline_encode(route)
end
