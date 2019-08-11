# Example taken from `PENBMI2.1/c/driver_bmi_c.c`.
using Test
using Penopt

@testset "Penbmi example" begin
    msizes = Cint[3]
    x0 = zeros(Cdouble, 3)
    fobj = Cdouble[0.0, 0.0, 1.0]

    q_col = Cint[0, 1, 1]
    q_row = Cint[0, 0, 1]
    q_val = Cdouble[1.0, -1.0, 1.0]

    ci = Cdouble[0.5, 2.0, 3.0, 7.0]

    bi_dim = ones(Cint, 4)
    bi_idx = Cint[0, 0, 1, 1]
    bi_val = Cdouble[-1.0, 1.0, -1.0, 1.0]

    ai_dim = Cint[4]
    ai_idx = Cint[0, 1, 2, 3]
    ai_nzs = Cint[4, 4, 5, 3]
    ai_col = Cint[0, 1, 2, 1, 0, 1, 2, 2, 0, 1, 2, 1, 2, 0, 1, 2]
    ai_row = Cint[0, 0, 0, 1, 0, 0, 1, 2, 0, 0, 0, 1, 1, 0, 1, 2]
    ai_val = Cdouble[-10.0, -0.5, -2.0, 4.5, 9.0, 0.5, -3.0, -1.0, -1.8, -0.1, -0.4, 1.2, -1.0, -1.0, -1.0, -1.0]

    ki_dim = Cint[1]
    ki_idx = Cint[1]
    kj_idx = Cint[2]
    ki_nzs = Cint[3]
    ki_col = Cint[2, 1, 2]
    ki_row = Cint[0, 1, 1]
    ki_val = Cdouble[2.0, -5.5, 3.0]

    fx, x0, uoutput, iresults, fresults, info = Penopt.penbmi(
        msizes, x0, fobj,
        q_col, q_row, q_val,
        ci,
        bi_dim, bi_idx, bi_val,
        ai_dim, ai_idx, ai_nzs, ai_val, ai_col, ai_row,
        ki_dim, ki_idx, kj_idx, ki_nzs, ki_val, ki_col, ki_row)

    @test fx ≈ 4.038697821670394 rtol=1e-4
    @test x0 ≈ [-0.181129, -0.579887, 3.87969] rtol=1e-4
    @test uoutput ≈ [5.88857e-9, 8.60883e-10, 7.75871e-10, 2.47721e-10, 0.00572922, -0.0694957, -0.0294404, 0.842987, 0.357114, 0.151284] rtol=1e-4
    @test length(iresults) == 4
    @test iresults isa Vector{Cint}
    @test length(fresults) == 5
    @test fresults isa Vector{Cdouble}
    @test info == 3
end
