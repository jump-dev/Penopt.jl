# Copyright (c) 2019: Benoît Legat and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

module TestPenbmi

using Test
using MathOptInterface
import Penopt

const MOI = MathOptInterface

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

# `Penopt.BMI.Optimizer` needs the commercial PENBMI library.
optimizers() =
    Penopt.has_penbmi() ? [Penopt.SDP.Optimizer, Penopt.BMI.Optimizer] :
    [Penopt.SDP.Optimizer]

function test_solver_name()
    @test MOI.get(Penopt.SDP.Optimizer(), MOI.SolverName()) == "Pensdp"
    @test MOI.get(Penopt.BMI.Optimizer(), MOI.SolverName()) == "Penbmi"
end

function test_supports_default_copy_to()
    for O in optimizers()
        @test MOI.supports_incremental_interface(O())
    end
end

function test_options()
    param = MOI.RawOptimizerAttribute("bad_option")
    err = MOI.UnsupportedAttribute(param)
    for O in optimizers()
        @test_throws err MOI.set(O(), param, 0)
    end
end

function test_runtests()
    for O in optimizers()
        @testset "$(O)" begin
            _test_runtests(O)
        end
    end
end

function _test_runtests(O)
    model = MOI.Utilities.CachingOptimizer(
        MOI.Utilities.UniversalFallback(MOI.Utilities.Model{Float64}()),
        MOI.instantiate(O, with_bridge_type=Float64),
    )
    MOI.set(model, MOI.Silent(), true)
    MOI.set(model, MOI.RawOptimizerAttribute("PBM_EPS"), 1e-2)
    MOI.set(model, MOI.RawOptimizerAttribute("P0"), 1e-2)
    MOI.Test.runtests(
        model,
        MOI.Test.Config(
            rtol = 1e-2,
            atol = 1e-2,
            optimal_status = MOI.LOCALLY_SOLVED,
            exclude = Any[
                MOI.ConstraintBasisStatus,
                MOI.VariableBasisStatus,
                MOI.ObjectiveBound,
                MOI.SolverVersion,
                MOI.DualStatus,
                MOI.ConstraintDual,
                MOI.DualObjectiveValue,
            ],
        ),
        exclude = Any[
            # Unable to bridge RotatedSecondOrderCone to PSD because the dimension is too small: got 2, expected >= 3.
            "test_conic_SecondOrderCone_INFEASIBLE",
            "test_constraint_PrimalStart_DualStart_SecondOrderCone",
            # Both PENSDP and PENBMI call `DSYEVX` with an illegal dimension on
            # the empty matrix and report `OTHER_ERROR`.
            "test_conic_empty_matrix",
            # Infeasible not supported
            "test_conic_NormInfinityCone_INFEASIBLE",
            "test_conic_NormOneCone_INFEASIBLE",
            r"test_conic_RotatedSecondOrderCone_INFEASIBLE$",
            r"test_conic_linear_INFEASIBLE$",
            "test_conic_linear_INFEASIBLE_2",
            r"test_linear_DUAL_INFEASIBLE$",
            "test_linear_DUAL_INFEASIBLE_2",
            r"test_linear_INFEASIBLE$",
            "test_linear_INFEASIBLE_2",
            "test_solve_TerminationStatus_DUAL_INFEASIBLE",
            # Unboundedness is not detected, the solver stops with `Unknown
            # error` instead.
            "test_conic_SecondOrderCone_negative_post_bound_2",
            "test_conic_SecondOrderCone_negative_post_bound_3",
            "test_conic_SecondOrderCone_no_initial_bound",
            # On a model without any matrix constraint, the outer loop never
            # meets its stopping criterion: it either exhausts the iteration
            # limit or the linesearch fails, so the status is `ITERATION_LIMIT`
            # or `NUMERICAL_ERROR` even though the point returned is optimal.
            # Adding any LMI to the same model gives `LOCALLY_SOLVED`.
            "test_linear_LessThan_and_GreaterThan",
            r"test_linear_VectorAffineFunction$",
            "test_linear_VectorAffineFunction_empty_row",
            "test_linear_add_constraints",
            "test_linear_modify_GreaterThan_and_LessThan_constraints",
            "test_modification_affine_deletion_edge_cases",
            "test_modification_coef_scalar_objective",
            "test_modification_coef_scalaraffine_lessthan",
            "test_modification_const_scalar_objective",
            "test_modification_const_vectoraffine_nonpos",
            "test_modification_delete_variable_with_single_variable_obj",
            "test_modification_func_scalaraffine_lessthan",
            "test_modification_func_vectoraffine_nonneg",
            "test_modification_set_scalaraffine_lessthan",
            "test_modification_set_singlevariable_lessthan",
            "test_modification_transform_singlevariable_lessthan",
            "test_objective_ObjectiveFunction_VariableIndex",
            "test_objective_ObjectiveFunction_blank",
            "test_solve_result_index",
        ],
    )
    return
end

end  # module

TestPenbmi.runtests()
