"""
Mortality model.

A given subtype `M` is expected to define either of:
- ```julia
  monthly_mortality_rate(model::M, time::Month, policy::Policy)
  ```
- ```julia
  monthly_mortality_rate(model::M, time::Month, age::Year)
  ```
- ```julia
  annual_mortality_rate(model::M, time::Month, policy::Policy)
  ```
- ```julia
  annual_mortality_rate(model::M, time::Month, age::Year)
  ```

where, by default, the form with `Policy` as third argument simply defaults to computing the age at the current time and call a method with `age::Year` as third argument, defined for convenience.
"""
abstract type MortalityModel end

"""
    monthly_mortality_rate(model::MortalityModel, time::Month, policy::Policy)
    monthly_mortality_rate(model::MortalityModel, time::Month, age::Year)

Compute the monthly mortality rate for the given model.
Falls back to a renormalization of [`annual_mortality_rate`] over 1/12 year.
"""
function monthly_mortality_rate end

"""
    annual_mortality_rate(model::MortalityModel, time::Month, policy::Policy)
    annual_mortality_rate(model::MortalityModel, time::Month, age::Year)

Compute an annual mortality rate for the given model.

!!! note
    Simulations with [`simulate`](@ref) will use [`monthly_mortality_rate`](@ref). If your model more naturally outputs monthly mortality rates, we recommend you to extend [`monthly_mortality_rate`](@ref) instead.
"""
function annual_mortality_rate end

Base.broadcastable(model::MortalityModel) = Ref(model)
monthly_mortality_rate(model::MortalityModel, time::Month, age::Year) = 1 - (1 - annual_mortality_rate(model, time, age)) ^ (1/12)
monthly_mortality_rate(model::MortalityModel, time::Month, policy::Policy) = 1 - (1 - annual_mortality_rate(model, time, policy)) ^ (1/12)

"Default to a mortality rate depedent on age and time only."
function annual_mortality_rate(model::MortalityModel, time::Month, policy::Policy)
  age = policy.age + Year(Dates.value(time ÷ 12))
  annual_mortality_rate(model, time, age)
end

struct ConstantMortality <: MortalityModel
  annual_mortality_rate::Float64
end

annual_mortality_rate(model::ConstantMortality, time::Month, age::Year) = model.annual_mortality_rate

@struct_hash_equal Base.@kwdef struct TabularMortality <: MortalityModel
  rates::Matrix{Float64} = Matrix{Float64}(read_csv("mortality_table.csv")[:, 2:end])
end

annual_mortality_rate(model::TabularMortality, time::Int, age::Int) = model.rates[age - 17, min(time, 5) + 1]
annual_mortality_rate(model::TabularMortality, time::Month, age::Year) = annual_mortality_rate(model, Dates.value(time ÷ 12), Dates.value(age))

struct PolicyVaryingMortality{F} <: MortalityModel
  f::F
end

annual_mortality_rate(model::PolicyVaryingMortality, time::Month, policy::Policy) = model.f(time, policy)
