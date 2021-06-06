# Example taken from `PENBMI2.1/c/driver_bmi_c.c`.
# Similar to Example 3 of http://www.penopt.com/doc/penbmi2_1.pdf except that we add (x1 - x2)^2/2 in the objective
using Test
using Penopt

import MathOptInterface
const MOI = MathOptInterface

function example3()
    msizes = Cint[3]
    x0 = zeros(Cdouble, 3)
    fobj = Cdouble[0.0, 0.0, 1.0]

    q_col = Cint[0, 1, 1]
    q_row = Cint[0, 0, 1]
    q_val = Cdouble[1.0, -1.0, 1.0]

    # x1 ∈ [-0.5, 2] and x2 ∈ [-3, 7]
    ci = Cdouble[0.5, 2.0, 3.0, 7.0]
    bi_dim = ones(Cint, 4)
    bi_idx = Cint[0, 0, 1, 1]
    bi_val = Cdouble[-1.0, 1.0, -1.0, 1.0]

    ai_dim = Cint[4]
    ai_idx = Cint[0, 1, 2, 3]
    ai_nzs = Cint[4, 4, 5, 3]
    ai_col = Cint[0, 1, 1, 2, 0, 1, 2, 2, 0, 1, 1, 2, 2, 0, 1, 2]
    ai_row = Cint[0, 0, 1, 0, 0, 0, 1, 2, 0, 0, 1, 0, 1, 0, 1, 2]
    ai_val = Cdouble[-10.0, -0.5, 4.5, -2.0, 9.0, 0.5, -3.0, -1.0, -1.8, -0.1, 1.2, -0.4, -1.0, -1.0, -1.0, -1.0]

    ki_dim = Cint[1]
    ki_idx = Cint[1]
    kj_idx = Cint[2]
    ki_nzs = Cint[3]
    ki_col = Cint[1, 2, 2]
    ki_row = Cint[1, 0, 1]
    ki_val = Cdouble[-5.5, 2.0, 3.0]

    ioptions = Cint[1, 50, 100, 0, 0, 1, 0, 0, 0, 0, 0, 0]
    foptions = Cdouble[1.0, 0.7, 0.1, 1e-7, 1e-6, 1e-14, 1e-2, 1e-1, 0.0, 1.0, 1.0e-6, 5.0e-2]

    fx_expected = 4.038697821670394
    x_expected = [-0.181129, -0.579887, 3.87969]

    @testset "Direct" begin
        x = copy(x0)
        fx, xx, uoutput, iresults, fresults, info = Penopt.penbmi(
            msizes, x, fobj,
            q_col, q_row, q_val,
            ci,
            bi_dim, bi_idx, bi_val,
            ai_dim, ai_idx, ai_nzs, ai_val, ai_col, ai_row,
            ki_dim, ki_idx, kj_idx, ki_nzs, ki_val, ki_col, ki_row,
            ioptions, foptions,
        )

        @test xx == x
        @test fx ≈ fx_expected rtol=1e-4
        @test x ≈ x_expected rtol=1e-4
        @test uoutput ≈ [5.88857e-9, 8.60883e-10, 7.75871e-10, 2.47721e-10, 0.00572922, -0.0694957, -0.0294404, 0.842987, 0.357114, 0.151284] rtol=1e-4
        @test length(iresults) == 4
        @test iresults isa Vector{Cint}
        @test fresults ≈ [6.55463e-7, -0.318871, 0.0, 7.51078e-9, 5.59009e-11] rtol=1e-6
        @test info isa Cint
    end

    @testset "MOI" begin
        optimizer = Penopt.Optimizer()
        MOI.set(optimizer, MOI.RawParameter("OUTPUT"), 0)
        MOI.set(optimizer, MOI.RawParameter("LS"), 1)
        MOI.set(optimizer, MOI.RawParameter("DIMACS"), 0)
        MOI.set(optimizer, MOI.RawParameter("P0"), 0.1)
        MOI.set(optimizer, MOI.RawParameter("PRECISION_2"), 1e-6)
        x = MOI.add_variables(optimizer, 3)
        fx = MOI.SingleVariable.(x)
        obj = (1.0fx[1] - 1.0fx[2])^2 / 2.0 + 1.0fx[3]
        MOI.set(optimizer, MOI.ObjectiveSense(), MOI.MIN_SENSE)
        MOI.set(optimizer, MOI.ObjectiveFunction{typeof(obj)}(), obj)
        MOI.add_constraint(optimizer, -1.0fx[1], MOI.LessThan(0.5))
        MOI.add_constraint(optimizer,  1.0fx[1], MOI.LessThan(2.0))
        MOI.add_constraint(optimizer, -1.0fx[2], MOI.LessThan(3.0))
        MOI.add_constraint(optimizer,  1.0fx[2], MOI.LessThan(7.0))
        func = MOI.Utilities.vectorize(MOI.ScalarQuadraticFunction{Cdouble}[
            10.0 - 9.0fx[1] + 1.8fx[2] + 1.0fx[3],
             0.5 - 0.5fx[1] + 0.1fx[2],
            -4.5            - 1.2fx[2] + 1.0fx[3] + 5.5fx[1] * fx[2],
             2.0            + 0.4fx[2]            - 2.0fx[1] * fx[2],
                   3.0fx[1] + 1.0fx[2]            - 3.0fx[1] * fx[2],
                   1.0fx[1]            + 1.0fx[3],
        ])
        MOI.add_constraint(optimizer, func, MOI.PositiveSemidefiniteConeTriangle(3))

        @test optimizer.objective_constant == 0.0
        @test optimizer.msizes == msizes
        @test optimizer.x0 == x0
        @test optimizer.fobj == fobj
        @test optimizer.q_col == q_col
        @test optimizer.q_row == q_row
        @test optimizer.q_val == q_val
        @test optimizer.ci == ci
        @test optimizer.bi_dim == bi_dim
        @test optimizer.bi_idx == bi_idx
        @test optimizer.bi_val == bi_val
        @test optimizer.ai_dim == ai_dim
        @test optimizer.ai_idx == ai_idx
        @test optimizer.ai_nzs == ai_nzs
        @test optimizer.ai_val == ai_val
        @test optimizer.ai_col == ai_col
        @test optimizer.ai_row == ai_row
        @test optimizer.ki_dim == ki_dim
        @test optimizer.ki_idx == ki_idx
        @test optimizer.kj_idx == kj_idx
        @test optimizer.ki_nzs == ki_nzs
        @test optimizer.ki_val == ki_val
        @test optimizer.ki_col == ki_col
        @test optimizer.ki_row == ki_row
        @test optimizer.ioptions == ioptions
        @test optimizer.foptions == foptions

        MOI.optimize!(optimizer)

        @test MOI.get(optimizer, MOI.ObjectiveValue()) ≈ fx_expected rtol=1e-4
        @test MOI.get.(optimizer, MOI.VariablePrimal(), x) ≈ x_expected rtol=1e-4
        @test MOI.get(optimizer, Penopt.NumberOfOuterIterations()) == 13
        @test MOI.get(optimizer, Penopt.NumberOfNewtonSteps()) == 42
        @test MOI.get(optimizer, Penopt.NumberOfLinesearchSteps()) == 93
    end
end

@testset "Penbmi example" begin
    example3()
end
