@struct_hash_equal Base.@kwdef struct BasicMortality <: MortalityModel
  rates::Matrix{Float64} = Matrix{Float64}(read_csv("basic_term/mort_table.csv")[:, 2:end])
  issue_age::Vector{Int} = issue_age[]
end

annual_mortality_rate(model::BasicMortality, year::Int, time::Int) = model.rates[year - 17, min(time, 5) + 1]
annual_mortality_rate(model::BasicMortality, year::Year, time::Month) = annual_mortality_rate(model, Dates.value(year), Dates.value(time ÷ 12))

const cache_monthly_basic_mortality = Dict{Tuple{Int},Vector{Float64}}()
monthly_mortality_rates(model::BasicMortality, t::Int) = 1 .- (1 .- model.rates[model.issue_age .+ (t ÷ 12) .- 17, min(t ÷ 12, 5) + 1]) .^ (1/12)
@memoize Returns(cache_monthly_basic_mortality)() monthly_basic_mortality(t) = monthly_mortality_rates(basic_mortality[], t)
