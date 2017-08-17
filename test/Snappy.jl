include("../src/Snappy.jl")
include("../src/internal.jl")

using Snappy
using Base.Test

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

    for file in files
        raw = read("$(@__DIR__)/testdata/$(file)")
        a = compress(raw)
        b = uncompress(a)

        @test hash(b) == hash(raw);
    end
end
