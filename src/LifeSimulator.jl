module LifeSimulator

using StructEquality: @struct_hash_equal
using Dates
using Accessors: @set
using CSV
using DataFrames
using Random
using Reexport

data_file(file) = joinpath(@__DIR__, "data", joinpath(split(file, '/')...))
function read_csv(file)
  !isabspath(file) && (file = data_file(file))
  CSV.read(file, DataFrame)
end

include("mortality.jl")
include("policy.jl")
include("model.jl")
include("simulation.jl")
include("cashflow.jl")

include("BasicTermMemoized.jl")
@reexport using .BasicTermMemoized

export
  Sex, MALE, FEMALE,
  Policy, policies_from_csv,
  PolicySet, policy_count,
  MortalityModel, ConstantMortality, BasicMortality,
  Model, TermLifeModel, UniversalLifeModel, LifelibBasiclife, LifelibSavings, investment_rate, brownian_motion,
  Simulation, SimulationEvents, SimulationResult, SHOW_PROGRESS, next!, simulate, simulate!, simulation_range,
  CashFlow, ntimesteps, use_policies!
end
