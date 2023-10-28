"""
Model defining the evolution of policies with regards to lapses, cashflows and,
for [`UniversalLifeModel`](@ref)s, account values for policy holders.

Models are to be evaluated using a [`Simulation`](@ref).

See also: [`Policy`](@ref), [`TermLifeModel`](@ref), [`UniversalLifeModel`](@ref)
"""
abstract type Model end

monthly_mortality_rate(model::Model, args...) = monthly_mortality_rate(model.mortality, args...)
monthly_lapse_rate(model::Model, args...) = monthly_lapse_rate(model.lapse, args...)

Base.broadcastable(model::Model) = Ref(model)

mortality = read_csv("savings/mortality.csv")

"""
Universal life model.

The defining property of a universal life model is that the contract between an insurance company and a policy holder
involves a client-managed bank account, where the policy holder is responsible for keeping the bank account appropriately filled.

Lapses do not occur in absence of a payment, but rather when the bank account runs out of money while fees or premiums must be paid.
It is, for example, for the policy holder to put a lot of money in the bank account and forget about it for a while, as opposed to a regular
term life insurance model which requires frequent payments without such buffer.
"""
abstract type UniversalLifeModel <: Model end

"""
Universal life model reimplemented from [lifelib's savings library](https://lifelib.io/libraries/savings/index.html).
"""
@struct_hash_equal Base.@kwdef struct LifelibSavings{M<:MortalityModel,L<:LapseModel} <: UniversalLifeModel
  mortality::M = ConstantMortality(0.0)
  lapse::L = ConstantLapse(0.0)
  maintenance_fee_rate::Float64 = 0.00
  commission_rate::Float64 = 0.05
  insurance_risk_cost::Float64 = 0.00 # could be set as a function of the mortality rate
  investment_rates::Vector{Float64} = brownian_motion(10000) # the dimension is the number of possible timesteps
  "One-time cost for new policies."
  acquisition_cost::Float64 = 5000.0
  "Roughly estimated average for the annual inflation rate."
  inflation_rate::Float64 = 0.01
  "Annual maintenance cost per policy."
  annual_maintenance_cost::Float64 = 500.0
  "Estimated average for the future devaluation of cash."
  annual_discount_rate::Float64 = 0.020201340026756
end

brownian_motion(n::Integer; μ = 0.02, σ = 0.03, Δt = 1/12) = exp.((μ - σ^2/2)Δt .+ σ√(Δt) .* randn(n)) .- 1
# TODO: Take the account value after the premium is versed and before account fees (`BEF_FEE`), not after.
amount_at_risk(::LifelibSavings, policy::Policy, av_before_fees) = max(av_before_fees, policy.assured)

investment_rate(model::LifelibSavings, t::Month) = model.investment_rates[1 + Dates.value(t)]

acquisition_cost(model::LifelibSavings) = model.acquisition_cost
maintenance_cost(model::LifelibSavings, t::Month) = model.annual_maintenance_cost / 12 * (1 + model.inflation_rate)^(Dates.value(t)/12)

discount_rate(model::LifelibSavings, time::Month) = ((1 + model.annual_discount_rate)^(1/12))^(-Dates.value(time))

"""
Term life model.

Term life contracts start at a given date, and expire at a specified term.
Upon death, the policy may be claimed, providing the policy holder with an assured amount.

Premiums must be paid every month, otherwise the contract is cancelled (lapses).
"""
abstract type TermLifeModel <: Model end

"""
Term life insurance model replicating the functionality of lifelib's `basiclife` module.
"""
@struct_hash_equal Base.@kwdef struct LifelibBasiclife{M<:MortalityModel,L<:LapseModel} <: TermLifeModel
  mortality::M = TabularMortality()
  lapse::L = TimeVaryingLapse(t::Month -> max(0.1 - 0.02 * (Dates.value(t) ÷ 12), 0.02))
  load_premium_rate::Float64 = 0.50
  "One-time cost for new policies."
  acquisition_cost::Float64 = 300.0
  "Annual maintenance cost per policy."
  annual_maintenance_cost::Float64 = 60.0
  "Agents selling insurance products get paid a commission, whose value is a percentage of the premium paid during the first year."
  commission_rate::Float64 = 0.60
  "Roughly estimated average for the inflation rate."
  inflation_rate::Float64 = 0.01
  discounts::Vector{Float64} = read_csv("basic_term/disc_rate_ann.csv")[:, :zero_spot]
end

inflation_factor(model::LifelibBasiclife, month::Month) = (1 + model.inflation_rate)^(Dates.value(month) / 12)
acquisition_cost(model::LifelibBasiclife) = model.acquisition_cost
annual_lapse_rate(model::LifelibBasiclife, time::Month) = max(0.1 - 0.02 * (Dates.value(time) ÷ 12), 0.02)
discount_rate(model::LifelibBasiclife, time::Month) = (1 + model.discounts[1 + Dates.value(time) ÷ 12])^(-Dates.value(time) / 12)

function ntimesteps end
