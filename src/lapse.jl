abstract type LapseModel end

Base.broadcastable(model::LapseModel) = Ref(model)
monthly_lapse_rate(model::LapseModel, time::Month) = 1 - (1 - annual_lapse_rate(model, time)) ^ (1/12)
monthly_lapse_rate(model::LapseModel, time::Month, policy::Policy) = 1 - (1 - annual_lapse_rate(model, time, policy)) ^ (1/12)

"""
    rates_are_per_policy(mortality_or_lapse_model)

Specify whether monthly rates produced by a given model will be specific to any given [`Policy`](@ref).

By default, this is set to `false` for performance reasons.
If `true`, rates will be recomputed for every policy, providing the [`Policy`](@ref) as an extra argument.

!!! warn
    While the recomputation of rates on a per-policy basis may allow for a fine-grained level of modeling, it will also be more computationally expensive.
"""
function rates_are_per_policy end

rates_are_per_policy(::LapseModel) = false

struct ConstantLapse <: LapseModel
  annual_lapse_rate::Float64
end

annual_lapse_rate(model::ConstantLapse, time::Month) = model.annual_lapse_rate

struct TimeVaryingLapse{F} <: LapseModel
  f::F
end

annual_lapse_rate(model::TimeVaryingLapse, time::Month) = model.f(time)

struct PolicyVaryingLapse{F} <: LapseModel
  f::F
end

rates_are_per_policy(::PolicyVaryingLapse) = true
annual_lapse_rate(model::PolicyVaryingLapse, time::Month, policy::Policy) = model.f(time, policy)
