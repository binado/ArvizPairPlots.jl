using ArviZPairPlots
using DataFrames
using InferenceObjects
using NCDatasets
import PairPlots
using Test

const DD = InferenceObjects.DimensionalData

@testset "ArviZPairPlots" begin
    @testset "scalar and dimensional variables" begin
        scalar = reshape(collect(1:6), 3, 2)
        vector = reshape(collect(11:22), 3, 2, 2)
        matrix = reshape(collect(101:124), 3, 2, 2, 2)
        idata = from_namedtuple(
            (; scalar, vector, matrix);
            dims=(vector=[:school], matrix=[:feature, :class]),
            coords=(school=["Choate", "Deerfield"], feature=["x", "y"], class=["A", "B"]),
        )

        df = inference_data_to_dataframe(idata)

        @test propertynames(df) == [
            :chain,
            :draw,
            :scalar,
            Symbol("vector[school=Choate]"),
            Symbol("vector[school=Deerfield]"),
            Symbol("matrix[feature=x, class=A]"),
            Symbol("matrix[feature=x, class=B]"),
            Symbol("matrix[feature=y, class=A]"),
            Symbol("matrix[feature=y, class=B]"),
        ]
        @test df.chain == [1, 1, 1, 2, 2, 2]
        @test df.draw == [1, 2, 3, 1, 2, 3]
        @test df.scalar == collect(1:6)
        @test df[!, Symbol("vector[school=Choate]")] == collect(11:16)
        @test df[!, Symbol("vector[school=Deerfield]")] == collect(17:22)
        @test df[!, Symbol("matrix[feature=x, class=A]")] == collect(101:106)
        @test df[!, Symbol("matrix[feature=x, class=B]")] == collect(113:118)
        @test df[!, Symbol("matrix[feature=y, class=A]")] == collect(107:112)
        @test df[!, Symbol("matrix[feature=y, class=B]")] == collect(119:124)

        # Regression: a scalar parameter is not expanded or duplicated merely because
        # another parameter has coordinate dimensions.
        @test size(df) == (6, 9)
        @test count(==(:scalar), propertynames(df)) == 1
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

        df = inference_data_to_dataframe(
            idata;
            group=:prior,
            var_names="alpha",
            coords=Dict("school" => DD.At(["B"])),
        )
        @test propertynames(df) == [:chain, :draw, Symbol("alpha[school=B]")]
        @test df[!, 3] == collect(105:108)

        ordered = inference_data_to_dataframe(idata; var_names=[:beta, "alpha"])
        @test propertynames(ordered)[3:end] == [
            :beta, Symbol("alpha[school=A]"), Symbol("alpha[school=B]")
        ]

        symbol_coord = inference_data_to_dataframe(
            idata; var_names=:alpha, coords=(school=DD.At(["A"]),)
        )
        @test propertynames(symbol_coord)[3] == Symbol("alpha[school=A]")
    end

    @testset "missing values" begin
        values = Matrix{Union{Missing,Float64}}(reshape(collect(1.0:6.0), 3, 2))
        values[2, 1] = missing
        idata = InferenceData(; posterior=namedtuple_to_dataset((value=values,)))
        df = inference_data_to_dataframe(idata)
        @test ismissing(df.value[2])
        @test nrow(df) == 6
    end

    @testset "validation" begin
        idata = from_namedtuple(
            (alpha=reshape(collect(1:4), 2, 2),);
            prior=(alpha=reshape(collect(5:8), 2, 2),),
        )

        err = try
            inference_data_to_dataframe(idata; group=:missing_group)
        catch exception
            exception
        end
        @test err isa ArgumentError
        @test occursin("available groups", sprint(showerror, err))

        err = try
            inference_data_to_dataframe(idata; var_names=:missing_var)
        catch exception
            exception
        end
        @test err isa ArgumentError
        @test occursin("available variables", sprint(showerror, err))

        @test_throws ArgumentError inference_data_to_dataframe(idata; var_names=Symbol[])
        @test_throws ArgumentError inference_data_to_dataframe(idata; var_names=[:alpha, :alpha])
        @test_throws ArgumentError inference_data_to_dataframe(idata; coords=[])

        observed = from_namedtuple(
            (alpha=reshape(collect(1:4), 2, 2),);
            observed_data=(y=collect(1:3),),
            dims=(y=[:observation],),
        )
        @test_throws ArgumentError inference_data_to_dataframe(
            observed; group=:observed_data
        )

        strings = InferenceData(
            ; posterior=namedtuple_to_dataset((label=reshape(["a", "b"], 2, 1),))
        )
        @test_throws ArgumentError inference_data_to_dataframe(strings)

        reserved = from_namedtuple((chain=reshape(collect(1:2), 2, 1),))
        @test_throws ArgumentError inference_data_to_dataframe(reserved)

        duplicate_keys = from_namedtuple(
            (alpha=reshape(collect(1:4), 2, 2),); coords=(chain=[1, 1],)
        )
        @test_throws ArgumentError inference_data_to_dataframe(duplicate_keys)

        collision_name = Symbol("theta[school=A]")
        collision_data = NamedTuple{(:theta, collision_name)}(
            (reshape(collect(1:2), 1, 1, 2), reshape([3], 1, 1))
        )
        collision = from_namedtuple(
            collision_data; dims=(theta=[:school],), coords=(school=["A", "B"],)
        )
        @test_throws ArgumentError inference_data_to_dataframe(collision)

        within_variable_collision = from_namedtuple(
            (theta=reshape(collect(1:2), 1, 1, 2),);
            dims=(theta=[:school],),
            coords=(school=Any[1, "1"],),
        )
        @test_throws ArgumentError inference_data_to_dataframe(within_variable_collision)

        left = DataFrame(chain=[1], draw=[1], a=[1.0])
        right = DataFrame(chain=[1], draw=[2], b=[2.0])
        @test_throws ArgumentError ArviZPairPlots._merge_variable_frame!(
            left, right, :b
        )
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

        labels = String[]
        for axis in fig.content
            hasproperty(axis, :xlabel) && push!(labels, axis.xlabel[])
            hasproperty(axis, :ylabel) && push!(labels, axis.ylabel[])
        end
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
            @test inference_data_to_dataframe(loaded) ==
                inference_data_to_dataframe(source)
        end
    end
end
