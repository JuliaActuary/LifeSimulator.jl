using Documenter, LifeSimulator, Literate

function julia_files(dir)
  files = reduce(vcat, [joinpath(root, file) for (root, dirs, files) in walkdir(dir) for file in files])
  sort(filter(endswith(".jl"), files))
end

function generate_markdowns()
  dir = joinpath(@__DIR__, "src")
  Threads.@threads for file in julia_files(dir)
    Literate.markdown(
    file,
    dirname(file);
    documenter = true,
    )
  end
end

generate_markdowns()

makedocs(;
  modules = [LifeSimulator],
  format = Documenter.HTML(
    prettyurls = true,
    repolink = "github.com/JuliaActuary/LifeSimulator.jl",
    size_threshold_warn = 10_000_000, # 10 MB
    size_threshold = 100_000_000, # 100 MB
  ),
  pages = [
    "Home" => "index.md",
    "Tutorials" => [
      "tutorial/getting_started.md",
      "tutorial/customizing_models.md",
    ],
    "Reference" => "reference.md",
  ],
  repo = "https://github.com/JuliaActuary/LifeSimulator.jl/blob/{commit}{path}#L{line}",
  sitename = "LifeSimulator.jl",
  authors = "Cédric Belmant, Matthew Caseres",
  linkcheck = true,
  doctest = false,
  checkdocs = :exports,
)

deploydocs(repo = "github.com/JuliaActuary/LifeSimulator.jl.git")
