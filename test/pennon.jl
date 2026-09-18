# Copyright (c) 2019: Benoît Legat and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

module TestPennon

using Test
using LinearAlgebra
using JuMP
import MathOptInterface as MOI
import Penopt

function test_interface()
    model = Penopt.Pennon.Optimizer()
    @test MOI.get(model, MOI.SolverName()) == "Pennon"
    @test MOI.supports_incremental_interface(model)
    @test MOI.supports(
        model,
        MOI.ObjectiveFunction{MOI.ScalarNonlinearFunction}(),
    )
    @test MOI.supports_constraint(
        model,
        MOI.VectorNonlinearFunction,
        MOI.PositiveSemidefiniteConeTriangle,
    )
    MOI.set(model, MOI.Silent(), true)
    MOI.add_variable(model)
    MOI.empty!(model)
    @test MOI.is_empty(model)
    @test MOI.get(model, MOI.Silent())
    return
end

function test_scalar_constraint_dispatch()
    model = Penopt.Pennon.Optimizer()
    x = MOI.add_variable(model)
    @test MOI.get(model, MOI.NumberOfVariables()) == 1
    variable_ci = MOI.add_constraint(model, x, MOI.LessThan(2.0))
    @test variable_ci ==
          MOI.ConstraintIndex{MOI.VariableIndex,MOI.LessThan{Float64}}(1)
    f = MOI.ScalarNonlinearFunction(:sin, Any[x])
    ci = MOI.add_constraint(model, f, MOI.GreaterThan(0.0))
    @test ci == MOI.ConstraintIndex{
        MOI.ScalarNonlinearFunction,
        MOI.GreaterThan{Float64},
    }(2)
    return
end

function test_vector_nonlinear_function()
    Penopt.has_pennon() || return
    model = Model(Penopt.Pennon.Optimizer)
    set_silent(model)
    @variable(model, x, start = 0.5)
    @objective(model, Max, x)
    @expression(model, entry, @force_nonlinear(1 - x^2))
    @constraint(model, [entry] in MOI.PositiveSemidefiniteConeTriangle(1))
    optimize!(model)
    @test termination_status(model) == MOI.LOCALLY_SOLVED
    @test primal_status(model) == MOI.FEASIBLE_POINT
    @test objective_value(model) ≈ 1.0 atol = 1e-5
    @test value(x) ≈ 1.0 atol = 1e-5
    return
end

function _solve_and_check(model)
    optimize!(model)
    @test termination_status(model) == MOI.LOCALLY_SOLVED
    @test primal_status(model) == MOI.FEASIBLE_POINT
    @test result_count(model) == 1
    return
end

# The next two problems use (39) and (40) in Kočvara and Stingl,
# "PENNON: Software for linear and nonlinear matrix inequalities", §5.4:
# https://arxiv.org/pdf/1504.07212
# Use a small, symmetric instance with an analytic solution instead of the
# paper's rounded 6-by-6 numerical results. Conjugating by D=diag(1,-1,1) preserves
# the eigenvalues and makes the packed off-diagonal entries distinguishable.
function test_nearest_correlation_matrix()
    Penopt.has_pennon() || return
    model = Model(Penopt.Pennon.Optimizer)
    set_silent(model)
    @variable(model, X[i = 1:3, j = 1:3], Symmetric, start = Float64(i == j))
    H = [1.0 1.0 -1.0; 1.0 1.0 1.0; -1.0 1.0 1.0]
    @objective(
        model,
        Min,
        @force_nonlinear(
            sum((X[i, j] - H[i, j])^2 for i in 1:3, j in 1:3),
        ),
    )
    @constraint(model, [i in 1:3], X[i, i] == 1)
    # Explicit nonlinear entries exercise the VectorNonlinearFunction backend
    # even when a particular PSD constraint happens to be affine.
    @constraint(model, Symmetric(convert.(NonlinearExpr, X)) in PSDCone())
    _solve_and_check(model)
    solution = value.(X)
    # In the sign-transformed coordinates all off-diagonals equal -1/2:
    # the PSD bound 1 + 2r >= 0 is active. The squared Frobenius distance is 3/2.
    expected = [1.0 0.5 -0.5; 0.5 1.0 0.5; -0.5 0.5 1.0]
    @test solution ≈ expected atol = 1e-5
    @test diag(solution) ≈ ones(3) atol = 1e-6
    @test eigmin(solution) >= -1e-6
    @test objective_value(model) ≈ 1.5 atol = 1e-5
    @test objective_value(model) ≈ sum(abs2, solution - H) atol = 1e-8
    return
end

function test_conditioned_correlation_matrix()
    Penopt.has_pennon() || return
    model = Model(Penopt.Pennon.Optimizer)
    set_silent(model)
    @variable(model, Y[i = 1:3, j = 1:3], Symmetric, start = 2.0 * (i == j))
    @variable(model, 1 <= zeta <= 4, start = 2.0)
    H = [1.0 1.0 -1.0; 1.0 1.0 1.0; -1.0 1.0 1.0]
    @objective(
        model,
        Min,
        sum((Y[i, j] / zeta - H[i, j])^2 for i in 1:3, j in 1:3),
    )
    @constraint(model, [i in 1:3], Y[i, i] == zeta)
    # Both spectral bounds are separate PSD blocks, as in (40).
    @constraint(model, Symmetric(convert.(NonlinearExpr, Y - I)) in PSDCone())
    @constraint(model, Symmetric(convert.(NonlinearExpr, 4I - Y)) in PSDCone())
    _solve_and_check(model)
    solution = value.(Y)
    X = solution / value(zeta)
    # Eigenvalues of the sign-transformed correlation matrix are 1+2r and
    # 1-r. Their ratio is 4 at r=-1/3, giving zeta=3 and squared distance 8/3.
    expected = [1.0 1/3 -1/3; 1/3 1.0 1/3; -1/3 1/3 1.0]
    @test X ≈ expected atol = 1e-5
    @test value(zeta) ≈ 3.0 atol = 1e-5
    @test diag(X) ≈ ones(3) atol = 1e-6
    @test eigmin(solution) >= 1.0 - 1e-5
    @test eigmax(solution) <= 4.0 + 1e-5
    @test cond(X) ≈ 4.0 atol = 1e-4
    @test objective_value(model) ≈ 8 / 3 atol = 1e-5
    @test objective_value(model) ≈ sum(abs2, X - H) atol = 1e-8
    return
end

# A one-interval instance of the nonnegative spline formulation (45)-(50),
# §5.5 of https://arxiv.org/pdf/1504.07212. The data are exact samples of
# (t-1/2)^2 + 1/4, so the independent optimum is zero residual.
function test_nonnegative_spline()
    Penopt.has_pennon() || return
    model = Model(Penopt.Pennon.Optimizer)
    set_silent(model)
    @variable(model, X[i = 1:2, j = 1:2], Symmetric, start = Float64(i == j))
    @variable(model, S[i = 1:2, j = 1:2], Symmetric, start = Float64(i == j))
    @constraint(model, Symmetric(convert.(NonlinearExpr, X)) in PSDCone())
    @constraint(model, Symmetric(convert.(NonlinearExpr, S)) in PSDCone())
    @expression(
        model,
        coefficients,
        [
            S[1, 1],
            X[1, 1] - S[1, 1] + 2S[1, 2],
            2X[1, 2] - 2S[1, 2] + S[2, 2],
            X[2, 2] - S[2, 2],
        ],
    )
    samples = collect(0.0:0.25:1.0)
    @expression(
        model,
        prediction[t in samples],
        sum(coefficients[k] * t^(k - 1) for k in 1:4),
    )
    @objective(
        model,
        Min,
        @force_nonlinear(
            sum((prediction[t] - ((t - 0.5)^2 + 0.25))^2 for t in samples),
        ),
    )
    _solve_and_check(model)
    c = value.(coefficients)
    @test c ≈ [0.5, -1.0, 1.0, 0.0] atol = 1e-4
    @test eigmin(value.(X)) >= -1e-6
    @test eigmin(value.(S)) >= -1e-6
    residual = sum((evalpoly(t, c) - ((t - 0.5)^2 + 0.25))^2 for t in samples)
    @test residual <= 1e-8
    @test objective_value(model) ≈ residual atol = 1e-10
    @test minimum(evalpoly(t, c) for t in 0.0:0.01:1.0) >= 0.0
    return
end

function test_nonlinear_matrix_off_diagonal()
    Penopt.has_pennon() || return
    model = Model(Penopt.Pennon.Optimizer)
    set_silent(model)
    @variable(model, x, start = 0.2)
    @variable(model, y, start = 0.4)
    @objective(model, Max, x + 2y)
    @expression(model, matrix, [1-x^2 x*y; x*y 1-y^2])
    @constraint(model, Symmetric(convert.(NonlinearExpr, matrix)) in PSDCone())
    # This matrix is PSD exactly when x^2 + y^2 <= 1. Cauchy-Schwarz
    # gives the unique maximizer (1,2)/sqrt(5) and objective sqrt(5).
    _solve_and_check(model)
    xv, yv = value(x), value(y)
    @test [xv, yv] ≈ [1.0, 2.0] / sqrt(5.0) atol = 1e-5
    @test xv^2 + yv^2 <= 1.0 + 1e-6
    @test eigmin(Symmetric([1-xv^2 xv*yv; xv*yv 1-yv^2])) >= -1e-6
    @test objective_value(model) ≈ sqrt(5.0) atol = 1e-5
    return
end

function runtests()
    for name in names(@__MODULE__; all = true)
        if startswith("$(name)", "test_")
            @testset "$(name)" begin
                getfield(@__MODULE__, name)()
            end
        end
    end
    return
end

end # module TestPennon

TestPennon.runtests()
