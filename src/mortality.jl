abstract type MortalityModel end

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
