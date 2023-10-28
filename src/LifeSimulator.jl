module LifeSimulator

using StructEquality: @struct_hash_equal
using Dates
using Accessors: @set
using CSV
using DataFrames
using Random
using Reexport
using DocStringExtensions

@template (FUNCTIONS, METHODS, MACROS) =
    """
    $(DOCSTRING)
    $(TYPEDSIGNATURES)
    """

@template TYPES =
    """
    $(DOCSTRING)
    $(TYPEDEF)
    $(TYPEDSIGNATURES)
    $(TYPEDFIELDS)
    """

data_file(file) = joinpath(@__DIR__, "data", joinpath(split(file, '/')...))
function read_csv(file)
  !isabspath(file) && (file = data_file(file))
  CSV.read(file, DataFrame)
end

include("policy.jl")
include("mortality.jl")
include("lapse.jl")
include("model.jl")
include("simulation.jl")
include("cashflow.jl")
include("show.jl")

include("BasicTermMemoized.jl")
@reexport using .BasicTermMemoized

export
  Sex, MALE, FEMALE,
  Policy, policies_from_csv,
  PolicySet, policy_count,
  MortalityModel, annual_mortality_rate, monthly_mortality_rate,
  ConstantMortality, TabularMortality, PolicyVaryingMortality,
  LapseModel, annual_lapse_rate, monthly_lapse_rate,
  ConstantLapse, TimeVaryingLapse, PolicyVaryingLapse,
  Model, TermLifeModel, UniversalLifeModel, LifelibBasiclife, LifelibSavings, investment_rate, brownian_motion, estimate_premiums,
  Simulation, SimulationEvents, SimulationResult, SHOW_PROGRESS, next!, simulate, simulate!, simulation_range,
  CashFlow, ntimesteps, use_policies!
end
