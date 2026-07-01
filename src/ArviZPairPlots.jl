module ArviZPairPlots

using DataFrames: DataFrame, Not, nrow, select, sort!
import InferenceObjects
using InferenceObjects: InferenceData
import PairPlots
import PairPlots: pairplot

export inference_data_to_dataframe, pairplot

include("conversion.jl")

end
