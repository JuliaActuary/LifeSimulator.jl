using Documenter, LifeSimulator

makedocs(;
    modules = [LifeSimulator],
    format = Documenter.HTML(
        prettyurls = true,
        repolink = "github.com/JuliaActuary/LifeSimulator.jl",
    ),
    pages = [
        "Home" => "index.md",
        "Reference" => "reference.md",
    ],
    repo = "https://github.com/JuliaActuary/LifeSimulator.jl/blob/{commit}{path}#L{line}",
    sitename = "LifeSimulator.jl",
    authors = "Cédric Belmant, Matthew Caseres",
    linkcheck = true,
    doctest = false,
    checkdocs = :exports,
)

deploydocs(
    repo = "github.com/JuliaActuary/LifeSimulator.jl.git",
)
