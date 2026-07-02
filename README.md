# ArviZPairPlots.jl

[![CI](https://github.com/binado/ArvizPairPlots.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/binado/ArvizPairPlots.jl/actions/workflows/CI.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

`ArviZPairPlots.jl` connects
[`InferenceObjects.InferenceData`](https://julia.arviz.org/InferenceObjects/stable/)
to [`PairPlots.jl`](https://sefffal.github.io/PairPlots.jl/stable/). It converts an
inference-data group to a wide `DataFrame`, or plots it directly while combining
chains.

## Installation

Once registered, install the package with:

```julia
using Pkg
Pkg.add("ArviZPairPlots")
```

ArviZPairPlots requires Julia 1.11 or later.

## Usage

NetCDF loading remains explicit so that `NCDatasets.jl` is an optional I/O
dependency:

```julia
using ArviZPairPlots, InferenceObjects, NCDatasets

idata = from_netcdf("chains.nc")
fig = pairplot(idata; var_names=[:μ, :τ])
```

The conversion to a wide `DataFrame` is exposed separately, so the same data can
be inspected or fed into other tools:

```julia
df = inference_data_to_dataframe(idata)
```

Both functions accept `group`, `var_names`, and `coords`. Variable names may be
symbols or strings. Coordinate selectors are forwarded to InferenceObjects:

```julia
using DimensionalData: At

df = inference_data_to_dataframe(
    idata;
    group=:prior,
    var_names=["θ", "τ"],
    coords=(school=At(["Choate", "Deerfield"]),),
)
```

The resulting data frame begins with `chain` and `draw`. Variables with other
dimensions are expanded into columns such as `θ[school=Choate]`. These sample
identifier columns are removed before data is delegated to PairPlots, and all
other `pairplot` keywords are forwarded unchanged.

For a custom Makie layout, convert explicitly and pass the table to a grid
position:

```julia
using CairoMakie
using DataFrames: Not, select

df = inference_data_to_dataframe(idata)
fig = Figure()
pairplot(fig[1, 1], select(df, Not([:chain, :draw])))
fig
```

## Worked example

The centered-eight example loads an `InferenceData` object with
[`ArviZExampleData.jl`](https://julia.arviz.org/ArviZExampleData/stable/) and
saves one pair plot for the global parameters and another that also includes
two school-level parameters. From the repository root, instantiate its separate
environment and run the script:

```sh
julia --project=examples -e 'using Pkg; Pkg.instantiate()'
julia --project=examples examples/centered_eight.jl
```

The first run downloads and caches the example data. The generated images are
written to `examples/centered_eight_globals.png` and
`examples/centered_eight_schools.png`.

## Scope

Version 0.1 combines chains and supports exact variable selection. Divergence
highlighting, chain-split series, regular-expression variable filtering, direct
GridLayout dispatch for `InferenceData`, and `pairplot(path)` are intentionally
outside the initial API.

## License

MIT
