using StaticModules: StaticModule
using MLStyle: @match
using MacroTools: rmlines

abstract type AbstractFootingsElement end


Base.@kwdef struct Parameter <: AbstractFootingsElement
    name::Symbol
    type::Type
    description::String
end

Base.@kwdef struct Temporary <: AbstractFootingsElement
    name::Symbol
    type::Type
    description::String
end

Base.@kwdef struct Result <: AbstractFootingsElement
    name::Symbol
    type::Type
    description::String
end

Base.@kwdef struct Steps <: AbstractFootingsElement
    steps::Vector
end

Base.@kwdef struct Step
    fsym::Symbol
    assign::Symbol
    func::Function
    args::Tuple
end

Base.@kwdef struct Model
    name::String
    description::String = ""
    parameters::Vector = []
    temps::Vector = []
    results::Vector = []
    steps::Vector = []
end


function add_field!(model::Model, field::Parameter)
    push!(model.parameters, field)
    return nothing
end

function add_field!(model::Model, field::Temporary)
    push!(model.temps, field)
    return nothing
end

function add_field!(model::Model, field::Result)
    push!(model.results, field)
    return nothing
end

function add_field!(model::Model, field::Step)
    push!(model.steps, field)
    return nothing
end

function add_parameter!(model::Model; name::Symbol, type::Any, description::String)
    add_field!(model, Parameter(name = name, type = type, description = description))
    return nothing
end

function add_temporary!(model::Model; name::Symbol, type::Any, description::String)
    add_field!(model, Temporary(name = name, type = type, description = description))
    return nothing
end

function add_result!(model::Model; name::Symbol, type::Any, description::String)
    add_field!(model, Result(name = name, type = type, description = description))
    return nothing
end

function add_step!(
    model::Model,
    ns::StaticModule;
    assign::Symbol,
    func::Symbol,
    args::Tuple,
)
    func2 = getproperty(ns, func)
    add_field!(model, Step(fsym = func, assign = assign, func = func2, args = args))
    return nothing
end

function make_expr(step)
    return Expr(:(=), step.assign, Expr(:call, step.func, step.args...))
end

function create_func_parameters_expr(model::Model)
    p = [Expr(:(::), Symbol(p.name), p.type) for p in values(model.parameters)]
    return Expr(:parameters, p...)
end

function create_func_call_expr(model::Model, prefix::String)
    f_name = Symbol(prefix, "_", lowercase(model.name))
    f_params = create_func_parameters_expr(model)
    return Expr(:call, f_name, f_params)
end

function create_runner_expr(model::Model)
    steps = [make_expr(step) for step in model.steps]
    return Expr(:block, steps...)
end

function create_auditor_expr(model::Model)
    return Expr()
end

function build_documentation(model::Model)
    return "This is documentation."
end

function build_runner(model::Model, document::Bool = false)::Function
    f_call = create_func_call_expr(model, "run")
    f_body = create_runner_expr(model)
    f = eval(Expr(:function, f_call, f_body))
    if document
        docs = build_documentation(model)
        @doc docs f
    end
    return f
end

function build_auditor(model)::Function
    f_call = create_func_call_expr(model, "audit")
    f_body = create_auditor_expr(model)
    return eval(Expr(:function, f_call, f_body))
end

escape_args(args) = Tuple([esc(arg) for arg in args])

function _parse_expr(expr::Expr)
    function _parse(expr::Expr)
        @match expr begin
            Expr(:block, args) => _parse(args)
            Expr(:call, :Parameter, args...) =>
                :(add_parameter!($(:m), $(escape_args(args)...)))
            Expr(:call, :Temporary, args...) =>
                :(add_temporary!($(:m), $(escape_args(args)...)))
            Expr(:call, :Result, args...) => :(add_result!($(:m), $(escape_args(args)...)))
            Expr(:call, :Steps, args...) => map(_parse, args)
            Expr(:call, :(=>), assign, call) => :(add_step!(
                $(:m),
                $(:ns),
                assign = $(esc(assign)),
                func = $(QuoteNode(call.args[1])),
                args = $(Tuple(call.args[2:end])),
            ))
            Expr(:(=), assign, func, args...) => :(add_step!(
                $(:m),
                $(:ns),
                assign = $(esc(assign)),
                func = $(esc(func)),
                args = $args,
            ))
            _ => nothing
        end
    end
    return [_parse(e) for e in expr.args]
end

function _flatten(vec::Vector)
    v2 = []
    function _inner(x)
        if !isnothing(x)
            if isa(x, Expr)
                push!(v2, x)
            elseif isa(x, Vector)
                for xx in x
                    _inner(xx)
                end
            end
        end
    end
    for v in vec
        _inner(v)
    end
    return v2
end

parse_expr(expr) = (_flatten ∘ _parse_expr ∘ rmlines)(expr)

macro model(name::String, ns, expr::Expr)
    add_calls = parse_expr(expr)
    return (quote
        let ns = $(esc(ns))
            m = Model(name = $name)
            $(add_calls...)
            m
        end
    end |> rmlines)
end
