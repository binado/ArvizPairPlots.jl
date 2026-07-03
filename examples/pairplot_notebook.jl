### A Pluto.jl notebook ###
# v1.0.1

using Markdown
using InteractiveUtils

# ╔═╡ 6c3d6262-7623-11f1-8a28-253c4620f101
begin
    import Pkg
    Pkg.activate(@__DIR__)
    Pkg.instantiate()
    using ArviZPairPlots: pairplot
    using InferenceObjects: from_netcdf
    using NCDatasets
    using CairoMakie
    using LaTeXStrings
    import ArviZPairPlots.PairPlots
end

# ╔═╡ 6c3b2ad8-7623-11f1-9de6-61b488dbfaeb
md"""
# ArviZ pair plot from NetCDF

This notebook loads a NetCDF file into an `InferenceData`, builds a pair plot with
`ArviZPairPlots.pairplot`, and saves it to an output file.

Adjust the **Configuration** cell below to set:

- input/output paths and selected variables
- optional truth values (`truths`; set to `nothing` to omit truth lines)
- LaTeX axis labels (`axis_labels`)
"""

# ╔═╡ 6c3d6316-7623-11f1-8a06-9d7197fb1556
md"## Configuration"

# ╔═╡ 6c3d632a-7623-11f1-a7f8-cf310414206d
begin
    input_file = joinpath(@__DIR__, "../data/mcmc-H0-gamma-kappa-z_peak-det=S2,R2-seed42-20260630-084129.nc")
    output_file = joinpath(@__DIR__, "pairplot.png")
    var_names = [:H0, :gamma, :kappa, :z_peak]
    group = :posterior

    # Set to nothing to omit truth lines
    truths = (;
        H0 = 70.0,
        gamma = 3.0,
        kappa = 2.0,
        z_peak = 1.5,
    )

    axis_labels = Dict(
        :H0 => L"H_0",
        :gamma => L"\gamma",
        :kappa => L"\kappa",
        :z_peak => L"z_{\mathrm{peak}}",
    )
end

# ╔═╡ 6c3d6338-7623-11f1-9a12-4b8e7c1d2f30
begin
    import InferenceObjects.Tables as Tables

    const SAMPLE_COLUMNS = (:chain, :draw)

    function plot_table(idata; group=:posterior, var_names)
        cols = Tables.columntable(idata[group][Tuple(var_names)])
        return NamedTuple(
            name => cols[name]
            for name in Tables.columnnames(cols)
            if name ∉ SAMPLE_COLUMNS
        )
    end
end

# ╔═╡ 6c3d6340-7623-11f1-bf42-257a3246b9fa
idata = from_netcdf(input_file)

# ╔═╡ 6c3d6348-7623-11f1-92fe-1d3c886b5d66
begin
    selected_labels = Dict(
        name => axis_labels[name] for name in var_names if haskey(axis_labels, name)
    )

    figure = if truths === nothing
        pairplot(idata; group, var_names, labels=selected_labels)
    else
        selected_truths = NamedTuple(
            name => truths[name] for name in var_names if haskey(truths, name)
        )
        table = plot_table(idata; group, var_names)
        PairPlots.pairplot(table, PairPlots.Truth(selected_truths); labels=selected_labels)
    end
end

# ╔═╡ 6c3d6352-7623-11f1-81cd-db3ec039161a
CairoMakie.save(output_file, figure)

# ╔═╡ Cell order:
# ╟─6c3b2ad8-7623-11f1-9de6-61b488dbfaeb
# ╠═6c3d6262-7623-11f1-8a28-253c4620f101
# ╟─6c3d6316-7623-11f1-8a06-9d7197fb1556
# ╠═6c3d632a-7623-11f1-a7f8-cf310414206d
# ╠═6c3d6338-7623-11f1-9a12-4b8e7c1d2f30
# ╠═6c3d6340-7623-11f1-bf42-257a3246b9fa
# ╠═6c3d6348-7623-11f1-92fe-1d3c886b5d66
# ╠═6c3d6352-7623-11f1-81cd-db3ec039161a
