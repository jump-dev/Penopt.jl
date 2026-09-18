# Copyright (c) 2019: Benoît Legat and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

# PENNON uses callbacks with Fortran-style output arguments. The C interface is
# not re-entrant, so keeping the callback state in the opaque user-data pointer
# also documents that one PENNON solve is active at a time.
mutable struct _PennonCallbackState
    evaluator::Any
    n::Int
    constraint_values::Vector{Cdouble}
    callback_error::Any
end

function _pennon_state(data::Ptr{Cvoid})
    return unsafe_pointer_to_objref(data)::_PennonCallbackState
end

function _pennon_x(state, x)
    return unsafe_wrap(Vector{Cdouble}, x, state.n; own = false)
end

function _pennon_callback(f, state, default)
    try
        return f()
    catch err
        state.callback_error = (err, catch_backtrace())
        return default
    end
end

function _pennon_f(x, value, data)::Cvoid
    state = _pennon_state(data)
    v = _pennon_callback(state, NaN) do
        MOI.eval_objective(state.evaluator, _pennon_x(state, x))
    end
    unsafe_store!(value, v)
    return
end

function _pennon_df(x, nnz, index, value, data)::Cvoid
    state = _pennon_state(data)
    _pennon_callback(state, nothing) do
        structure = 1:state.n
        gradient = unsafe_wrap(Vector{Cdouble}, value, length(structure); own = false)
        MOI.eval_objective_gradient(state.evaluator, gradient, _pennon_x(state, x))
        unsafe_store!(nnz, Cint(length(structure)))
        for (i, j) in enumerate(structure)
            unsafe_store!(index, Cint(j), i)
        end
    end
    return
end

function _pennon_hessian!(evaluate, state, row, col, value, structure)
    values = unsafe_wrap(Vector{Cdouble}, value, length(structure); own = false)
    evaluate(values)
    for (k, (i, j)) in enumerate(structure)
        unsafe_store!(row, Cint(i), k)
        unsafe_store!(col, Cint(j), k)
    end
    return
end

function _pennon_hf(x, nnz, row, col, value, data)::Cvoid
    state = _pennon_state(data)
    _pennon_callback(state, nothing) do
        structure = MOI.hessian_objective_structure(state.evaluator)
        unsafe_store!(nnz, Cint(length(structure)))
        _pennon_hessian!(state, row, col, value, structure) do values
            MOI.eval_hessian_objective(
                state.evaluator,
                values,
                _pennon_x(state, x),
            )
        end
    end
    return
end

function _pennon_g(index, x, value, data)::Cvoid
    state = _pennon_state(data)
    _pennon_callback(state, nothing) do
        MOI.eval_constraint(
            state.evaluator,
            state.constraint_values,
            _pennon_x(state, x),
        )
        unsafe_store!(value, state.constraint_values[unsafe_load(index)+1])
    end
    return
end

function _pennon_dg(index, x, nnz, variable, value, data)::Cvoid
    state = _pennon_state(data)
    _pennon_callback(state, nothing) do
        i = unsafe_load(index) + 1
        structure = MOI.constraint_gradient_structure(state.evaluator, i)
        gradient = unsafe_wrap(Vector{Cdouble}, value, length(structure); own = false)
        MOI.eval_constraint_gradient(
            state.evaluator,
            gradient,
            _pennon_x(state, x),
            i,
        )
        unsafe_store!(nnz, Cint(length(structure)))
        for (k, j) in enumerate(structure)
            unsafe_store!(variable, Cint(j), k)
        end
    end
    return
end

function _pennon_hg(index, x, nnz, row, col, value, data)::Cvoid
    state = _pennon_state(data)
    _pennon_callback(state, nothing) do
        i = unsafe_load(index) + 1
        structure = MOI.hessian_constraint_structure(state.evaluator, i)
        unsafe_store!(nnz, Cint(length(structure)))
        _pennon_hessian!(state, row, col, value, structure) do values
            MOI.eval_hessian_constraint(
                state.evaluator,
                values,
                _pennon_x(state, x),
                i,
            )
        end
    end
    return
end

const _PENNON_F = Ref{Ptr{Cvoid}}(C_NULL)
const _PENNON_DF = Ref{Ptr{Cvoid}}(C_NULL)
const _PENNON_HF = Ref{Ptr{Cvoid}}(C_NULL)
const _PENNON_G = Ref{Ptr{Cvoid}}(C_NULL)
const _PENNON_DG = Ref{Ptr{Cvoid}}(C_NULL)
const _PENNON_HG = Ref{Ptr{Cvoid}}(C_NULL)
const _PENNON_LOCK = ReentrantLock()

function _init_pennon_callbacks!()
    _PENNON_F[] = @cfunction(
        _pennon_f,
        Cvoid,
        (Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cvoid}),
    )
    _PENNON_DF[] = @cfunction(
        _pennon_df,
        Cvoid,
        (Ptr{Cdouble}, Ptr{Cint}, Ptr{Cint}, Ptr{Cdouble}, Ptr{Cvoid}),
    )
    _PENNON_HF[] = @cfunction(
        _pennon_hf,
        Cvoid,
        (Ptr{Cdouble}, Ptr{Cint}, Ptr{Cint}, Ptr{Cint}, Ptr{Cdouble}, Ptr{Cvoid}),
    )
    _PENNON_G[] = @cfunction(
        _pennon_g,
        Cvoid,
        (Ptr{Cint}, Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cvoid}),
    )
    _PENNON_DG[] = @cfunction(
        _pennon_dg,
        Cvoid,
        (Ptr{Cint}, Ptr{Cdouble}, Ptr{Cint}, Ptr{Cint}, Ptr{Cdouble}, Ptr{Cvoid}),
    )
    _PENNON_HG[] = @cfunction(
        _pennon_hg,
        Cvoid,
        (
            Ptr{Cint},
            Ptr{Cdouble},
            Ptr{Cint},
            Ptr{Cint},
            Ptr{Cint},
            Ptr{Cdouble},
            Ptr{Cvoid},
        ),
    )
    return
end

const PENNON_INFINITY = 1.0e38
const DEFAULT_PENNON_IOPTIONS = Cint[
    100, 100, 2, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, -1, 0, 1, 0, 0, 0, 0, 0,
]
const DEFAULT_PENNON_DOPTIONS = Cdouble[
    1e-2, 1.0, 1.0, 1e-2, 0.5, 0.5, 1e-6, 1e-12, 1e-7, 0.05, 1.0, 1.0,
    1.0, 1.0,
]

mutable struct PennonOptimizer <: MOI.AbstractOptimizer
    num_variables::Int
    x0::Vector{Cdouble}
    objective::MOI.ScalarNonlinearFunction
    objective_sign::Cdouble
    constraints::Vector{Tuple{MOI.ScalarNonlinearFunction,Any}}
    matrix_functions::Vector{MOI.VectorNonlinearFunction}
    matrix_sizes::Vector{Cint}
    x::Vector{Cdouble}
    objective_value::Cdouble
    info::Cint
    ioptions::Vector{Cint}
    doptions::Vector{Cdouble}
    silent::Bool
    function PennonOptimizer()
        return new(
            0,
            Cdouble[],
            convert(MOI.ScalarNonlinearFunction, 0.0),
            1.0,
            Tuple{MOI.ScalarNonlinearFunction,Any}[],
            MOI.VectorNonlinearFunction[],
            Cint[],
            Cdouble[],
            NaN,
            -1,
            copy(DEFAULT_PENNON_IOPTIONS),
            copy(DEFAULT_PENNON_DOPTIONS),
            false,
        )
    end
end

MOI.get(::PennonOptimizer, ::MOI.SolverName) = "Pennon"

# MOI's FunctionConversionBridge does not yet implement conversion to
# VectorNonlinearFunction. Keep this conversion in a bridge, not the optimizer.
struct _PennonNonlinearPSDBridge <:
       MOI.Bridges.Constraint.AbstractFunctionConversionBridge{
    MOI.VectorNonlinearFunction,
    MOI.PositiveSemidefiniteConeTriangle,
}
    constraint::MOI.ConstraintIndex{
        MOI.VectorNonlinearFunction,
        MOI.PositiveSemidefiniteConeTriangle,
    }
end

function MOI.get(
    ::PennonOptimizer,
    ::MOI.Bridges.ListOfNonstandardBridges{Cdouble},
)
    return Type[_PennonNonlinearPSDBridge]
end

function MOI.supports_constraint(
    ::Type{_PennonNonlinearPSDBridge},
    ::Type{<:Union{
        MOI.VectorOfVariables,
        MOI.VectorAffineFunction{Cdouble},
        MOI.VectorQuadraticFunction{Cdouble},
    }},
    ::Type{MOI.PositiveSemidefiniteConeTriangle},
)
    return true
end

function MOI.Bridges.Constraint.concrete_bridge_type(
    ::Type{_PennonNonlinearPSDBridge},
    ::Type{<:MOI.AbstractVectorFunction},
    ::Type{MOI.PositiveSemidefiniteConeTriangle},
)
    return _PennonNonlinearPSDBridge
end

function MOI.Bridges.Constraint.bridge_constraint(
    ::Type{_PennonNonlinearPSDBridge},
    model::MOI.ModelLike,
    f::MOI.AbstractVectorFunction,
    set::MOI.PositiveSemidefiniteConeTriangle,
)
    g = MOI.VectorNonlinearFunction(
        MOI.ScalarNonlinearFunction[row for row in MOI.Utilities.eachscalar(f)],
    )
    return _PennonNonlinearPSDBridge(MOI.add_constraint(model, g, set))
end

MOI.Bridges.bridging_cost(::Type{_PennonNonlinearPSDBridge}) = 100.0

MOI.supports_incremental_interface(::PennonOptimizer) = true
MOI.copy_to(dest::PennonOptimizer, src::MOI.ModelLike) =
    MOI.Utilities.default_copy_to(dest, src)

function MOI.is_empty(model::PennonOptimizer)
    return model.num_variables == 0 && isempty(model.constraints) &&
           isempty(model.matrix_functions)
end

function MOI.empty!(model::PennonOptimizer)
    model.num_variables = 0
    empty!(model.x0)
    model.objective = convert(MOI.ScalarNonlinearFunction, 0.0)
    model.objective_sign = 1.0
    empty!(model.constraints)
    empty!(model.matrix_functions)
    empty!(model.matrix_sizes)
    empty!(model.x)
    model.objective_value = NaN
    model.info = -1
    return
end

function MOI.add_variable(model::PennonOptimizer)
    model.num_variables += 1
    push!(model.x0, 0.0)
    return MOI.VariableIndex(model.num_variables)
end
MOI.get(model::PennonOptimizer, ::MOI.NumberOfVariables) = model.num_variables

MOI.supports(::PennonOptimizer, ::MOI.Silent) = true
MOI.get(model::PennonOptimizer, ::MOI.Silent) = model.silent
MOI.set(model::PennonOptimizer, ::MOI.Silent, value::Bool) = model.silent = value

MOI.supports(::PennonOptimizer, ::MOI.ObjectiveSense) = true
function MOI.set(model::PennonOptimizer, ::MOI.ObjectiveSense, sense)
    model.objective_sign = sense == MOI.MAX_SENSE ? -1.0 : 1.0
    if sense == MOI.FEASIBILITY_SENSE
        model.objective = convert(MOI.ScalarNonlinearFunction, 0.0)
    end
    return
end

# Only accept nonlinear functions and let MOI bridges convert affine and
# quadratic inputs. TODO: add native quadratic support once
# https://github.com/jump-dev/MathOptInterface.jl/pull/3048 lands, so that we can
# use specialized quadratic AD instead of the slightly slower nonlinear AD.
function MOI.supports(
    ::PennonOptimizer,
    ::MOI.ObjectiveFunction{MOI.ScalarNonlinearFunction},
)
    return true
end
function MOI.set(
    model::PennonOptimizer,
    ::MOI.ObjectiveFunction{MOI.ScalarNonlinearFunction},
    f::MOI.ScalarNonlinearFunction,
)
    model.objective = f
    return
end

function MOI.supports(
    ::PennonOptimizer,
    ::MOI.VariablePrimalStart,
    ::Type{MOI.VariableIndex},
)
    return true
end
function MOI.set(
    model::PennonOptimizer,
    ::MOI.VariablePrimalStart,
    x::MOI.VariableIndex,
    value,
)
    model.x0[x.value] = value === nothing ? 0.0 : value
    return
end

const _PENNON_SCALAR_SETS = Union{
    MOI.LessThan{Cdouble},
    MOI.GreaterThan{Cdouble},
    MOI.EqualTo{Cdouble},
    MOI.Interval{Cdouble},
}

function MOI.supports_constraint(
    ::PennonOptimizer,
    ::Type{MOI.ScalarNonlinearFunction},
    ::Type{S},
) where {S<:_PENNON_SCALAR_SETS}
    return true
end

function MOI.add_constraint(
    model::PennonOptimizer,
    f::MOI.ScalarNonlinearFunction,
    set::S,
) where {S<:_PENNON_SCALAR_SETS}
    push!(model.constraints, (f, set))
    return MOI.ConstraintIndex{MOI.ScalarNonlinearFunction,S}(
        length(model.constraints),
    )
end

function MOI.supports_constraint(
    ::PennonOptimizer,
    ::Type{MOI.VectorNonlinearFunction},
    ::Type{MOI.PositiveSemidefiniteConeTriangle},
)
    return true
end

function MOI.add_constraint(
    model::PennonOptimizer,
    f::MOI.VectorNonlinearFunction,
    set::MOI.PositiveSemidefiniteConeTriangle,
)
    MOI.output_dimension(f) == MOI.dimension(set) ||
        throw(MOI.DimensionMismatch("Function dimension does not match cone"))
    push!(model.matrix_functions, f)
    push!(model.matrix_sizes, set.side_dimension)
    return MOI.ConstraintIndex{typeof(f),typeof(set)}(length(model.matrix_sizes))
end

function _pennon_bounds(set::MOI.LessThan)
    return -PENNON_INFINITY, set.upper
end
function _pennon_bounds(set::MOI.GreaterThan)
    return set.lower, PENNON_INFINITY
end
_pennon_bounds(set::MOI.EqualTo) = (set.value, set.value)
_pennon_bounds(set::MOI.Interval) = (set.lower, set.upper)

function _pennon_evaluator(model::PennonOptimizer)
    data = MOI.Nonlinear.Model()
    objective = MOI.ScalarNonlinearFunction(
        :*,
        Any[model.objective_sign, model.objective],
    )
    MOI.Nonlinear.set_objective(data, objective)
    lower = Cdouble[]
    upper = Cdouble[]
    for (f, set) in model.constraints
        MOI.Nonlinear.add_constraint(data, f, set)
        l, u = _pennon_bounds(set)
        push!(lower, l)
        push!(upper, u)
    end
    slack = model.num_variables
    for f in model.matrix_functions
        for row in f.rows
            slack += 1
            equality = MOI.ScalarNonlinearFunction(
                :-,
                Any[row, MOI.VariableIndex(slack)],
            )
            MOI.Nonlinear.add_constraint(data, equality, MOI.EqualTo(0.0))
            push!(lower, 0.0)
            push!(upper, 0.0)
        end
    end
    variables = MOI.VariableIndex.(1:slack)
    evaluator = MOI.Nonlinear.Evaluator(
        data,
        MOI.Nonlinear.SparseReverseMode(),
        variables,
    )
    MOI.initialize(evaluator, [:Grad, :Jac, :Hess])
    return evaluator, lower, upper
end

function _pennon_call!(model::PennonOptimizer, evaluator, lower, upper)
    has_pennon() || error(
        "PENNON is not available. Set `PENOPT_LIBPENNON` to the path of " *
        "`libpennon` and re-run `Pkg.build(\"Penopt\")`.",
    )
    n = model.num_variables + sum(_tridim, model.matrix_sizes; init = 0)
    nconstr = length(lower)
    nlin = 0
    nsdp = length(model.matrix_sizes)
    lbv = fill(Cdouble(-PENNON_INFINITY), n)
    ubv = fill(Cdouble(PENNON_INFINITY), n)
    lbmv = zeros(Cdouble, nsdp)
    ubmv = fill(Cdouble(PENNON_INFINITY), nsdp)
    # Keep the matrix variables explicit. PENNON's automatic slack-removal
    # mode assumes a library-specific linear callback representation, whereas
    # these equalities are supplied through the general nonlinear callbacks.
    mtype = zeros(Cint, nsdp)
    mnzs = Cint[_tridim(s) for s in model.matrix_sizes]
    mrow = Cint[]
    mcol = Cint[]
    for side in model.matrix_sizes, col in 0:(side-1), row in 0:col
        push!(mrow, row)
        push!(mcol, col)
    end
    model.x = vcat(model.x0, zeros(Cdouble, n - model.num_variables))
    multipliers = zeros(Cdouble, max(1, 2n + 2nconstr))
    state = _PennonCallbackState(evaluator, n, zeros(nconstr), nothing)
    ioptions = copy(model.ioptions)
    if model.silent
        ioptions[3] = 0
    end
    data = pointer_from_objref(state)
    lock(_PENNON_LOCK) do
        model.info = GC.@preserve state ccall(
            (:pennlp, libpennon),
            Cint,
            (
                Cint, Cint, Cint, Cint, Ptr{Cint}, Cint, Cint,
                Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble},
                Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cint}, Ptr{Cint}, Ptr{Cint},
                Ptr{Cint}, Ptr{Cdouble}, Ptr{Cdouble},
                Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid},
                Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid},
                Ptr{Cvoid}, Ptr{Cint}, Ptr{Cdouble}, Ptr{Cvoid}, Ptr{Cvoid},
                Ptr{Cvoid}, Ptr{Cvoid},
            ),
            n, nlin, nconstr, nsdp, model.matrix_sizes, n, n * (n + 1) ÷ 2,
            lbv, ubv, lower, upper, lbmv, ubmv, mtype, mnzs, mrow, mcol,
            model.x, multipliers,
            _PENNON_F[], _PENNON_DF[], _PENNON_HF[], C_NULL,
            _PENNON_G[], _PENNON_DG[], _PENNON_HG[], C_NULL,
            C_NULL, C_NULL, C_NULL, ioptions, model.doptions,
            C_NULL, C_NULL, data, C_NULL,
        )
    end
    if state.callback_error !== nothing
        err, bt = state.callback_error
        throw(CapturedException(err, bt))
    end
    model.objective_value = MOI.eval_objective(
        evaluator,
        view(model.x, 1:n),
    ) * model.objective_sign
    return
end

function MOI.optimize!(model::PennonOptimizer)
    evaluator, lower, upper = _pennon_evaluator(model)
    _pennon_call!(model, evaluator, lower, upper)
    return
end

MOI.get(model::PennonOptimizer, ::MOI.RawStatusString) =
    model.info == -1 ? "Optimize not called" : "PENNON return code $(model.info)"

function MOI.get(model::PennonOptimizer, ::MOI.TerminationStatus)
    model.info == -1 && return MOI.OPTIMIZE_NOT_CALLED
    model.info == 0 && return MOI.LOCALLY_SOLVED
    return MOI.OTHER_ERROR
end

MOI.get(model::PennonOptimizer, ::MOI.ResultCount) = model.info == -1 ? 0 : 1
function MOI.get(model::PennonOptimizer, attr::MOI.ObjectiveValue)
    MOI.check_result_index_bounds(model, attr)
    return model.objective_value
end
function MOI.get(model::PennonOptimizer, attr::MOI.VariablePrimal, x::MOI.VariableIndex)
    MOI.check_result_index_bounds(model, attr)
    return model.x[x.value]
end
function MOI.get(model::PennonOptimizer, attr::MOI.PrimalStatus)
    attr.result_index > MOI.get(model, MOI.ResultCount()) && return MOI.NO_SOLUTION
    return model.info == 0 ? MOI.FEASIBLE_POINT : MOI.UNKNOWN_RESULT_STATUS
end

module Pennon

import ..Penopt

"""
    Penopt.Pennon.Optimizer()

Optimizer for nonlinear semidefinite programs. Matrix constraints are accepted
as `MOI.VectorNonlinearFunction`-in-`MOI.PositiveSemidefiniteConeTriangle` and
their derivatives are supplied to PENNON by MOI's sparse reverse-mode AD.
"""
const Optimizer = Penopt.PennonOptimizer

end # module Pennon
