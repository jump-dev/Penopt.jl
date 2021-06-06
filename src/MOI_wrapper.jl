import LinearAlgebra

const IOPTIONS = String[
    "DEF",
    "PBM MAX ITER",
    "UM MAX ITER",
    "OUTPUT",
    "DENSE",
    "LS",
    "XOUT",
    "UOUT",
    "NWT_SYS_MODE",
    "PREC_TYPE",
    "DIMACS",
    "TR_MODE",
]
const FOPTIONS = String[
    "U0",
    "MU",
    "MU2",
    "PBM_EPS",
    "P_EPS",
    "UMIN",
    "ALPHA",
    "P0",
    "PEN_UP",
    "ALPHA_UP",
    "PRECISION_2",
    "CG_TOL_DIR",
]

mutable struct Optimizer <: MOI.AbstractOptimizer
    objective_sign::Cdouble
    objective_constant::Cdouble
    msizes::Vector{Cint}
    x0::Vector{Cdouble}
    fobj::Vector{Cdouble}
    q_col::Vector{Cint}
    q_row::Vector{Cint}
    q_val::Vector{Cdouble}
    ci::Vector{Cdouble}
    bi_dim::Vector{Cint}
    bi_idx::Vector{Cint}
    bi_val::Vector{Cdouble}
    ai_dim::Vector{Cint}
    ai_idx::Vector{Cint}
    ai_nzs::Vector{Cint}
    ai_val::Vector{Cdouble}
    ai_col::Vector{Cint}
    ai_row::Vector{Cint}
    ki_dim::Vector{Cint}
    ki_idx::Vector{Cint}
    kj_idx::Vector{Cint}
    ki_nzs::Vector{Cint}
    ki_val::Vector{Cdouble}
    ki_col::Vector{Cint}
    ki_row::Vector{Cint}
    fx::Cdouble
    x::Vector{Cdouble}
    uoutput::Vector{Cdouble}
    iresults::Vector{Cint}
    fresults::Vector{Cdouble}
    info::Cint
    ioptions::Vector{Cint}
    foptions::Vector{Cdouble}
    silent::Bool
    function Optimizer()
        return new(
            1.0,
            0.0,
            Cint[],
            Cdouble[],
            Cdouble[],
            Cint[],
            Cint[],
            Cdouble[],
            Cdouble[],
            Cint[],
            Cint[],
            Cdouble[],
            Cint[],
            Cint[],
            Cint[],
            Cdouble[],
            Cint[],
            Cint[],
            Cint[],
            Cint[],
            Cint[],
            Cint[],
            Cdouble[],
            Cint[],
            Cint[],
            NaN,
            Cdouble[],
            Cdouble[],
            Cint[],
            Cdouble[],
            -1,
            copy(DEFAULT_IOPTIONS),
            copy(DEFAULT_FOPTIONS),
            false,
        )
    end
end

MOI.get(::Optimizer, ::MOI.SolverName) = "Penbmi"

function MOI.supports(optimizer::Optimizer, param::MOI.RawParameter)
    return param.name in IOPTIONS || param.name in FOPTIONS
end
function MOI.set(optimizer::Optimizer, param::MOI.RawParameter, value)
    i = findfirst(isequal(param.name), IOPTIONS)
    if i !== nothing
        optimizer.ioptions[i] = value
        return
    end
    i = findfirst(isequal(param.name), FOPTIONS)
    if i !== nothing
        optimizer.foptions[i] = value
        return
    end
    return throw(MOI.UnsupportedAttribute(param))
end
function MOI.get(optimizer::Optimizer, param::MOI.RawParameter)
    i = findfirst(isequal(param.name), IOPTIONS)
    if i !== nothing
        return optimizer.ioptions[i]
    end
    i = findfirst(isequal(param.name), FOPTIONS)
    if i !== nothing
        return optimizer.foptions[i]
    end
    return throw(MOI.UnsupportedAttribute(param))
end

MOI.supports(::Optimizer, ::MOI.Silent) = true
function MOI.set(optimizer::Optimizer, ::MOI.Silent, value::Bool)
    return optimizer.silent = value
end
MOI.get(optimizer::Optimizer, ::MOI.Silent) = optimizer.silent

function MOI.is_empty(optimizer::Optimizer)
    return true
end
function MOI.empty!(optimizer::Optimizer)
    optimizer.objective_sign = 1.0
    optimizer.objective_constant = 0.0
    empty!(optimizer.msizes)
    empty!(optimizer.x0)
    empty!(optimizer.fobj)
    empty!(optimizer.q_col)
    empty!(optimizer.q_row)
    empty!(optimizer.q_val)
    empty!(optimizer.ci)
    empty!(optimizer.bi_dim)
    empty!(optimizer.bi_idx)
    empty!(optimizer.bi_val)
    empty!(optimizer.ai_dim)
    empty!(optimizer.ai_idx)
    empty!(optimizer.ai_nzs)
    empty!(optimizer.ai_val)
    empty!(optimizer.ai_col)
    empty!(optimizer.ai_row)
    empty!(optimizer.ki_dim)
    empty!(optimizer.ki_idx)
    empty!(optimizer.kj_idx)
    empty!(optimizer.ki_nzs)
    empty!(optimizer.ki_val)
    empty!(optimizer.ki_col)
    empty!(optimizer.ki_row)
    optimizer.fx = NaN
    empty!(optimizer.x)
    optimizer.info = -1
    return
end

function MOI.add_variable(optimizer::Optimizer)
    push!(optimizer.x0, 0.0)
    push!(optimizer.fobj, 0.0)
    return MOI.VariableIndex(length(optimizer.x0))
end

function MOI.supports(
    ::Optimizer,
    ::MOI.ObjectiveSense,
)
    return true
end
function MOI.set(
    optimizer::Optimizer,
    ::MOI.ObjectiveSense,
    sense::MOI.OptimizationSense,
)
    if sense == MOI.FEASIBILITY_SENSE
        optimizer.objective_sign = 1.0
        optimizer.objective_constant = 0.0
        fill!(optimizer.fobj, 0.0)
    elseif sense == MOI.MAX_SENSE
        if optimizer.objective_sign == 1.0
            LinearAlgebra.rmul!(optimizer.fobj, -1.0)
            LinearAlgebra.rmul!(optimizer.q_val, -1.0)
            optimizer.objective_sign = -1.0
        end
        @assert optimizer.objective_sign == -1.0
    else
        @assert sense == MOI.MIN_SENSE
        if optimizer.objective_sign == -1.0
            LinearAlgebra.rmul!(optimizer.fobj, -1.0)
            LinearAlgebra.rmul!(optimizer.q_val, -1.0)
            optimizer.objective_sign = 1.0
        end
        @assert optimizer.objective_sign == 1.0
    end
    return
end
function MOI.supports(
    ::Optimizer,
    ::MOI.ObjectiveFunction{MOI.ScalarQuadraticFunction{Cdouble}},
)
    return true
end
function MOI.set(
    optimizer::Optimizer,
    ::MOI.ObjectiveFunction{MOI.ScalarQuadraticFunction{Cdouble}},
    func::MOI.ScalarQuadraticFunction{Cdouble},
)
    func = MOI.Utilities.canonical(func)
    optimizer.objective_constant = func.constant
    fill!(optimizer.fobj, 0.0)
    for term in func.affine_terms
        optimizer.fobj[term.variable_index.value] = optimizer.objective_sign * term.coefficient
    end
    empty!(optimizer.q_val)
    empty!(optimizer.q_col)
    empty!(optimizer.q_row)
    for term in func.quadratic_terms
        col = term.variable_index_1.value
        row = term.variable_index_2.value
        if col < row
            col, row = row, col
        end
        push!(optimizer.q_val, optimizer.objective_sign * term.coefficient)
        push!(optimizer.q_col, col - 1)
        push!(optimizer.q_row, row - 1)
    end
    return
end

function MOI.supports(
    ::Optimizer,
    ::MOI.VariablePrimalStart,
    ::Type{MOI.VariableIndex},
)
    return true
end
function MOI.set(
    optimizer::Optimizer,
    ::MOI.VariablePrimalStart,
    vi::MOI.VariableIndex,
    value::Cdouble,
)
    optimizer.x0[vi.value] = value
    return
end
function MOI.set(
    optimizer::Optimizer,
    ::MOI.VariablePrimalStart,
    vi::MOI.VariableIndex,
    ::Nothing,
)
    optimizer.x0[vi.value] = 0.0
    return
end

function MOI.supports_constraint(
    optimizer::Optimizer,
    ::Type{MOI.ScalarAffineFunction{Cdouble}},
    ::Type{MOI.LessThan{Cdouble}},
)
    return true
end
function MOI.add_constraint(
    optimizer::Optimizer,
    func::MOI.ScalarAffineFunction{Cdouble},
    set::MOI.LessThan{Cdouble},
)
    if !iszero(func.constant)
        throw(
            MOI.ScalarFunctionConstantNotZero{Cdouble,typeof(func),typeof(set)}(
                func.constant,
            ),
        )
    end
    func = MOI.Utilities.canonical(func)
    push!(optimizer.bi_dim, length(func.terms))
    for term in func.terms
        push!(optimizer.bi_idx, term.variable_index.value - 1)
        push!(optimizer.bi_val, term.coefficient)
    end
    push!(optimizer.ci, set.upper)
    return MOI.ConstraintIndex{typeof(func),typeof(set)}(
        length(optimizer.bi_dim),
    )
end

function MOI.supports_constraint(
    optimizer::Optimizer,
    ::Type{MOI.VectorQuadraticFunction{Cdouble}},
    ::Type{MOI.PositiveSemidefiniteConeTriangle},
)
    return true
end
function _col_row(n)
    col = MOI.Utilities.side_dimension_for_vectorized_dimension(n)
    last = _tridim(col)
    if last < n
        col += 1
        offset = last
        last = _tridim(col)
    else
        offset = _tridim(col - 1)
    end
    @assert offset < n <= last
    return col, n - offset
end
# We want to group the same variables together so we give least priority to 'output_index`.
function _term_indices(t::Union{MOI.VectorAffineTerm,MOI.VectorQuadraticTerm})
    return (MOI.term_indices(t.scalar_term)..., t.output_index)
end
function push_a!(optimizer, cur_idx, idx, output_index, value)
    if cur_idx != idx
        cur_idx = idx
        optimizer.ai_dim[end] += 1
        push!(optimizer.ai_idx, idx)
        push!(optimizer.ai_nzs, 0)
    end
    optimizer.ai_nzs[end] += 1
    # Penbmi expects `⪯ 0` and MOI gives `⪰ 0` so we multiply by `-1`.
    push!(optimizer.ai_val, -value)
    col, row = _col_row(output_index)
    push!(optimizer.ai_col, col - 1)
    push!(optimizer.ai_row, row - 1)
    return cur_idx
end
function MOI.add_constraint(
    optimizer::Optimizer,
    func::MOI.VectorQuadraticFunction{Cdouble},
    set::MOI.PositiveSemidefiniteConeTriangle,
)
    push!(optimizer.msizes, set.side_dimension)
    push!(optimizer.ai_dim, 0)
    cur_idx = -1
    for i in eachindex(func.constants)
        if !iszero(func.constants[i])
            cur_idx = push_a!(optimizer, cur_idx, 0, i, func.constants[i])
        end
    end
    affine = copy(func.affine_terms)
    MOI.Utilities.sort_and_compress!(
        affine,
        _term_indices,
        t -> !iszero(MOI.coefficient(t)),
        MOI.Utilities.unsafe_add,
    )
    for term in affine
        cur_idx = push_a!(
            optimizer,
            cur_idx,
            term.scalar_term.variable_index.value,
            term.output_index,
            term.scalar_term.coefficient,
        )
    end
    push!(optimizer.ki_dim, 0)
    quad = copy(func.quadratic_terms)
    MOI.Utilities.sort_and_compress!(
        quad,
        _term_indices,
        t -> !iszero(MOI.coefficient(t)),
        MOI.Utilities.unsafe_add,
    )
    curi_idx = 0
    curj_idx = 0
    for term in quad
        sterm = term.scalar_term
        i_idx = sterm.variable_index_1.value
        j_idx = sterm.variable_index_2.value
        if curi_idx != i_idx || curj_idx != j_idx
            curi_idx = i_idx
            curj_idx = j_idx
            optimizer.ki_dim[end] += 1
            push!(optimizer.ki_idx, i_idx)
            push!(optimizer.kj_idx, j_idx)
            push!(optimizer.ki_nzs, 0)
        end
        optimizer.ki_nzs[end] += 1
        # Penbmi expects `⪯ 0` and MOI gives `⪰ 0` so we multiply by `-1`.
        push!(optimizer.ki_val, -sterm.coefficient)
        col, row = _col_row(term.output_index)
        push!(optimizer.ki_col, col - 1)
        push!(optimizer.ki_row, row - 1)
    end
    return MOI.ConstraintIndex{typeof(func),typeof(set)}(
        length(optimizer.msizes),
    )
end

# TODO This should be removed once we have a bridged
#      doing affine -> quadratic
function MOI.supports_constraint(
    optimizer::Optimizer,
    ::Type{MOI.VectorAffineFunction{Cdouble}},
    ::Type{MOI.PositiveSemidefiniteConeTriangle},
)
    return true
end
function MOI.add_constraint(
    optimizer::Optimizer,
    func::MOI.VectorAffineFunction{Cdouble},
    set::MOI.PositiveSemidefiniteConeTriangle,
)
    quad = convert(MOI.VectorQuadraticFunction{Cdouble}, func)
    ci = MOI.add_constraint(optimizer, quad, set)
    return MOI.ConstraintIndex{typeof(func),typeof(set)}(ci.value)
end

function MOI.optimize!(optimizer::Optimizer)
    ioptions = optimizer.ioptions
    if optimizer.silent
        ioptions = copy(ioptions)
        ioptions[4] = 0 # OUTPUT : no output
        ioptions[11] = 0 # DIMACS : no
    end
    optimizer.x = copy(optimizer.x0)
    return optimizer.fx,
    _,
    optimizer.uoutput,
    optimizer.iresults,
    optimizer.fresults,
    optimizer.info = penbmi(
        optimizer.msizes,
        optimizer.x,
        optimizer.fobj,
        optimizer.q_col,
        optimizer.q_row,
        optimizer.q_val,
        optimizer.ci,
        optimizer.bi_dim,
        optimizer.bi_idx,
        optimizer.bi_val,
        optimizer.ai_dim,
        optimizer.ai_idx,
        optimizer.ai_nzs,
        optimizer.ai_val,
        optimizer.ai_col,
        optimizer.ai_row,
        optimizer.ki_dim,
        optimizer.ki_idx,
        optimizer.kj_idx,
        optimizer.ki_nzs,
        optimizer.ki_val,
        optimizer.ki_col,
        optimizer.ki_row,
        ioptions,
        optimizer.foptions,
    )
end

function MOI.get(optimizer::Optimizer, ::MOI.SolveTime)
    return convert(Float64, optimizer.iresults[4])
end
const INFO = String[
    "No errors.",
    "Cholesky factorization of Hessian failed. The result may still be usefull.",
    "No progress in objective value, problem probably infeasible.",
    "Linesearch failed. The result may still be usefull.",
    "Maximum iteration limit exceeded. The result may still be usefull.",
    "Wrong input parameters (ioptions,foptions).",
    "Memory error.",
    "Unknown error, please contact PENOPT Gbr (contact @penopt.com).",
]
function MOI.get(optimizer::Optimizer, ::MOI.RawStatusString)
    return INFO[optimizer.info + 1]
end

"""
    NumberOfOuterIterations()

The number of outer iterations.
"""
struct NumberOfOuterIterations <: MOI.AbstractModelAttribute end
MOI.is_set_by_optimize(::NumberOfOuterIterations) = true
function MOI.get(optimizer::Optimizer, ::NumberOfOuterIterations)
    return optimizer.iresults[1]
end

"""
    NumberOfNewtonSteps()

The number of Newton steps.
"""
struct NumberOfNewtonSteps <: MOI.AbstractModelAttribute end
MOI.is_set_by_optimize(::NumberOfNewtonSteps) = true
function MOI.get(optimizer::Optimizer, ::NumberOfNewtonSteps)
    return optimizer.iresults[2]
end

"""
    NumberOfLinesearchSteps()

The number of linesearch steps.
"""
struct NumberOfLinesearchSteps <: MOI.AbstractModelAttribute end
MOI.is_set_by_optimize(::NumberOfLinesearchSteps) = true
function MOI.get(optimizer::Optimizer, ::NumberOfLinesearchSteps)
    return optimizer.iresults[3]
end

function MOI.get(optimizer::Optimizer, ::MOI.TerminationStatus)
    s = optimizer.info
    @assert -1 <= s <= 7
    if s == -1
        return MOI.OPTIMIZE_NOT_CALLED
    elseif s == 0
        return MOI.LOCALLY_SOLVED
    elseif s == 4
        return MOI.ITERATION_LIMIT
    elseif s == 5
        return MOI.INVALID_OPTION
    elseif s == 6
        return MOI.MEMORY_LIMIT
    elseif s == 7
        return MOI.OTHER_ERROR
    else
        return MOI.NUMERICAL_ERROR
    end
end

function MOI.get(optimizer::Optimizer, attr::MOI.ObjectiveValue)
    MOI.check_result_index_bounds(optimizer, attr)
    return optimizer.objective_sign * optimizer.fx + optimizer.objective_constant
end

function MOI.get(optimizer::Optimizer, attr::Union{MOI.PrimalStatus, MOI.DualStatus})
    if attr.N > MOI.get(optimizer, MOI.ResultCount())
        return MOI.NO_SOLUTION
    end
    s = optimizer.info
    @assert 0 <= s <= 7 && s != 5
    if s == 0
        return MOI.FEASIBLE_POINT
    else
        return MOI.UNKNOWN_RESULT_STATUS
    end
end
function MOI.get(optimizer::Optimizer, attr::MOI.VariablePrimal, vi::MOI.VariableIndex)
    MOI.check_result_index_bounds(optimizer, attr)
    return optimizer.x[vi.value]
end

function MOI.get(optimizer::Optimizer, ::MOI.ResultCount)
    return optimizer.info in [-1, 5] ? 0 : 1
end
