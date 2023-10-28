# LifeSimulator.jl

![tests](https://github.com/JuliaActuary/LifeSimulator.jl/workflows/CI/badge.svg)
[![docs-stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://juliaactuary.github.io/LifeSimulator.jl/stable)
[![docs-dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://juliaactuary.github.io/LifeSimulator.jl/dev)

Simulation of insurance products forward in time.

## Getting started

Here is one way to get started with a simple simulation

```julia
using LifeSimulator, Dates

# Select the model you want to use, with parameters you like.
# Read the documentation with `?LifelibBasiclife` (help mode) in the REPL.
model = LifelibBasiclife(inflation_rate = 0.03)

# Define your policies, specifying policy templates with a number of instances.
policies = [
  PolicySet(Policy(term = Year(20), age = Year(20), premium = 200_000), 100),
  PolicySet(Policy(term = Year(20), age = Year(45), premium = 600_000), 80),
  PolicySet(Policy(term = Year(10), age = Year(70), premium = 400_000), 50),
]

# Define for how many months you want the simulation to run.
n = 150

# Perform the simulation and compute cashflows along the way.
total_cashflow = CashFlow(model, policies, n)
total_cashflow.net
total_cashflow.discounted

# Or, alternatively, perform the simulation and define a callback to be invoked at every simulation step.
deaths = 0.0
simulation = simulate(model, policies, n) do events::SimulationEvents
  # Do something with `events`.
  global deaths += sum(last, events.deaths)
end
simulation.active_policies
deaths
```

For more information, consult the [latest documentation](https://juliaactuary.github.io/LifeSimulator.jl/dev).
