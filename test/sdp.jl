# Copyright (c) 2019: Benoît Legat and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

module TestSDP

# Example taken from `Pensdp2.2/c/driver_sdp_c.c` (the SDP part of Example 3
# in http://www.penopt.com/doc/penbmi2_1.pdf).
using Test
using Penopt

import MathOptInterface
const MOI = MathOptInterface

function test_driver_sdp_c()
    msizes = Cint[3]
    x0 = zeros(Cdouble, 3)
    fobj = Cdouble[0.0, 0.0, 1.0]

    ci = Cdouble[0.5, 2.0, 3.0, 7.0]
    bi_dim = ones(Cint, 4)
    bi_idx = Cint[0, 0, 1, 1]
    bi_val = Cdouble[-1.0, 1.0, -1.0, 1.0]

    ai_dim = Cint[4]
    ai_idx = Cint[0, 1, 2, 3]
    ai_nzs = Cint[4, 4, 5, 3]
    ai_col = Cint[0, 1, 2, 1, 0, 1, 2, 2, 0, 1, 2, 1, 2, 0, 1, 2]
    ai_row = Cint[0, 0, 0, 1, 0, 0, 1, 2, 0, 0, 0, 1, 1, 0, 1, 2]
    ai_val = Cdouble[
        -10.0, -0.5, -2.0,  4.5,
          9.0,  0.5, -3.0, -1.0,
         -1.8, -0.1, -0.4,  1.2, -1.0,
         -1.0, -1.0, -1.0,
    ]

    ioptions = Cint[1, 50, 100, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1]
    foptions = Cdouble[1.0, 0.7, 0.1, 1e-7, 1e-6, 1e-14, 1e-2, 1e-1, 0.0, 1.0, 1.0e-6, 5.0e-2]

    x = copy(x0)
    fx, xx, uoutput, iresults, fresults, info = Penopt.pensdp(
        msizes, x, fobj,
        ci,
        bi_dim, bi_idx, bi_val,
        ai_dim, ai_idx, ai_nzs, ai_val, ai_col, ai_row,
        ioptions, foptions,
    )

    @test xx === x
    @test info == 0
    @test length(iresults) == 4
    @test iresults isa Vector{Cint}
    @test length(fresults) == 5
    @test isfinite(fx)
end

function test_moi_sdp()
    optimizer = Penopt.Optimizer()
    MOI.set(optimizer, MOI.RawOptimizerAttribute("OUTPUT"), 0)
    MOI.set(optimizer, MOI.RawOptimizerAttribute("DIMACS"), 0)
    x = MOI.add_variables(optimizer, 3)
    obj = 1.0x[3]
    MOI.set(optimizer, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    MOI.set(optimizer, MOI.ObjectiveFunction{typeof(obj)}(), obj)
    MOI.add_constraint(optimizer, -1.0x[1], MOI.LessThan(0.5))
    MOI.add_constraint(optimizer,  1.0x[1], MOI.LessThan(2.0))
    MOI.add_constraint(optimizer, -1.0x[2], MOI.LessThan(3.0))
    MOI.add_constraint(optimizer,  1.0x[2], MOI.LessThan(7.0))
    func = MOI.Utilities.vectorize(MOI.ScalarAffineFunction{Cdouble}[
        10.0 - 9.0x[1] + 1.8x[2] + 1.0x[3],
         0.5 - 0.5x[1] + 0.1x[2],
        -4.5           - 1.2x[2] + 1.0x[3],
         2.0           + 0.4x[2],
               3.0x[1] + 1.0x[2],
               1.0x[1]           + 1.0x[3],
    ])
    MOI.add_constraint(optimizer, func, MOI.PositiveSemidefiniteConeTriangle(3))

    MOI.optimize!(optimizer)

    @test MOI.get(optimizer, MOI.RawStatusString()) == "No errors."
    @test MOI.get(optimizer, MOI.TerminationStatus()) == MOI.LOCALLY_SOLVED
    @test MOI.get(optimizer, MOI.PrimalStatus()) == MOI.FEASIBLE_POINT
end

function runtests()
    for name in names(@__MODULE__; all = true)
        if startswith("$(name)", "test_")
            @testset "$(name)" begin
                getfield(@__MODULE__, name)()
            end
        end
    end
end

end # module TestSDP

TestSDP.runtests()
