include("../src/Snappy.jl")
include("libsnappy.jl")


using Snappy
using BenchmarkTools

# this is rough, sorry!

testfiles = Dict([
    "alice29.txt" => "txt",
    "html" => "html",
    "fireworks.jpeg" => "jpeg",
    "paper-100k.pdf" => "pdf",
    "urls.10K" => "urls",
    "sample-tweet.json" => "json"
])

reports = []
for file in keys(testfiles)
    gc()
    println("\n\n")
    println(" ==== sample file: $file")
    input = read("$(Base.source_dir())/testdata/$(file)")

    # warm up
    ccall_uncompress(ccall_compress(input));
    uncompress(compress(input));

    m1_compress = @benchmark compress($input)
    println(" ======== compress (Julia):")
    display(m1_compress)
    println("")
    m0_compress = @benchmark ccall_compress($input)
    println(" ======== compress (ccall):")
    display(m0_compress)
    println("")
    println("---------------------------")
    println(" ============ compress comparison (median):")
    j = judge(median(m1_compress), median(m0_compress))
    display(j)
    println("\n")
    julia_bps = length(input) / (median(m1_compress).time / 10^9)
    ccall_bps = length(input) / (median(m0_compress).time / 10^9)
    if julia_bps >= 1e9
        julia_pretty = "$(round(julia_bps / 2^30, 3)) GB/s"
    elseif julia_bps >= 1e8
        julia_pretty = "$(Int(floor(julia_bps / 2^20))) MB/s"
    else
        julia_pretty = "$(Int(floor(julia_bps / 2^10))) KB/s"
    end
    if ccall_bps >= 1e9
        ccall_pretty = "$(round(ccall_bps / 2^30, 3)) GB/s"
    elseif ccall_bps >= 1e8
        ccall_pretty = "$(Int(floor(ccall_bps / 2^20))) MB/s"
    else
        ccall_pretty = "$(Int(floor(ccall_bps / 2^10))) KB/s"
    end
    j_pretty = j.ratio.time > 1 ? "+$(round((j.ratio.time-1)*100,2))%" : "-$(round((1-j.ratio.time)*100,2))%"

    outline_a = "|$(testfiles[file])|$(length(input))|$julia_pretty|$ccall_pretty|$j_pretty"
    gc()
    output = compress(input);
    m1_uncompress = @benchmark uncompress($output)
    println(" ======== uncompress (Julia):")
    display(m1_uncompress)
    println("")
    output = ccall_compress(input);
    m0_uncompress = @benchmark ccall_uncompress($output)
    println(" ======== uncompress (ccall):")
    display(m0_uncompress)
    println("")
    println("---------------------------")
    println(" ============ uncompress comparison (median):")
    j = judge(median(m1_uncompress), median(m0_uncompress))
    display(j)
    println("\n")
    julia_bps = length(output) / (median(m1_uncompress).time / 10^9)
    ccall_bps = length(output) / (median(m0_uncompress).time / 10^9)
    if julia_bps >= 1e9
        julia_pretty = "$(round(julia_bps / 2^30, 3)) GB/s"
    elseif julia_bps >= 1e8
        julia_pretty = "$(Int(floor(julia_bps / 2^20))) MB/s"
    else
        julia_pretty = "$(Int(floor(julia_bps / 2^10))) KB/s"
    end
    if ccall_bps >= 1e9
        ccall_pretty = "$(round(ccall_bps / 2^30, 3)) GB/s"
    elseif ccall_bps >= 1e8
        ccall_pretty = "$(Int(floor(ccall_bps / 2^20))) MB/s"
    else
        ccall_pretty = "$(Int(floor(ccall_bps / 2^10))) KB/s"
    end
    j_pretty = j.ratio.time > 1 ? "+$(round((j.ratio.time-1)*100,2))%" : "-$(round((1-j.ratio.time)*100,2))%"

    outline_b = "|$julia_pretty|$ccall_pretty|$j_pretty|"
    println(outline_a * outline_b)
    push!(reports, outline_a*outline_b)
    println("==================================================")
end
println("final report:")
println(join(reports, '\n'))
