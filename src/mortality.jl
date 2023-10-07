abstract type MortalityModel end

Base.broadcastable(model::MortalityModel) = Ref(model)

monthly_mortality_rate(model::MortalityModel, age::Year, time::Month) = 1 - (1 - annual_mortality_rate(model, age, time)) ^ (1/12)

struct ConstantMortality <: MortalityModel
  annual_mortality_rate::Float64
end

annual_mortality_rate(model::ConstantMortality, year::Year, time::Month) = model.annual_mortality_rate
