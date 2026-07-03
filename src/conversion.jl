const SAMPLE_COLUMNS = (:chain, :draw)
const _DD = InferenceObjects.DimensionalData
const _Tables = InferenceObjects.Tables
const _GridPosition = PairPlots.Makie.GridPosition
const _GridSubposition = PairPlots.Makie.GridSubposition

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

function _validate_scalar_dataset!(dataset)
    for var_name in keys(dataset)
        array = dataset[var_name]
        value_type = Base.nonmissingtype(eltype(array))
        value_type <: Real || throw(
            ArgumentError(
                "variable $var_name has non-real element type $(eltype(array)); " *
                "PairPlots requires real-valued variables",
            ),
        )

        dim_names = Symbol.(_DD.name.(_DD.dims(array)))
        extra_dims = filter(name -> name ∉ SAMPLE_COLUMNS, dim_names)
        isempty(extra_dims) && continue
        throw(
            ArgumentError(
                "variable $var_name has dimensions $(_available(collect(extra_dims))); " *
                "only scalar variables (chain and draw only) are supported",
            ),
        )
    end
    return dataset
end

function _plot_table(dataset)
    cols = _Tables.columntable(dataset)
    return NamedTuple(
        name => cols[name] for name in _Tables.columnnames(cols) if name ∉ SAMPLE_COLUMNS
    )
end

function _select_dataset(
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

    return _validate_scalar_dataset!(selected_dataset)
end

"""
    pairplot(idata::InferenceData; group=:posterior, var_names=nothing, coords=(;), kwargs...)

Plot scalar variables from an `InferenceData` group with PairPlots. Sample
identifier columns (`chain` and `draw`) are excluded automatically.
"""
function pairplot(
    idata::InferenceData;
    group::Symbol=:posterior,
    var_names=nothing,
    coords=(;),
    pairplots_kwargs...,
)
    selected = _select_dataset(idata; group, var_names, coords)
    return PairPlots.pairplot(_plot_table(selected); pairplots_kwargs...)
end

function _pairplot_grid(
    layout,
    idata::InferenceData;
    group::Symbol=:posterior,
    var_names=nothing,
    coords=(;),
    pairplots_kwargs...,
)
    selected = _select_dataset(idata; group, var_names, coords)
    return PairPlots.pairplot(layout, _plot_table(selected); pairplots_kwargs...)
end

function pairplot(
    layout::_GridPosition,
    idata::InferenceData;
    kwargs...,
)
    return _pairplot_grid(layout, idata; kwargs...)
end

function pairplot(
    layout::_GridSubposition,
    idata::InferenceData;
    kwargs...,
)
    return _pairplot_grid(layout, idata; kwargs...)
end
