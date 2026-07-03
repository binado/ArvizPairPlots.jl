# ArviZPairPlots.jl

[![CI](https://github.com/binado/ArvizPairPlots.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/binado/ArvizPairPlots.jl/actions/workflows/CI.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

`ArviZPairPlots.jl` connects
[`InferenceObjects.InferenceData`](https://julia.arviz.org/InferenceObjects/stable/)
to [`PairPlots.jl`](https://sefffal.github.io/PairPlots.jl/stable/). It plots
scalar inference-data groups directly through the Tables.jl interface, while
handling group selection, variable filtering, and automatic removal of sample
identifier columns.

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

`pairplot` accepts `group`, `var_names`, and `coords`. Variable names may be
symbols or strings. Coordinate selectors are forwarded to InferenceObjects:

```julia
using DimensionalData: At

fig = pairplot(
    idata;
    group=:prior,
    var_names=["θ", "τ"],
)
```

Sample identifier columns (`chain` and `draw`) are excluded automatically before
data is passed to PairPlots. All other `pairplot` keywords are forwarded
unchanged.

For a custom Makie layout, pass a grid position as the first argument:

```julia
using CairoMakie

fig = Figure()
pairplot(fig[1, 1], idata; var_names=[:μ, :τ])
fig
```

To inspect tabular data directly, use InferenceObjects' native Tables interface or
convert with `DataFrame(idata.posterior)` from DataFrames.jl.

## Worked example

The centered-eight example loads an `InferenceData` object with
[`ArviZExampleData.jl`](https://julia.arviz.org/ArviZExampleData/stable/) and
saves a pair plot for the global parameters. From the repository root,
instantiate its separate environment and run the script:

```sh
julia --project=examples -e 'using Pkg; Pkg.instantiate()'
julia --project=examples examples/centered_eight.jl
```

The first run downloads and caches the example data. The generated image is
written to `examples/centered_eight_globals.png`.

## Scope

Version 0.2 plots scalar variables only (chain and draw dimensions). Variables
with additional dimensions are rejected with an explicit error. Divergence
highlighting, chain-split series, regular-expression variable filtering, and
`pairplot(path)` are intentionally outside the API.

Breaking changes from 0.1:

- Removed `inference_data_to_dataframe` and `drop_sample_columns`
- Removed dimensional variable flattening to columns such as `θ[school=Choate]`

## License

MIT
