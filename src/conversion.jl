const SAMPLE_COLUMNS = [:chain, :draw]
const _DD = InferenceObjects.DimensionalData

_available(values) = isempty(values) ? "(none)" : join(string.(values), ", ")

function _normalize_var_names(var_names, available::Vector{Symbol})
    var_names === nothing && return copy(available)

    requested = if var_names isa Union{Symbol,AbstractString}
        [Symbol(var_names)]
    elseif var_names isa Union{AbstractVector,Tuple}
        all(name -> name isa Union{Symbol,AbstractString}, var_names) || throw(
            ArgumentError("var_names must contain only symbols or strings"),
        )
        Symbol.(var_names)
    else
        throw(
            ArgumentError(
                "var_names must be a symbol, string, vector, tuple, or nothing",
            ),
        )
    end

    isempty(requested) && throw(ArgumentError("var_names selects no variables"))
    allunique(requested) || throw(ArgumentError("var_names contains duplicate variables"))

    missing_names = filter(name -> name ∉ available, requested)
    isempty(missing_names) || throw(
        ArgumentError(
            "variables $(_available(missing_names)) were not found; available variables: " *
            _available(available),
        ),
    )
    return requested
end

function _normalize_coords(coords)
    coords isa Union{NamedTuple,AbstractDict} || throw(
        ArgumentError("coords must be a NamedTuple or dictionary"),
    )

    normalized = Pair{Symbol,Any}[]
    for (name, selector) in pairs(coords)
        name isa Union{Symbol,AbstractString} || throw(
            ArgumentError("coordinate names must be symbols or strings"),
        )
        push!(normalized, Symbol(name) => selector)
    end
    names = first.(normalized)
    allunique(names) || throw(
        ArgumentError("coords contains duplicate names after string/symbol normalization"),
    )
    return (; normalized...)
end

function _coordinate_values(dim)
    return collect(_DD.val(_DD.lookup(dim)))
end

function _extra_index_combinations(sizes::Tuple)
    combinations = Tuple[]
    function visit(prefix::Tuple, dim_index::Int)
        if dim_index > length(sizes)
            push!(combinations, prefix)
            return
        end
        for index in 1:sizes[dim_index]
            visit((prefix..., index), dim_index + 1)
        end
    end
    visit((), 1)
    return combinations
end

function _column_name(var_name::Symbol, dim_names, coordinate_values)
    isempty(dim_names) && return var_name
    indices = join(
        ("$(dim)=$(value)" for (dim, value) in zip(dim_names, coordinate_values)),
        ", ",
    )
    return Symbol("$(var_name)[$indices]")
end

function _validate_sample_keys(frame::DataFrame, var_name::Symbol)
    nrow(frame) > 0 || throw(
        ArgumentError("variable $var_name contains no samples after selection"),
    )
    sample_keys = collect(zip(frame[!, :chain], frame[!, :draw]))
    allunique(sample_keys) || throw(
        ArgumentError("variable $var_name has duplicate (chain, draw) sample keys"),
    )
    return frame
end

function _variable_to_dataframe(array, var_name::Symbol)
    value_type = Base.nonmissingtype(eltype(array))
    value_type <: Real || throw(
        ArgumentError(
            "variable $var_name has non-real element type $(eltype(array)); " *
            "PairPlots requires real-valued variables",
        ),
    )

    dimensions = _DD.dims(array)
    dim_names = Symbol.(_DD.name.(dimensions))
    count(==(:chain), dim_names) == 1 && count(==(:draw), dim_names) == 1 || throw(
        ArgumentError("variable $var_name must contain exactly one chain and draw dimension"),
    )

    chain_dim = only(findall(==(:chain), dim_names))
    draw_dim = only(findall(==(:draw), dim_names))
    extra_dims = findall(name -> name ∉ SAMPLE_COLUMNS, dim_names)

    chain_values = _coordinate_values(dimensions[chain_dim])
    draw_values = _coordinate_values(dimensions[draw_dim])
    isempty(chain_values) && throw(
        ArgumentError("variable $var_name contains no chains after selection"),
    )
    isempty(draw_values) && throw(
        ArgumentError("variable $var_name contains no draws after selection"),
    )

    frame = DataFrame(
        chain=repeat(chain_values; inner=length(draw_values)),
        draw=repeat(draw_values; outer=length(chain_values)),
    )

    extra_sizes = Tuple(size(array, dim) for dim in extra_dims)
    combinations = _extra_index_combinations(extra_sizes)
    isempty(combinations) && throw(
        ArgumentError("variable $var_name contains no coordinate values after selection"),
    )
    extra_names = dim_names[extra_dims]
    extra_coordinates = [_coordinate_values(dimensions[dim]) for dim in extra_dims]
    extra_positions = zeros(Int, length(dim_names))
    for (position, dim) in enumerate(extra_dims)
        extra_positions[dim] = position
    end

    for combination in combinations
        coordinate_values = map(getindex, extra_coordinates, combination)
        column_name = _column_name(var_name, extra_names, coordinate_values)
        column_name in propertynames(frame) && throw(
            ArgumentError("generated column name collision: $column_name"),
        )
        values = [
            begin
                indices = ntuple(length(dim_names)) do dim
                    dim == chain_dim && return chain_index
                    dim == draw_dim && return draw_index
                    return combination[extra_positions[dim]]
                end
                array[indices...]
            end for chain_index in eachindex(chain_values) for
            draw_index in eachindex(draw_values)
        ]
        frame[!, column_name] = values
    end

    sort!(frame, SAMPLE_COLUMNS)
    return _validate_sample_keys(frame, var_name)
end

function _merge_variable_frame!(result::DataFrame, frame::DataFrame, var_name::Symbol)
    if !isequal(result[!, :chain], frame[!, :chain]) ||
        !isequal(result[!, :draw], frame[!, :draw])
        throw(
            ArgumentError(
                "variable $var_name has (chain, draw) sample keys that do not match " *
                "the other selected variables",
            ),
        )
    end

    for name in propertynames(frame)[3:end]
        name in propertynames(result) && throw(
            ArgumentError("generated column name collision: $name"),
        )
        result[!, name] = frame[!, name]
    end
    return result
end

"""
    inference_data_to_dataframe(
        idata::InferenceData;
        group::Symbol=:posterior,
        var_names=nothing,
        coords=(;),
    ) -> DataFrame

Convert variables in an inference-data group to a wide data frame. The first two
columns identify each sample (`chain` and `draw`); non-sample dimensions are
expanded into deterministically named columns.
"""
function inference_data_to_dataframe(
    idata::InferenceData;
    group::Symbol=:posterior,
    var_names=nothing,
    coords=(;),
)
    groups = collect(propertynames(idata))
    group in groups || throw(
        ArgumentError(
            "group $group was not found; available groups: " * _available(groups),
        ),
    )

    dataset = idata[group]
    available_vars = collect(Symbol, keys(dataset))
    selected_vars = _normalize_var_names(var_names, available_vars)
    any(name -> name in SAMPLE_COLUMNS, selected_vars) && throw(
        ArgumentError("variable names chain and draw are reserved for sample identifiers"),
    )

    selected_dataset = dataset[Tuple(selected_vars)]
    normalized_coords = _normalize_coords(coords)
    if !isempty(normalized_coords)
        selected_dataset = getindex(selected_dataset; normalized_coords...)
    end

    result = nothing
    for var_name in selected_vars
        frame = _variable_to_dataframe(selected_dataset[var_name], var_name)
        if result === nothing
            result = frame
        else
            _merge_variable_frame!(result, frame, var_name)
        end
    end

    result === nothing && throw(ArgumentError("selection contains no variables"))
    return result::DataFrame
end

"""
    pairplot(idata::InferenceData; group=:posterior, var_names=nothing, coords=(;), kwargs...)

Convert an `InferenceData` group and plot its variables with PairPlots. Sample
identifier columns are excluded from the plot.
"""
function pairplot(
    idata::InferenceData;
    group::Symbol=:posterior,
    var_names=nothing,
    coords=(;),
    pairplots_kwargs...,
)
    df = inference_data_to_dataframe(idata; group, var_names, coords)
    return PairPlots.pairplot(select(df, Not(SAMPLE_COLUMNS)); pairplots_kwargs...)
end
