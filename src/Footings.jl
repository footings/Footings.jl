module Footings

export 
    AbstractElement, 
    Parameter, 
    Temporary, 
    Result, 
    Step,
    Model, 
    add_parameter!, 
    add_temporary!, 
    add_result!,
    add_step!, 
    parse_expr,
    @model,
    build_documentation,
    build_runner,
    build_auditor

include("model.jl")
# inlcude("audit_runner.jl")
# include("model_runner.jl")

end
