using Documenter, LifeSimulator

makedocs(;
    modules = [LifeSimulator],
    format = Documenter.HTML(
        prettyurls = true,
    ),
    pages = [
        "Home" => "index.md",
    ],
    repo = "https://github.com/JuliaActuary/LifeSimulator.jl/blob/{commit}{path}#L{line}",
    sitename = "LifeSimulator.jl",
    authors = "Cédric Belmant, Matthew Caseres",
    strict = true,
    doctest = false,
    checkdocs = :exports,
)

deploydocs(
    repo = "github.com/JuliaActuary/LifeSimulator.jl.git",
)
