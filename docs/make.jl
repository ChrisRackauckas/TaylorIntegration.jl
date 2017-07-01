using Documenter, TaylorIntegration

makedocs(
    modules = [TaylorIntegration],
    format = :html,
    sitename = "TaylorIntegration.jl",
    pages = [
        "Home" => "index.md",
    ]
)

deploydocs(
    repo   = "github.com/PerezHz/TaylorIntegration.jl.git",
    target = "build",
    julia = "0.6",
    osname = "linux",
    deps   = nothing,
    make   = nothing
)
