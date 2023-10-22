@testset "Memoized term life model" begin
  empty_memoization_caches!()

  @test BT.policies_inforce(200)[1:3] == [0.000000, 0.5724017900070532, 0.000000]
  @test BT.claims(130)[1:3] ≈ [0.0, 28.82531005791726, 0.0]
  @test BT.expenses(100)[1:3] == [3.682616858501336, 3.703818110341339, 3.671941182132007]
  @test BT.expenses(0)[1:3] == [305.0,305.0,305.0]

  @test pv_claims()[1:3] ≈ [5501.19489836432, 5956.471604652321, 9190.425784230943]
  @test pv_premiums()[1:3] ≈ [8252.08585552, 8934.76752446, 13785.48441688]
  @test pv_commissions()[1:3] ≈ [1084.60427012, 699.31842569, 1814.20246663]
  @test pv_expenses()[1:3] ≈ [755.36602611, 1097.43049098, 754.73305144]
  @test pv_net_cf()[1:3] ≈ [910.92066093, 1181.54700314, 2026.12311458]

  pvs = result_pv()
  @test isa(pvs, DataFrame)
  cfs = result_cf()
  @test isa(cfs, DataFrame)

  @testset "Changing model points" begin
    @test BT.npoints() == length(pv_claims()) == 10_000
    @test pv_claims()[1:3] ≈ [5501.19489836432, 5956.471604652321, 9190.425784230943]
    set_basic_term_policies!(policies_from_csv("basic_term/model_point_table_100.csv"))
    @test BT.npoints() == length(pv_claims()) == 100
    @test pv_claims()[1:3] ≉ [5501.19489836432, 5956.471604652321, 9190.425784230943]
    set_basic_term_policies!(policies_from_csv("basic_term/model_point_table_10K.csv"))
    @test BT.npoints() == length(pv_claims()) == 10_000
    @test pv_claims()[1:3] ≈ [5501.19489836432, 5956.471604652321, 9190.425784230943]
  end
end

@testset "Simulated term life model" begin
  model = LifelibBasiclife(commission_rate = 1.0)
  @test model == LifelibBasiclife(commission_rate = 1.0)
  policies = policies_from_csv("basic_term/model_point_table_10K.csv")

  @testset "Correctness" begin
    @test LS.monthly_mortality_rate(model, Month(0), Year(47)) == BT.monthly_mortality_rates(BT.mortality[], 0)[1]
    @test LS.monthly_mortality_rate(model, Month(24), Year(49)) == BT.monthly_mortality_rates(BT.mortality[], 24)[1]
    @test LS.monthly_mortality_rate(model, Month(49), Year(51)) == BT.monthly_mortality_rates(BT.mortality[], 49)[1]
    @test LS.monthly_mortality_rate(model, Month(49), Year(26)) == BT.monthly_mortality_rates(BT.mortality[], 49)[end]
    @test LS.annual_lapse_rate(model, Month(0)) == BT.lapse_rate(0)
    @test LS.annual_lapse_rate(model, Month(12)) == BT.lapse_rate(12)
    @test LS.monthly_lapse_rate(model, Month(0)) == (1 - (1 - BT.lapse_rate(0))^(1/12))
    @test LS.discount_rate(model, Month(0)) == BT.disc_factor(0)
    @test LS.discount_rate(model, Month(50)) == BT.disc_factor(50)

    n = BT.final_timestep[]
    sim = Simulation(model, policies)
    simulate!(sim, n) do events
      t = Dates.value(events.time)
      t > 0 && @test sum(policy_count, events.expirations; init = 0.0) ≈ sum(BT.policies_maturity(t))
      @test sum(last, events.deaths) ≈ sum(BT.policies_death(t))
      @test sum(last, events.lapses) ≈ sum(BT.policies_lapse(t))
      @test sum(policy_count, sim.active_policies) ≈ sum(BT.policies_inforce(t) .- BT.policies_death(t) .- BT.policies_lapse(t))
      @test events.claimed ≈ sum(BT.claims(t))
    end

    with_adjusted_premiums = estimate_premiums(model, policies, n)
    @test (x -> x.policy.premium).(with_adjusted_premiums) == BT.premium_pp()

    cashflow = CashFlow(model, estimate_premiums(model, policies, 1), 1)
    @test cashflow.expenses ≈ sum(BT.expenses(0))
    cashflow = CashFlow(model, estimate_premiums(model, policies, n), n)
    @test sum(sum.(BT.claims.(0:n))) ≈ cashflow.claims
    @test sum(sum.(BT.premiums.(0:n))) ≈ cashflow.premiums
    @test sum(sum.(BT.commissions.(0:n))) ≈ cashflow.commissions
    @test sum(sum.(BT.expenses.(0:n))) ≈ cashflow.expenses
    @test sum(pv_net_cf()) ≈ cashflow.discounted
  end

  @testset "Parametrization" begin
    lapse = ConstantLapse(0.00)
    mortality = ConstantMortality(0.01)
    model = LifelibBasiclife(; mortality, lapse)
    sim = simulate(model, policies, 1)
    @test all(set -> set.count < 1.0, sim.active_policies)

    mortality = ConstantMortality(0.00)
    model = LifelibBasiclife(; mortality, lapse)
    sim = simulate(model, policies, 1)
    @test all(set -> set.count == 1.0, sim.active_policies)

    mortality = ConstantMortality(0.00)
    lapse = ConstantLapse(0.01)
    model = LifelibBasiclife(; mortality, lapse)
    sim = simulate(model, policies, 1)
    @test all(set -> set.count < 1.0, sim.active_policies)

    lapse = ConstantLapse(0.00)
    model = LifelibBasiclife(; mortality, lapse)
    sim = simulate(model, policies, 1)
    @test all(set -> set.count == 1.0, sim.active_policies)

    executed = Ref(false)
    mortality = ConstantMortality(0.00)
    lapse = PolicyVaryingLapse() do time::Month, policy::Policy
      executed[] = true
      0.01
    end
    model = LifelibBasiclife(; mortality, lapse)
    sim = simulate(model, policies, 1)
    @test all(set -> set.count < 1.0, sim.active_policies)
    @test executed[]

    executed = Ref(false)
    mortality = PolicyVaryingMortality() do time::Month, policy::Policy
      executed[] = true
      # Kill all males.
      policy.sex == MALE ? 1.0 : 0.0
    end
    lapse = ConstantLapse(0.00)
    model = LifelibBasiclife(; mortality, lapse)
    sim = simulate(model, policies, 1)
    @test executed[]
    @test all(set -> set.count == (set.policy.sex == FEMALE), sim.active_policies)
  end
end;
