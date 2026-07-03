using ArviZExampleData: load_example_data
using ArviZPairPlots: pairplot
using CairoMakie

idata = load_example_data("centered_eight")

globals_figure = pairplot(idata; var_names=[:mu, :tau])
CairoMakie.save(joinpath(@__DIR__, "centered_eight_globals.png"), globals_figure)
