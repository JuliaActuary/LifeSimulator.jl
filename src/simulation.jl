"""
Account changes between two timesteps for a policy holder in a [`UniversalLifeModel`](@ref).
"""
struct AccountChanges
  premium_paid::Float64
  premium_into_account::Float64
  maintenance_fee_rate::Float64
  insurance_cost::Float64
  investments::Float64
  net_changes::Float64
end

"""
Events that happen as part of a simulation timestep for a [`Model`](@ref).

These events are meant to be processed by the user in order to generate quantities of interest that
do not involve simulation-related state. This is, for example, how the [`CashFlow`](@ref) quantities are computed.
"""
mutable struct SimulationEvents
  "Month during which the events started to be simulated. Events occur between `time` and `time + Month(1) - Day(1)`."
  time::Month
  # Policy changes.
  "Policy sets where lapses occurred, along with the number of lapsed policies. Lapses occur at the middle of the month."
  const lapses::Vector{Pair{PolicySet,Float64}}
  "Policy sets where deaths occurred, along with the number of deceased policy holders. Deaths occur at the middle of the month."
  const deaths::Vector{Pair{PolicySet,Float64}}
  "Policies which expired at the beginning of the month."
  const expirations::Vector{PolicySet}
  "Amount resulting from expired or lapsed policies or for which the holder has died."
  claimed::Float64
  "Policies which started at the beginning of the month."
  const starts::Vector{PolicySet}
  expenses::Float64
  const account_changes::Vector{Pair{PolicySet,AccountChanges}}
end

SimulationEvents() = SimulationEvents(Month(0), Pair{PolicySet,Float64}[], Pair{PolicySet,Float64}[], PolicySet[], 0.0, PolicySet[], 0.0, Pair{PolicySet,AccountChanges}[])

function Base.empty!(events::SimulationEvents)
  empty!(events.lapses)
  empty!(events.deaths)
  empty!(events.expirations)
  empty!(events.starts)
  empty!(events.account_changes)
  events.claimed = 0
  events.expenses = 0
  events
end

"""
Simulation parametrized by a particular [`Model`](@ref).

The simulation time starts at the current date by default.
The simulation is carried out every month, producing events ([`SimulationEvents`]) corresponding
to what happened between two timesteps, i.e. from one month to the other. The simulation is nonetheless
stateful, meaning that such events may only be produced once; the next evaluation will return the events for the
timestep after that.

See also: [`next!`](@ref)
"""
mutable struct Simulation{M<:Model}
  const model::M
  "Ongoing policies which haven't reached their term yet nor lapsed and whose holders haven't died."
  const active_policies::Vector{PolicySet}
  "Policies which have yet to be started."
  const inactive_policies::Vector{PolicySet}
  "Current simulation time, incremented after every simulation step."
  time::Month
end

function Simulation(model::Model, policies, time = Month(0))
  active = filter(x -> x.policy.issued_at < time, policies)
  inactive = filter(x -> x.policy.issued_at ≥ time, policies)
  Simulation(model, active, inactive, time)
end

if isdefined(Base, :ScopedValue)
  const SHOW_PROGRESS = ScopedValue(false)
else
  const SHOW_PROGRESS = Ref(false)
end

"""
Boolean flag indicating whether to show progress during a simulation.

See also: [`simulate`](@ref), [`simulate!`](@ref)
"""
SHOW_PROGRESS

"""
    simulate(f, model, policies, n)

Simulate a set of policies forward in time according to the provided model, for `n` months.

After every iteration, `f(events::SimulationEvents)` is called, and may be used for example to
compute and keep track of cashflows.

See also: [`SimulationEvents`](@ref), [`CashFlow`](@ref)
"""
simulate(f, model::Model, policies, n::Int) = simulate!(f, Simulation(model, policies), n)
simulate(model::Model, policies, n::Int) = simulate(identity, model, policies, n)
simulate!(sim::Simulation, n::Int) = simulate!(identity, sim, n)

"""
    simulate!(f, sim::Simulation, n)

Iteratively update a [`Simulation`](@ref) in-place with `n` 1-month timesteps.

See also: [`simulate`](@ref)
"""
function simulate!(f, sim::Simulation, n::Int)
  events = SimulationEvents()
  SHOW_PROGRESS[] && print("Simulation starting...")
  for i in 1:n
    next!(sim, events)
    f(events)
    empty!(events)
    SHOW_PROGRESS[] && show_progress(sim, i, n)
  end
  SHOW_PROGRESS[] && print("\r" * ' '^100 * '\r')
  sim
end

function show_progress(sim::Simulation, i::Int, n::Int)
  model = nameof(typeof(sim.model))
  print("\rSimulating ($model): $i/$n steps               ")
end

"""
Run a first simulation to estimate premiums for each policy, returning policies with the estimated premiums.

Instead of running a full simulation, and producing a [`SimulationEvents`](@ref) at every step,
we manually go through the lapse and mortality stages only to speed it up a bit.
"""
function estimate_premiums(model::LifelibBasiclife, policies, n)
  policy_counts = policy_count.(policies)
  expired = Set{PolicySet}()
  discounted_claims = zeros(length(policies))
  discounted_policy_counts = zeros(length(policies))

  # Record claims associated to deaths at `time` and the policy counts at `time + 1`.
  for time in simulation_range(n + 1)
    discount = discount_rate(model, time)
    !rates_are_per_policy(model.lapse) && (lapse_rate = monthly_lapse_rate(model, time))
    lapse_rate = monthly_lapse_rate(model, time)
    for (i, set) in enumerate(policies)
      expires(set, time) && push!(expired, set)
      in(set, expired) && continue
      current_count = policy_counts[i]
      discounted_policy_counts[i] += current_count * discount
      mortality_rate = monthly_mortality_rate(model, time, set.policy)
      deaths = mortality_rate * current_count
      current_count -= deaths
      discounted_claims[i] += deaths * set.policy.assured * discount
      rates_are_per_policy(model.lapse) && (lapse_rate = monthly_lapse_rate(model, time, policy))
      lapses = lapse_rate * current_count
      current_count -= lapses
      policy_counts[i] = current_count
    end
  end

  map(enumerate(policies)) do (i, set)
    raw_premium = discounted_claims[i] / (policy_count(set) * discounted_policy_counts[i])
    @set set.policy.premium = round((1 + model.load_premium_rate) * raw_premium; digits = 2)
  end
end

simulation_range(n::Int, start::Int = 0) = Month(start):Month(1):Month(n)

"""
Perform a simulation timestep over the [`LifelibSavings`](@ref) model, returning a [`SimulationEvents`](@ref).

First, the policies which reached their term are removed, yielding claims and account changes.

Second, the policies which start from the current month are added, yielding expenses (costs for the insurance company).

Third, all account values are updated, with:
- A premium amount put into the bank account (minus fees, the load premium rate).
- Maintenance fees withdrawn from the back account.
- Insurance costs withdrawn from the back account.
- Investments realized during the previous month.

Then, at the middle of the month, deaths and lapses occur. Finally, the simulation time is incremented.
"""
function next!(sim::Simulation{<:LifelibSavings}, events::SimulationEvents)
  events.time = sim.time

  remove_expired_policies!(events, sim)
  add_new_policies!(events, sim)
  update_bank_accounts!(events, sim)
  # At this point we are at `time` + 0.5 months.
  simulate_deaths_and_lapses!(events, sim)

  sim.time += Month(1)
  events
end

"""
Perform a simulation timestep over the [`LifelibBasiclife`](@ref) model, returning a [`SimulationEvents`](@ref).

First, the policies which reached their term are removed, yielding claims and account changes.

Second, the policies which start from the current month are added, yielding expenses (costs for the insurance company).

Then, at the middle of the month, deaths and lapses occur. Finally, the simulation time is incremented.

A callback may be run just before the deaths and lapses occur, as the original `basiclife` model considers
lapses and deaths to be part of the next iteration (i.e., deaths and lapses occur prior to the next step, and not in the current step).
"""
function next!(sim::Simulation{<:LifelibBasiclife}, events::SimulationEvents; callback = identity)
  events.time = sim.time

  remove_expired_policies!(events, sim)
  add_new_policies!(events, sim)
  callback(sim)
  # At this point we are at `time` + 0.5 months.
  simulate_deaths_and_lapses!(events, sim)

  sim.time += Month(1)
  events
end

"Add policies which start from this date."
function add_new_policies!(events::SimulationEvents, sim::Simulation)
  filter!(sim.inactive_policies) do set
    issued = sim.time == set.policy.issued_at
    if issued
      push!(sim.active_policies, set)
      push!(events.starts, set)
      events.expenses += policy_count(set) * acquisition_cost(sim.model)
    end
    !issued
  end
end

"Remove policies which reached their term."
function remove_expired_policies!(events::SimulationEvents, sim::Simulation)
  filter!(sim.active_policies) do set
    expires(set, sim.time) || return true
    push!(events.expirations, set)
    false
  end
  on_expired!(events, sim.model)
end

expires(policy::Policy, time::Month) = time == policy.issued_at + Month(policy.term)
expires(set::PolicySet, time::Month) = expires(set.policy, time)

function simulate_deaths_and_lapses!(events::SimulationEvents, sim::Simulation)
  !rates_are_per_policy(sim.model.lapse) && (lapse_rate = monthly_lapse_rate(sim.model, events.time))
  for (i, set) in enumerate(sim.active_policies)
    remaining = policy_count(set)
    (; policy) = set
    mortality_rate = monthly_mortality_rate(sim.model, events.time, policy)
    deaths = mortality_rate * remaining
    remaining -= deaths
    rates_are_per_policy(sim.model.lapse) && (lapse_rate = monthly_lapse_rate(sim.model, events.time, policy))
    lapses = lapse_rate * remaining
    remaining -= lapses
    sim.active_policies[i] = PolicySet(policy, remaining)
    !iszero(lapses) && push!(events.lapses, set => lapses)
    !iszero(deaths) && push!(events.deaths, set => deaths)
  end
  on_deaths!(events, sim.model)
  on_lapses!(events, sim.model)
end

on_deaths!(events::SimulationEvents, model::LifelibBasiclife) = events.claimed += sum(((set, deaths),) -> set.policy.assured * deaths, events.deaths; init = 0.0)
function on_deaths!(events::SimulationEvents, model::LifelibSavings)
  for (set, deaths) in events.deaths
    events.claimed += deaths * max((1 + 0.5investment_rate(model, events.time)) * set.policy.account_value, set.policy.assured)
  end
end

on_lapses!(events::SimulationEvents, model::LifelibBasiclife) = nothing
function on_lapses!(events::SimulationEvents, model::LifelibSavings)
  for (set, lapses) in events.lapses
    events.claimed += lapses * (1 + 0.5investment_rate(model, events.time)) * set.policy.account_value
  end
end

on_expired!(events::SimulationEvents, model::LifelibBasiclife) = nothing
function on_expired!(events::SimulationEvents, model::LifelibSavings)
  for set in events.expirations
    # The account value is claimed by the policy holder at expiration.
    events.claimed += policy_count(set) * max(set.policy.account_value, set.policy.assured)
    push!(events.account_changes, set => AccountChanges(0, 0, 0, 0, 0, -set.policy.account_value))
  end
end

function update_bank_accounts!(events::SimulationEvents, sim::Simulation{<:LifelibSavings})
  (; model, time) = sim
  for (i, set) in enumerate(sim.active_policies)
    events.expenses += maintenance_cost(model, time) * policy_count(set)

    (; policy) = set
    (; account_value) = policy
    # `BEF_PREM`
    old_account_value = account_value
    premium_paid = premium_cost(policy, time)
    premium_into_account = premium_paid * (1 - policy.product.load_premium_rate)
    account_value += premium_into_account
    # `BEF_FEE`
    fee = account_value * model.maintenance_fee_rate
    account_value -= fee
    insurance_cost = model.insurance_risk_cost * amount_at_risk(model, policy, account_value)
    account_value -= insurance_cost
    # `BEF_INV`
    investments = investment_rate(model, time) * account_value
    account_value += investments
    sim.active_policies[i] = @set set.policy.account_value = account_value
    push!(events.account_changes, set => AccountChanges(premium_paid, premium_into_account, fee, insurance_cost, investments, account_value - old_account_value))
  end
end

premium_cost(policy, time) = policy.product.premium_type == PREMIUM_SINGLE && time ≠ policy.issued_at ? 0.0 : policy.premium
