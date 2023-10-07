#=

# Getting started

Let's run a few simulations to get a feel of the package functionality.

First, we have to choose a [`Model`](@ref) to simulate. There are a few to choose from, essentially divided in two categories: [`TermLifeModel`](@ref)s, representing [term life insurance](https://en.wikipedia.org/wiki/Term_life_insurance), and [`UniversalLifeModel`](@ref)s, representing [universal life insurance](https://en.wikipedia.org/wiki/Universal_life_insurance). For this example, we will take a simple term life model based on [lifelib](https://github.com/lifelib-dev/lifelib), reimplemented in Julia. There are two implementations we can choose from: a memoized implementation, and an iterative implementation. The memoized implementation replicates 1:1 the design of the corresponding Python library, and has a less polished interface. For this reason, we will take the iterative implementation, [`LifelibBasiclife`](@ref), which will allow us to showcase most of the data structures relevant in context of this package.

=#

using LifeSimulator
model = LifelibBasiclife()

#=

Second, we define a bunch of policies that we want to simulate forward in time. Such policies represent life insurance products. Ideally, we would simulate individual products, that is, separate contracts for different customers. However, for efficiency and scalability reasons, such insurance products are implemented as sets of products. That is, a contract is weighted by a number of customers holding this type of contract. those are called [`PolicySet`]s, which we can generate randomly using `Base.rand`:

=#

policies = rand(PolicySet, 500)

#=

Now that we have a model and policies to evolve over time, let us summon a [`Simulation`](@ref) before carrying out the computation over a specified time range.

=#

simulation = Simulation(model, policies)

# First, as we're just experimenting, we can simulate a single step and print what happened during that time. The data structure that will be provided to our custom callback function will be a [`SimulationEvents`](@ref), and we can just print it out for now.

n = 1 # number of timesteps
simulate!(simulation, n) do events
  println(sprint(show, MIME"text/plain"(), events))
end;

#=

This [`SimulationEvents`](@ref) data structure has information about deaths, lapses, new and expired policies, claims and expenses. This is all useful to compute cash flows and miscellaneous costs involved for the insurance company providing the insurance products.

In fact, the computation of cash flows is usually the main point of interest of such simulations, which warranted its implementation in this package: enters [`CashFlow`](@ref).

Now, instead of printing the raw [`SimulationEvents`](@ref), we can print the associated [`CashFlow`](@ref) quite simply:

=#

## Prepare a new simulation, the other one has been modified by `simulate!`.
simulation = Simulation(model, policies)
simulate!(simulation, n) do events
  cf = CashFlow(events, model)
  println("Net cash flow: ", cf.net)
end;

#=

We got a negative cashflow, from the perspective of the insurance company. Why is that? In our model, establishing new contracts (policies) has a fixed cost, which is part of the expenses reported by the [`SimulationEvents`](@ref) during printing earlier.

But note that we only computed cash flows due to the various events that occurred during the simulation. We have not computed cash flows related to active policies, and therefore, our value for the net cash flow is incomplete! Let's fix that:

=#

simulation = Simulation(model, policies)
simulate!(simulation, n) do events
  cf = CashFlow(simulation) # premiums, policy upkeep costs, commissions
  cf += CashFlow(events, model) # claims, costs for new policies
  println("Net cash flow: ", cf.net)
end;

##XXX: Why do we get negative cash flows all the way?
