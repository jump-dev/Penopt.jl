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

function test_solver_name()
    @test MOI.get(Penopt.Optimizer(), MOI.SolverName()) == "Penbmi"
end

function test_supports_default_copy_to()
    @test MOI.supports_incremental_interface(Penopt.Optimizer())
end

function test_options()
    param = MOI.RawOptimizerAttribute("bad_option")
    err = MOI.UnsupportedAttribute(param)
    @test_throws err MOI.set(
        Penopt.Optimizer(),
        MOI.RawOptimizerAttribute("bad_option"),
        0,
    )
end

function test_runtests()
    model = MOI.Utilities.CachingOptimizer(
        MOI.Utilities.UniversalFallback(MOI.Utilities.Model{Float64}()),
        MOI.instantiate(Penopt.Optimizer, with_bridge_type=Float64),
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
        exclude = String[
            # Unable to bridge RotatedSecondOrderCone to PSD because the dimension is too small: got 2, expected >= 3.
            "test_conic_SecondOrderCone_INFEASIBLE",
            "test_constraint_PrimalStart_DualStart_SecondOrderCone",
            # Infeasible not supported
            "test_conic_NormInfinityCone_INFEASIBLE",
            "test_conic_NormOneCone_INFEASIBLE",
            "test_conic_RotatedSecondOrderCone_INFEASIBLE",
            "test_conic_linear_INFEASIBLE",
            "test_conic_linear_INFEASIBLE_2",
            "test_linear_DUAL_INFEASIBLE",
            "test_linear_DUAL_INFEASIBLE_2",
            "test_linear_INFEASIBLE",
            "test_linear_INFEASIBLE_2",
            "test_solve_TerminationStatus_DUAL_INFEASIBLE",
            # To investigate
            "test_conic_SecondOrderCone_negative_post_bound_2",
            "test_conic_SecondOrderCone_negative_post_bound_3",
            "test_conic_SecondOrderCone_no_initial_bound",
            "test_constraint_ScalarAffineFunction_GreaterThan",
            "test_constraint_ScalarAffineFunction_LessThan",
            "test_constraint_ScalarAffineFunction_duplicate",
            "test_constraint_VectorAffineFunction_duplicate",
            "test_linear_LessThan_and_GreaterThan",
            "test_linear_VectorAffineFunction",
            "test_linear_VectorAffineFunction_empty_row",
            "test_linear_add_constraints",
            "test_linear_modify_GreaterThan_and_LessThan_constraints",
            "test_modification_affine_deletion_edge_cases",
            "test_modification_coef_scalar_objective",
            "test_modification_coef_scalaraffine_lessthan",
            "test_modification_const_scalar_objective",
            "test_modification_const_vectoraffine_nonpos",
            "test_modification_const_vectoraffine_zeros",
            "test_modification_delete_variable_with_single_variable_obj",
            "test_modification_func_scalaraffine_lessthan",
            "test_modification_func_vectoraffine_nonneg",
            "test_modification_set_scalaraffine_lessthan",
            "test_modification_set_singlevariable_lessthan",
            "test_modification_transform_singlevariable_lessthan",
            "test_objective_ObjectiveFunction_VariableIndex",
            "test_objective_ObjectiveFunction_blank",
            "test_objective_ObjectiveFunction_constant",
            "test_objective_ObjectiveFunction_duplicate_terms",
            "test_solve_result_index",
        ],
    )
    return
end

end  # module

TestPenbmi.runtests()
