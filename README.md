# Snappy.jl
[![Build Status](https://travis-ci.org/krm01/Snappy.jl.svg?branch=master)](https://travis-ci.org/krm01/Snappy.jl)
[![Build status](https://ci.appveyor.com/api/projects/status/vhvheji9o932cjde?svg=true)](https://ci.appveyor.com/project/krm01/snappy-jl)
[![codecov](https://codecov.io/gh/krm01/Snappy.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/krm01/Snappy.jl)

Julia implementation of the snappy compressor <https://github.com/google/snappy>, a fast compression library developed by Google.

## Usage
The compression and decompression functions operate on and return byte arrays, i.e. `Vector{UInt8}`. Two functions are exported: 

```julia
compress(input::Vector{UInt8})
```
```julia
uncompress(input::Vector{UInt8})
```
A `compress(input::String)` method is provided for convenience. 

## Performance
Soon there will be a chart here with numbers.