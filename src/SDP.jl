"""
    pensdp(msizes, x0, fobj, ci,
           bi_dim, bi_idx, bi_val,
           ai_dim, ai_idx, ai_nzs, ai_val, ai_col, ai_row,
           ioptions, foptions)

Solve a semidefinite program of the form

```
min f'x
bi'x ≤ ci                              i = 1, ..., constr
A0i + sum_k x_k * Ai_k ⪯ 0             i = 1, ..., mconstr
```

This is the linear-objective, linear-matrix-inequality subset of [`penbmi`](@ref).
"""
function pensdp(
    msizes::Vector{Cint},
    x0::Vector{Cdouble},
    fobj::Vector{Cdouble},
    ci::Vector{Cdouble},
    bi_dim::Vector{Cint},
    bi_idx::Vector{Cint},
    bi_val::Vector{Cdouble},
    ai_dim::Vector{Cint},
    ai_idx::Vector{Cint},
    ai_nzs::Vector{Cint},
    ai_val::Vector{Cdouble},
    ai_col::Vector{Cint},
    ai_row::Vector{Cint},
    ioptions = Cint[1, 50, 100, 2, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1],
    foptions = Cdouble[
        1.0,
        0.7,
        0.1,
        1e-7,
        1e-6,
        1e-14,
        1e-2,
        1e-1,
        0.0,
        1.0,
        1.0e-6,
        5.0e-2,
    ],
)
    mconstr = length(msizes)
    vars = length(x0)
    @assert vars == length(fobj)
    @assert mconstr == length(ai_dim)
    constr = length(ci)
    @assert length(bi_dim) == constr
    @assert length(bi_idx) == sum(bi_dim)
    @assert length(bi_val) == sum(bi_dim)
    @assert length(ai_idx) == sum(ai_dim)
    @assert length(ai_nzs) == sum(ai_dim)
    @assert length(ai_val) == sum(ai_nzs)
    @assert length(ai_col) == sum(ai_nzs)
    @assert length(ai_row) == sum(ai_nzs)
    # PENSDP exposes 15 integer options; pad the trailing 3 with the defaults
    # documented in `Pensdp2.2/c/driver_sdp_c.c` when only the 12 PENBMI-common
    # options are provided.
    if length(ioptions) == 12
        ioptions = vcat(ioptions, Cint[0, 1, 1])
    end
    @assert length(ioptions) == 15
    @assert length(foptions) == 12
    fx = Ref{Cdouble}(zero(Cdouble))
    iresults = zeros(Cint, 4)
    fresults = zeros(Cdouble, 5)
    info = Ref{Cint}(zero(Cint))
    u0 = C_NULL
    uoutput = zeros(Cdouble, constr + sum(_tridim, msizes, init = 0))
    ccall(
        (:pensdp, libpensdp),
        Cint,
        (
            Cint,
            Cint,
            Cint,
            Ptr{Cint},
            Ref{Cdouble},
            Ptr{Cdouble},
            Ptr{Cdouble},
            Ptr{Cdouble},
            Ptr{Cdouble},
            Ptr{Cdouble},
            Ptr{Cint},
            Ptr{Cint},
            Ptr{Cdouble},
            Ptr{Cint},
            Ptr{Cint},
            Ptr{Cint},
            Ptr{Cdouble},
            Ptr{Cint},
            Ptr{Cint},
            Ptr{Cint},
            Ptr{Cdouble},
            Ptr{Cint},
            Ptr{Cdouble},
            Ref{Cint},
        ),
        vars,
        constr,
        mconstr,
        msizes,
        fx,
        x0,
        u0,
        uoutput,
        fobj,
        ci,
        bi_dim,
        bi_idx,
        bi_val,
        ai_dim,
        ai_idx,
        ai_nzs,
        ai_val,
        ai_col,
        ai_row,
        ioptions,
        foptions,
        iresults,
        fresults,
        info,
    )
    return fx[], x0, uoutput, iresults, fresults, info[]
end


module SDP

import ..Penopt

"""
    Penopt.SDP.Optimizer()

Optimizer solving semidefinite programs with [`Penopt.pensdp`](@ref), which is
installed by `Pkg.build("Penopt")`. It supports a linear objective and linear
matrix inequalities; the bridges reformulate a convex quadratic objective into
an additional matrix constraint. Use [`Penopt.BMI.Optimizer`](@ref) to solve
these natively and to solve bilinear matrix inequalities.
"""
const Optimizer = Penopt.Optimizer{:SDP}

end # module SDP
