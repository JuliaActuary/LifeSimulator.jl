#=

# Customizing models

LifeSimulator.jl is designed to allow users to provide their own models. Notably, custom models for mortality and lapses may be specified, to allow for a more realistic parametrization than the default values. On the longer term, it might be possible to bundle common interfaces for whole [`Model`](@ref)s, but we haven't explored enough insurance products to be able to design a cohesive interface between different types of products. Curently, we have a very basic categorization of insurance product models into [term life](https://en.wikipedia.org/wiki/Term_life_insurance) and [universal life](https://en.wikipedia.org/wiki/Universal_life_insurance) models (via the types [`TermLifeModel`](@ref) and [`UniversalLifeModel`](@ref)). These don't represent all the types of insurance models, and have a single implementation with limited functionality at the moment, [`LifelibBasiclife`](@ref) and [`LifelibSavings`](@ref) (greatly inspired by [lifelib](https://lifelib.io/), as their name suggests).

Nonetheless, these insurance models allow us to carry out simulations and produce reasonable data, and even more so with custom mortality and lapse models.

## Mortality model

Mortality models are defined as subtypes of [`MortalityModel`](@ref). Documentation for this abstract type reveals that we need to extend [`monthly_mortality_rate`](@ref) or [`annual_mortality_rate`](@ref), whichever we prefer.

Let's create our own mortality model which believes that female individuals are immortal and that men very frequently die. After creating a basic `struct`, we extend [`annual_mortality_rate`](@ref) with the corresponding logic:

=#

using LifeSimulator, Dates

Base.@kwdef struct SexDiscriminatingMortality <: MortalityModel
  annual_rate::Float64 = 0.4
end

function LifeSimulator.annual_mortality_rate(model::SexDiscriminatingMortality, ::Month, policy::Policy)
  if policy.sex == FEMALE
    0.0
  else
    model.annual_rate
  end
end

# We can now try to simulate using this model and see how that affects the population after 5 years:

mortality = SexDiscriminatingMortality()
lapse = ConstantLapse(0.0) # this ensures all policy decrements are due to deaths
model = LifelibBasiclife(; mortality, lapse)
policies = [
  PolicySet(Policy(sex = MALE), 100),
  PolicySet(Policy(sex = FEMALE), 100),
]
sim = simulate(model, policies, 60)

male, female = sim.active_policies
male.count

#-

female.count

#=

## Lapse model

Similarly to mortality models, lapse models are defined as subtypes of a [`LapseModel`](@ref) abstract type. We also need to implement a method to compute an annual or monthly lapse rate, but this time the default is not to associate lapse rates to individual policies for performance reasons. Instead, if we wish to do so, we will have to specify `rates_are_per_policy(model::MyModel) = true`. Let's define a model that thinks only females lapse their contracts, and with a very high default probability:

=#

Base.@kwdef struct SexDiscriminatingLapse <: LapseModel
  annual_rate::Float64 = 0.7
end

function LifeSimulator.annual_lapse_rate(model::SexDiscriminatingLapse, ::Month, policy::Policy)
  if policy.sex == MALE
    0.0
  else
    model.annual_rate
  end
end

LifeSimulator.rates_are_per_policy(::SexDiscriminatingLapse) = true

# Let's see this in action:

mortality = ConstantMortality(0.0) # this ensures all policy decrements are due to lapses
lapse = SexDiscriminatingLapse()
model = LifelibBasiclife(; mortality, lapse)
policies = [
  PolicySet(Policy(sex = MALE), 100),
  PolicySet(Policy(sex = FEMALE), 100),
]
sim = simulate(model, policies, 60)

male, female = sim.active_policies
male.count

#-

female.count

# Of course, we can customize both mortality and lapse models at the same time:

mortality = SexDiscriminatingMortality()
lapse = SexDiscriminatingLapse()
model = LifelibBasiclife(; mortality, lapse)
policies = [
  PolicySet(Policy(sex = MALE), 100),
  PolicySet(Policy(sex = FEMALE), 100),
]
sim = simulate(model, policies, 60)

male, female = sim.active_policies
male.count

#-

female.count
