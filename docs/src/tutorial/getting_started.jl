#=

# Getting started

Let's run a few simulations to get a feel of the package functionality.

First, we have to choose a [`Model`](@ref) to simulate. There are a few to choose from, essentially divided in two categories: [`TermLifeModel`](@ref)s, representing [term life insurance](https://en.wikipedia.org/wiki/Term_life_insurance), and [`UniversalLifeModel`](@ref)s, representing [universal life insurance](https://en.wikipedia.org/wiki/Universal_life_insurance). For this example, we will take a simple term life model based on [lifelib](https://github.com/lifelib-dev/lifelib), reimplemented in Julia. There are two implementations we can choose from: a memoized implementation, and an iterative implementation. The memoized implementation replicates 1:1 the design of the corresponding Python library, and has a less polished interface. For this reason, we will take the iterative implementation, [`LifelibBasiclife`](@ref), which will allow us to showcase most of the data structures relevant in context of this package.

=#

using LifeSimulator, Dates
model = LifelibBasiclife()

#=

Second, we define a bunch of policies that we want to simulate forward in time. Such policies represent life insurance products. Ideally, we would simulate individual products, that is, separate contracts for different customers. However, for efficiency and scalability reasons, such insurance products are implemented as sets of products. That is, a contract is weighted by a number of customers holding this type of contract. those are called [`PolicySet`](@ref)s. We can generate some randomly using `Base.rand`:

=#

rand(PolicySet, 500)

# But for this example, we'll use a small set of fixed policies to guarantee the consistency of results across runs (which will allow us to reliably interpret what we obtain). We'll stick to the default values for the most part.

policies = [
  PolicySet(Policy(term = Year(20), age = Year(20), premium = 200_000), 100),
  PolicySet(Policy(term = Year(20), age = Year(45), premium = 600_000), 80),
  PolicySet(Policy(term = Year(10), age = Year(70), premium = 400_000), 50),
]

#=

Now that we have a model and policies to evolve over time, we can carry out a simulation using [`simulate`](@ref) over a specified time range.

First, as we're just experimenting, we can simulate a single step (which is equivalent to a single month) and print what happened during that time. The data structure that will be provided to our custom callback function will be a [`SimulationEvents`](@ref), and we can just print it out for now.


=#

n = 1 # number of timesteps
simulate(model, policies, n) do events
  println(sprint(show, MIME"text/plain"(), events))
end;

#=

This [`SimulationEvents`](@ref) data structure has information about deaths, lapses, new and expired policies, claims and expenses. This is all useful to compute cash flows and miscellaneous costs involved for the insurance company providing the insurance products.

In fact, the computation of cash flows is usually the main point of interest of such simulations, which warranted its implementation in this package: enters [`CashFlow`](@ref).

Now, instead of printing the raw [`SimulationEvents`](@ref), we can print the associated [`CashFlow`](@ref) quite simply:

=#

simulate(model, policies, n) do events
  cf = CashFlow(events, model)
  println(sprint(show, MIME"text/plain"(), cf; context = :color => true))
end;

#=

We got a negative cashflow, from the perspective of the insurance company. Why is that? In our model, establishing new contracts (policies) has a fixed cost, which is part of the expenses reported by the [`SimulationEvents`](@ref) during printing earlier.

But note that we only computed cash flows due to the various events that occurred during the simulation. We have not computed cash flows related to active policies, and therefore, our value for the net cash flow is incomplete! Let's fix that. We will need to manually build a [`Simulation`](@ref) object so we can reference during the computation of cash flows, and use [`simulate!`](@ref) to mutate this simulation in-place. Note that the [`simulate`](@ref) function essentially does the same thing, it's just that it won't give you access to the simulation object itself.

=#

simulation = Simulation(model, policies)
simulate!(simulation, n) do events
  cf = CashFlow(simulation) # premiums, policy upkeep costs, commissions
  cf += CashFlow(events, model) # claims, costs for new policies
  println(sprint(show, MIME"text/plain"(), cf; context = :color => true))
end;

#=

Note how the net cashflow is now positive: the premiums balance out the costs incurred by policy acquisitions to the insurance company,
as well as claims made during that period. It even turns out that commissions on said premiums now actually make most of the cash flow; indeed, by default there is a 60% commission rate for the first year.

Instead of building a `Simulation`, and then computing cash flows manually, convenience functions are provided when the sole interest of the simulation is to compute cash flows. Let's for example simulate 5 months now and see what we get:

=#

n = 5
CashFlow(model, policies, n)

#-

CashFlow(model, policies, n) do cashflow
  println(sprint(show, MIME"text/plain"(), cashflow; context = :color => true))
end;

#=

For term life insurance products, it will be normal for the company to have a decreasing revenue over time, as the premium remains fixed while mortality increases. An exception is typically made for the first year, during which commissions to agents are generally paid a large percentage of the premium.

=#
