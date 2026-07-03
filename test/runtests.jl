using ArviZPairPlots
using InferenceObjects
using NCDatasets
import PairPlots
using Test

const DD = InferenceObjects.DimensionalData

function _axis_labels(fig)
    labels = String[]
    for axis in fig.content
        hasproperty(axis, :xlabel) && push!(labels, axis.xlabel[])
        hasproperty(axis, :ylabel) && push!(labels, axis.ylabel[])
    end
    return labels
end

@testset "ArviZPairPlots" begin
    @testset "scalar selection" begin
        idata = from_namedtuple(
            (
                alpha=reshape(collect(1.0:12.0), 6, 2),
                beta=reshape(collect(2.0:13.0), 6, 2),
            ),
        )

        table = ArviZPairPlots._plot_table(
            ArviZPairPlots._select_dataset(idata; var_names=[:alpha, :beta]),
        )
        @test Tuple(keys(table)) == (:alpha, :beta)
        @test length(table.alpha) == 12

        fig = pairplot(idata; var_names=[:alpha])
        @test "alpha" in _axis_labels(fig)
        @test "beta" ∉ _axis_labels(fig)
        @test "chain" ∉ _axis_labels(fig)
        @test "draw" ∉ _axis_labels(fig)
    end

    @testset "selection and normalization" begin
        posterior = (
            alpha=reshape(collect(1:8), 2, 2, 2),
            beta=reshape(collect(21:24), 2, 2),
        )
        prior = (
            alpha=reshape(collect(101:108), 2, 2, 2),
            beta=reshape(collect(121:124), 2, 2),
        )
        idata = from_namedtuple(
            posterior;
            prior,
            dims=(alpha=[:school],),
            coords=(school=["A", "B"],),
        )

        @test_throws ArgumentError pairplot(
            idata;
            group=:prior,
            var_names="alpha",
            coords=Dict("school" => DD.At(["B"])),
        )

        fig = pairplot(idata; var_names=[:beta])
        @test "beta" in _axis_labels(fig)

        scalar_idata = from_namedtuple(
            (
                beta=reshape(collect(21:24), 2, 2),
                alpha=reshape(collect(1:4), 2, 2),
            ),
        )
        ordered = ArviZPairPlots._plot_table(
            ArviZPairPlots._select_dataset(scalar_idata; var_names=[:beta, "alpha"]),
        )
        @test Tuple(keys(ordered)) == (:beta, :alpha)
    end

    @testset "dimensional variables rejected" begin
        idata = from_namedtuple(
            (theta=reshape(collect(1.0:24.0), 6, 2, 2),);
            dims=(theta=[:school],),
            coords=(school=["A", "B"],),
        )

        err = try
            pairplot(idata; var_names=:theta)
        catch exception
            exception
        end
        @test err isa ArgumentError
        @test occursin("only scalar variables", sprint(showerror, err))
        @test occursin("school", sprint(showerror, err))
    end

    @testset "validation" begin
        idata = from_namedtuple(
            (alpha=reshape(collect(1:4), 2, 2),);
            prior=(alpha=reshape(collect(5:8), 2, 2),),
        )

        err = try
            pairplot(idata; group=:missing_group)
        catch exception
            exception
        end
        @test err isa ArgumentError
        @test occursin("available groups", sprint(showerror, err))

        err = try
            pairplot(idata; var_names=:missing_var)
        catch exception
            exception
        end
        @test err isa ArgumentError
        @test occursin("available variables", sprint(showerror, err))

        @test_throws ArgumentError pairplot(idata; var_names=Symbol[])
        @test_throws ArgumentError pairplot(idata; var_names=[:alpha, :alpha])
        @test_throws ArgumentError pairplot(idata; coords=[])

        observed = from_namedtuple(
            (alpha=reshape(collect(1:4), 2, 2),);
            observed_data=(y=collect(1:3),),
            dims=(y=[:observation],),
        )
        @test_throws ArgumentError pairplot(observed; group=:observed_data)

        strings = InferenceData(
            ; posterior=namedtuple_to_dataset((label=reshape(["a", "b"], 2, 1),))
        )
        @test_throws ArgumentError pairplot(strings)

        reserved = from_namedtuple((chain=reshape(collect(1:2), 2, 1),))
        @test_throws ArgumentError pairplot(reserved)
    end

    @testset "PairPlots integration" begin
        idata = from_namedtuple(
            (
                alpha=reshape(collect(1.0:12.0), 6, 2),
                beta=reshape(collect(2.0:13.0), 6, 2),
            ),
        )
        fig = pairplot(idata; fullgrid=true, figure=(; fontsize=17))
        @test fig isa PairPlots.Makie.Figure
        @test fig.scene.theme[:fontsize][] == 17

        labels = _axis_labels(fig)
        @test "alpha" in labels
        @test "beta" in labels
        @test "chain" ∉ labels
        @test "draw" ∉ labels
    end

    @testset "GridLayout dispatch" begin
        idata = from_namedtuple(
            (
                alpha=reshape(collect(1.0:12.0), 6, 2),
                beta=reshape(collect(2.0:13.0), 6, 2),
            ),
        )
        fig = PairPlots.Makie.Figure()
        pairplot(fig[1, 1], idata; var_names=[:alpha, :beta])
        labels = _axis_labels(fig)
        @test "alpha" in labels
        @test "beta" in labels
        @test "chain" ∉ labels
        @test "draw" ∉ labels
    end

    @testset "NetCDF smoke test" begin
        source = from_namedtuple(
            (
                alpha=reshape(collect(1.0:6.0), 3, 2),
                beta=reshape(collect(11.0:16.0), 3, 2),
            ),
        )
        mktempdir() do directory
            path = joinpath(directory, "chains.nc")
            to_netcdf(source, path)
            loaded = from_netcdf(path)
            source_table = ArviZPairPlots._plot_table(ArviZPairPlots._select_dataset(source))
            loaded_table = ArviZPairPlots._plot_table(ArviZPairPlots._select_dataset(loaded))
            @test source_table == loaded_table
        end
    end
end
