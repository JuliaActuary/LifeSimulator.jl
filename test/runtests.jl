using LifeSimulator, Dates
using LifeSimulator: LifeSimulator as LS
using DataFrames: DataFrame
using Test
using CondaPkg

@testset "LifeSimulator.jl" begin
    include("basiclife.jl")
    include("savings.jl")
end;
