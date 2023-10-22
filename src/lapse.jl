"""
Model expressing lapses, e.g. due to payment defaults.

A given subtype `L` is expected to define either of:
- ```julia
  monthly_lapse_rate(model::L, time::Month)
  ```
- ```julia
  monthly_lapse_rate(model::L, time::Month, policy::Policy)
  ```
- ```julia
  annual_lapse_rate(model::L, time::Month)
  ```
- ```julia
  annual_lapse_rate(model::L, time::Month, policy::Policy)
  ```

Whether to define a 2- or 3-argument method depends on whether the lapse rate as computed by the model is policy-specific. In such a case, in addition of defining 3-argument methods, you must implement `rates_are_per_policy(::LapseModel) = true`; the default is for it to be `false` implying that 2-argument methods are required.
"""
abstract type LapseModel end

"""
monthly_lapse_rate(model::LapseModel, time::Month)
    monthly_lapse_rate(model::LapseModel, time::Month, policy::Policy)

Compute the monthly lapse rate for the given model.
Falls back to a renormalization of [`annual_lapse_rate`] over 1/12 year.
"""
function monthly_lapse_rate end

"""
annual_lapse_rate(model::LapseModel, time::Month)
    annual_lapse_rate(model::LapseModel, time::Month, policy::Policy)

Compute an annual lapse rate for the given model.

!!! note
    Simulations with [`simulate`](@ref) will use [`monthly_lapse_rate`](@ref). If your model more naturally outputs monthly lapse rates, we recommend you to extend [`monthly_lapse_rate`](@ref) instead.
"""
function annual_lapse_rate end

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
