module BasicTermMemoized

using DataFrames
using CSV
using Memoize
using Dates
using StructEquality: @struct_hash_equal
using ..LifeSimulator: MortalityModel, read_csv, Policy, PolicySet, policies_from_csv, policy_count
import ..LifeSimulator: annual_mortality_rate

const final_timestep = Ref{Int}(240)
duration(t::Int) = t ÷ 12

include("basic_mortality.jl")
include("basic_term.jl")

const sum_assured = Ref{Vector{Int}}()
const issue_age = Ref{Vector{Int}}()
const current_policies_term = Ref{Vector{Int}}()
const basic_term_policies = Ref{Vector{PolicySet}}()
const basic_mortality = Ref{BasicMortality}()
set_basic_term_policies!(policies_from_csv("basic_term/model_point_table_10K.csv"))

export
  empty_memoization_caches!,
  set_basic_term_policies!,

  pv_claims,
  pv_premiums,
  pv_commissions,
  pv_expenses,
  pv_net_cf,

  result_pv,
  result_cf

end # module
