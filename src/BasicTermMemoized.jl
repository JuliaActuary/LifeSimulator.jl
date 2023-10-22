module BasicTermMemoized

using DataFrames
using CSV
using Memoize
using Dates
using StructEquality: @struct_hash_equal
using ..LifeSimulator: TabularMortality, read_csv, Policy, PolicySet, policies_from_csv, policy_count

const final_timestep = Ref{Int}(240)
duration(t::Int) = t ÷ 12

const zero_spot = read_csv("basic_term/disc_rate_ann.csv")[:, :zero_spot]
const inflation_rate = 0.01
const expense_acq = 300
const expense_maint = 60
const loading_prem = 0.50
const projection_length = 20 * 12

function recompute_globals!()
    sets = basic_term_policies[]
    policies = getproperty.(sets, :policy)
    sum_assured[] = getproperty.(policies, :assured)
    issue_age[] = Dates.value.(getproperty.(policies, :age))
    current_policies_term[] = Dates.value.(getproperty.(policies, :term)) .* Int.(policy_count.(sets))
    mortality[] = TabularMortality()
    empty_memoization_caches!()
end

function empty_memoization_caches!()
    empty!(cache_policies_inforce)
    empty!(cache_premiums_pp)
    empty!(cache_monthly_mortality)
    nothing
end

function set_basic_term_policies!(policies)
    basic_term_policies[] = policies
    recompute_globals!()
end

age(t::Int) = age_at_entry() .+ duration(t)
age_at_entry() = issue_age[]
claim_pp(t::Int) = sum_assured[]
claims(t::Int) = claim_pp(t) .* policies_death(t)
commissions(t::Int) = duration(t) == 0 ? premiums(t) : 0.0
disc_factors() = [(1 + disc_rate_mth(t))^(-t) for t in final_timestep[]]
disc_rate_mth(t::Int)::Float64 = (1 + disc_rate_ann(duration(t)))^(1/12) - 1
disc_rate_ann(t::Int)::Float64 = 0.05
expenses(t::Int) = policies_inforce(t) .* ((t == 0 ? expense_acq : 0.0) .+ (expense_maint / 12) .* inflation_factor(t))
inflation_factor(t::Int) = (1 .+ inflation_rate).^(t/12)
const cache_premiums_pp = Dict{Tuple{},Vector{Float64}}()
@memoize Returns(cache_premiums_pp)() premium_pp() = round.((1 .+ loading_prem) .* net_premium_pp(); digits = 2)
premiums(t::Int) = premium_pp() .* policies_inforce(t)
net_premium_pp() = pv_claims() ./ pv_pols_if()
net_cf(t::Int) = premiums(t) .- claims(t) .- expenses(t) .- commissions(t)

policies_death(t) = policies_inforce(t) .* monthly_mortality(t)
policies_lapse(t) = (policies_inforce(t) .- policies_death(t)) .* (1 - (1 - lapse_rate(t))^(1/12))
lapse_rate(t) = max(0.1 - 0.02 * duration(t), 0.02)
policies_term() = current_policies_term[]
function policies_maturity(t)
  (t .== 12 .* policies_term()) .* (policies_inforce(t - 1) .- policies_lapse(t - 1) .- policies_death(t - 1))::Vector{Float64}
end
const cache_policies_inforce = Dict{Tuple{Int64},Vector{Float64}}()
@memoize Returns(cache_policies_inforce)() function policies_inforce(t)::Vector{Float64}
  t == 0 && return ones(npoints())
  policies_inforce(t - 1) .- policies_lapse(t - 1) .- policies_death(t - 1) .- policies_maturity(t)
end

npoints() = length(issue_age[])
disc_factor(t) = (1 + zero_spot[duration(t)+1])^(-t/12)
pv_claims() = foldl((res, t) -> (res .+= claims(t) .* disc_factor(t)), 0:final_timestep[]; init = zeros(Float64, npoints()))
pv_commissions() = foldl((res, t) -> (res .+= commissions(t) .* disc_factor(t)), 0:final_timestep[]; init = zeros(Float64, npoints()))
pv_expenses() = foldl((res, t) -> (res .+= expenses(t) .* disc_factor(t)), 0:final_timestep[]; init = zeros(Float64, npoints()))
pv_pols_if() = foldl((res, t) -> (res .+= policies_inforce(t) .* disc_factor(t)), 0:final_timestep[]; init = zeros(Float64, npoints()))
pv_premiums() = foldl((res, t) -> (res .+= premiums(t) .* disc_factor(t)), 0:final_timestep[]; init = zeros(Float64, npoints()))
pv_net_cf() = pv_premiums() .- pv_claims() .- pv_expenses() .- pv_commissions()

function result_cf()
    data = Dict(
        "Premiums" => [sum(premiums(t)) for t in 0:final_timestep[]],
        "Claims" => [sum(claims(t)) for t in 0:final_timestep[]],
        "Expenses" => [sum(expenses(t)) for t in 0:final_timestep[]],
        "Commissions" => [sum(commissions(t)) for t in 0:final_timestep[]],
        "Net Cashflow" => [sum(net_cf(t)) for t in 0:final_timestep[]]
    )
    return DataFrame(data)
end

function result_pv()
    cols = "PV " .* ["Premiums", "Claims", "Expenses", "Commissions", "Net Cashflow"]
    pvs = [pv_premiums(), pv_claims(), pv_expenses(), pv_commissions(), pv_net_cf()]

    return DataFrame(Dict(
            cols .=> pvs,
        ))
end

const cache_monthly_mortality = Dict{Tuple{Int},Vector{Float64}}()
monthly_mortality_rates(model::TabularMortality, t::Int) = 1 .- (1 .- model.rates[issue_age[] .+ (t ÷ 12) .- 17, min(t ÷ 12, 5) + 1]) .^ (1/12)
@memoize Returns(cache_monthly_mortality)() monthly_mortality(t) = monthly_mortality_rates(mortality[], t)

const sum_assured = Ref{Vector{Int}}()
const issue_age = Ref{Vector{Int}}()
const current_policies_term = Ref{Vector{Int}}()
const basic_term_policies = Ref{Vector{PolicySet}}()
const mortality = Ref{TabularMortality}()
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
