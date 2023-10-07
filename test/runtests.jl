using LifeSimulator, Dates
using LifeSimulator: LifeSimulator as LS
using LifeSimulator: BasicTermMemoized as BT
using DataFrames: DataFrame
using Test
using CondaPkg

@testset "LifeSimulator.jl" begin
    include("basiclife.jl")
    include("savings.jl")
end;
