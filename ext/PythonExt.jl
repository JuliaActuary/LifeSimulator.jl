module PythonExt

using LifeSimulator
using LifeSimulator: to_csv
using PythonCall

"Read a specific `savings` model, such as `SE_EX4` or `ME_EX4`."
function read_savings_model(model = "ME_EX4"; dir = pwd())
  mx = pyimport("modelx")
  mx.read_model(joinpath(dir, "CashValue_$model")).Projection
end

LifeSimulator.investment_rate(proj::Py) = pyconvert(Array, proj.inv_return_table())[1, :]
LifeSimulator.ntimesteps(proj::Py) = pyconvert(Int, proj.max_proj_len())

"Set the policy sets (model points) used by `proj` to be `policies`."
function LifeSimulator.use_policies!(proj::Py, policies)
  csv = to_csv(policies)
  pd = pyimport("pandas")
  df = pd.read_csv(csv)
  proj.model_point_table = df
  proj
end

"""
Import the current policy sets (model points) from a projection model `proj`.
"""
function LifeSimulator.policies_from_csv(proj::Py)
  file = tempname()
  open(file, "w") do io
    println(io, "policy_id,spec_id,age_at_entry,sex,policy_term,policy_count,sum_assured,duration_mth,premium_pp,av_pp_init")
    for (i, row) in enumerate(proj.model_point_table.values)
      print(io, i, ',')
      data = pyconvert(Tuple, row)
      # Skip accum_prem_init_pp.
      data = data[1:(end - 1)]
      println(io, join(data, ','))
    end
    println(io)
  end
  policies_from_csv(file)
end


end # module
