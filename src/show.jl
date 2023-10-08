using Printf

function print_balance(io::IO, value::Real; kwargs...)
  value == 0 && return printstyled(io, value; kwargs...)
  (symbol, color) = value > 0 ? ('+', :green) : ("", :red)
  printstyled(io, symbol, formatted_amount(value); color, kwargs...)
end
formatted_amount(value::Real) = @sprintf "%g" round(value, sigdigits = 4)


function Base.show(io::IO, ::MIME"text/plain", cashflow::CashFlow)
  print_balance(io, cashflow.net; bold = true)
  if !isapprox(cashflow.net, cashflow.discounted; rtol = 1e-4)
    printstyled(io, " (discounted: "; color = :light_black)
    print_balance(io, cashflow.discounted)
    printstyled(io, ')'; color = :lightblack)
  end
  positive_values = [:premiums]
  negative_values = [:claims, :commissions, :expenses]
  !iszero(cashflow.account_value_changes) && push!(cashflow.account_value_changes > 0 ? positive_values : negative_values, :account_value_changes)
  print(io, " ⇆")
  print_cashflow_contributions(io, cashflow, positive_values, :positive)
  print(io, ',')
  print_cashflow_contributions(io, cashflow, negative_values, :negative)
end

function print_cashflow_contributions(io, cashflow, fields, part)
  (color, arrow) = part == :negative ? (:red, '↓') : (:green, '↑')
  total = sum(getproperty(cashflow, field) for field in fields; init = 0.0)
  printstyled(io, " $arrow "; color, bold = true)
  print_balance(io, part == :negative ? -total : total; color)
  if total ≉ 0
    printstyled(io, " ("; color = :light_black)
    printed = false
    for field in fields
      value = getproperty(cashflow, field)
      isapprox(value, zero(value); atol = total / 10000) && continue
      percentage = round(Int, 100 * value/total)
      printed && print(io, ", ")
      printstyled(io, percentage == 0 ? "<1" : value ≉ total && percentage == 100 ? ">99" : percentage, "% ", field; color = :light_black)
      printed = true
    end
    printstyled(io, ')'; color = :light_black)
  end
end

function Base.show(io::IO, ::MIME"text/plain", events::SimulationEvents)
  print(io, SimulationEvents, ':')
  print(io, "\n● Time range: months ", Dates.value(events.time), " to ", Dates.value(events.time) + 1)
  print(io, "\n● Total deaths: ", sum(last, events.deaths), " over ", length(events.deaths), " policy sets")
  print(io, "\n● Total lapses: ", sum(last, events.lapses), " over ", length(events.lapses), " policy sets")
  print(io, "\n● Number of policies starting at the beginning of month ", Dates.value(events.time), ": ", sum(policy_count, events.starts; init = 0.0))
  print(io, "\n● Policy expirations: ~", sum(policy_count, events.expirations; init = 0.0), " (", length(events.expirations), " policy sets)")
  print(io, "\n● Claims: ~", formatted_amount(events.claimed))
  print(io, "\n● Expenses: ~", formatted_amount(events.expenses))
end
