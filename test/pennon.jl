# Copyright (c) 2019: Benoît Legat and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

module TestPennon

using Test
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
    model = Penopt.Pennon.Optimizer()
    x = MOI.add_variable(model)
    MOI.set(model, MOI.VariablePrimalStart(), x, 0.5)
    MOI.set(model, MOI.ObjectiveSense(), MOI.MAX_SENSE)
    MOI.set(model, MOI.ObjectiveFunction{MOI.VariableIndex}(), x)
    square = MOI.ScalarNonlinearFunction(:^, Any[x, 2])
    entry = MOI.ScalarNonlinearFunction(:-, Any[1.0, square])
    matrix = MOI.VectorNonlinearFunction([entry])
    MOI.add_constraint(
        model,
        matrix,
        MOI.PositiveSemidefiniteConeTriangle(1),
    )
    MOI.set(model, MOI.Silent(), true)
    MOI.optimize!(model)
    @test MOI.get(model, MOI.TerminationStatus()) == MOI.LOCALLY_SOLVED
    @test MOI.get(model, MOI.PrimalStatus()) == MOI.FEASIBLE_POINT
    @test MOI.get(model, MOI.ObjectiveValue()) ≈ 1.0 atol = 1e-5
    @test MOI.get(model, MOI.VariablePrimal(), x) ≈ 1.0 atol = 1e-5
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
