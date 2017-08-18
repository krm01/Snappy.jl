include("../src/Snappy.jl")

using Snappy
using Base.Test

@show pwd()
@testset "round_trip_tests" begin

    testfiles = [
        "alice29.txt",
        "asyoulik.txt",
        "html",
        "html_x_4",
        "kppkn.gtb",
        "lcet10.txt",

        # these guys are failing
        "fireworks.jpeg",
        "geo.protodata",
        "paper-100k.pdf",
        "plrabn12.txt",
        "urls.10K",
    ]

    for file in testfiles
        raw = read("$(pwd())/test/testdata/$(file)")
        a = compress(raw)
        b = uncompress(a)

        @test hash(b) == hash(raw);
    end
end

