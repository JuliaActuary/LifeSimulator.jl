abstract type MortalityModel end

Base.broadcastable(model::MortalityModel) = Ref(model)
monthly_mortality_rate(model::MortalityModel, age::Year, time::Month) = 1 - (1 - annual_mortality_rate(model, age, time)) ^ (1/12)

struct ConstantMortality <: MortalityModel
  annual_mortality_rate::Float64
end

annual_mortality_rate(model::ConstantMortality, year::Year, time::Month) = model.annual_mortality_rate

@struct_hash_equal Base.@kwdef struct ExplicitMortality <: MortalityModel
  rates::Matrix{Float64} = Matrix{Float64}(read_csv("mortality_table.csv")[:, 2:end])
end

annual_mortality_rate(model::ExplicitMortality, year::Int, time::Int) = model.rates[year - 17, min(time, 5) + 1]
annual_mortality_rate(model::ExplicitMortality, year::Year, time::Month) = annual_mortality_rate(model, Dates.value(year), Dates.value(time ÷ 12))
