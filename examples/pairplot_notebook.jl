### A Pluto.jl notebook ###
# v0.20.4

using Markdown
using InteractiveUtils

# ╔═╡ 6c3b2ad8-7623-11f1-9de6-61b488dbfaeb
md"""
# ArviZ pair plot from NetCDF

This notebook loads a NetCDF file into an `InferenceData`, builds a pair plot with
`ArviZPairPlots.pairplot`, and saves it to an output file. Adjust the paths and
selected variables in the **Configuration** cell below.
"""

# ╔═╡ 6c3d6262-7623-11f1-8a28-253c4620f101
begin
    import Pkg
    Pkg.activate(@__DIR__)
    Pkg.instantiate()
    using ArviZPairPlots: pairplot
    using InferenceObjects: from_netcdf
    using NCDatasets
    using CairoMakie
end

# ╔═╡ 6c3d6316-7623-11f1-8a06-9d7197fb1556
md"## Configuration"

# ╔═╡ 6c3d632a-7623-11f1-a7f8-cf310414206d
begin
    input_file = joinpath(@__DIR__, "chains.nc")
    output_file = joinpath(@__DIR__, "pairplot.png")
    var_names = [:mu, :tau]
    group = :posterior
end

# ╔═╡ 6c3d6340-7623-11f1-bf42-257a3246b9fa
idata = from_netcdf(input_file)

# ╔═╡ 6c3d6348-7623-11f1-92fe-1d3c886b5d66
figure = pairplot(idata; group, var_names)

# ╔═╡ 6c3d6352-7623-11f1-81cd-db3ec039161a
CairoMakie.save(output_file, figure)

# ╔═╡ Cell order:
# ╟─6c3b2ad8-7623-11f1-9de6-61b488dbfaeb
# ╠═6c3d6262-7623-11f1-8a28-253c4620f101
# ╟─6c3d6316-7623-11f1-8a06-9d7197fb1556
# ╠═6c3d632a-7623-11f1-a7f8-cf310414206d
# ╠═6c3d6340-7623-11f1-bf42-257a3246b9fa
# ╠═6c3d6348-7623-11f1-92fe-1d3c886b5d66
# ╠═6c3d6352-7623-11f1-81cd-db3ec039161a
