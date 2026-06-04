# Copyright (c) 2019: Benoît Legat and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

module Penopt

using Libdl

if isfile(joinpath(dirname(@__FILE__), "..", "deps", "deps.jl"))
    include("../deps/deps.jl")
else
    error(
        "Penopt not properly installed. Please run Pkg.build(\"Penopt\") and restart julia",
    )
end

has_penbmi() = !isempty(libpenbmi)

const DEFAULT_IOPTIONS = Cint[1, 50, 100, 2, 0, 0, 0, 0, 0, 0, 1, 0]
const DEFAULT_FOPTIONS = Cdouble[
    1.0,
    0.7,
    0.1,
    1e-7,
    1e-6,
    1e-14,
    1e-2,
    1.1,
    0.0,
    1.0,
    1.0e-7,
    5.0e-2,
]

import MathOptInterface
const MOI = MathOptInterface
_tridim(n) = MOI.dimension(MOI.PositiveSemidefiniteConeTriangle(n))

"""
    penbmi()

```
min x'Qx/2 + f'x
bi'x ≤ ci                                                    i = 1, ..., constr
A0i + sum_k x_k * Ai_k + sum_k sum_l x_k * x_l * Ki_kl ⪯ 0   i = 1, ..., mconstr
```
"""
function penbmi(
    msizes::Vector{Cint},
    x0::Vector{Cdouble},
    fobj::Vector{Cdouble},
    q_col::Vector{Cint},
    q_row::Vector{Cint},
    q_val::Vector{Cdouble},
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
    ki_dim::Vector{Cint},
    ki_idx::Vector{Cint},
    kj_idx::Vector{Cint},
    ki_nzs::Vector{Cint},
    ki_val::Vector{Cdouble},
    ki_col::Vector{Cint},
    ki_row::Vector{Cint},
    ioptions = Cint[1, 50, 100, 2, 0, 1, 0, 0, 0, 0, 0, 0],
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
    q_nzs = length(q_col)
    @assert length(q_row) == length(q_val) == q_nzs
    constr = length(ci)
    @assert length(bi_dim) == constr
    @assert length(bi_idx) == sum(bi_dim)
    @assert length(bi_val) == sum(bi_dim)
    @assert length(ai_dim) == mconstr
    @assert length(ai_idx) == sum(ai_dim)
    @assert length(ai_nzs) == sum(ai_dim)
    @assert length(ai_val) == sum(ai_nzs)
    @assert length(ai_col) == sum(ai_nzs)
    @assert length(ai_row) == sum(ai_nzs)
    @assert length(ki_dim) == mconstr
    @assert length(ki_idx) == sum(ki_dim)
    @assert length(kj_idx) == sum(ki_dim)
    @assert length(ki_nzs) == sum(ki_dim)
    @assert length(ki_val) == sum(ki_nzs)
    @assert length(ki_col) == sum(ki_nzs)
    @assert length(ki_row) == sum(ki_nzs)
    @assert length(ioptions) == 12
    @assert length(foptions) == 12
    has_penbmi() || error(
        "PENBMI is not available. PENBMI is a commercial product; set the " *
        "`PENOPT_LIBPENBMI` environment variable to the path of `libpenbmi` " *
        "and re-run `Pkg.build(\"Penopt\")`. PENSDP (auto-installed) only " *
        "supports linear objectives and linear matrix inequalities; use " *
        "`Penopt.pensdp` for those problems.",
    )
    fx = Ref{Cdouble}(zero(Cdouble))
    iresults = zeros(Cint, 4)
    fresults = zeros(Cdouble, 5)
    info = Ref{Cint}(zero(Cint))
    # array reserved for initial (factors for) dual variables (input)
    u0 = C_NULL
    uoutput = zeros(Cdouble, constr + sum(_tridim, msizes, init = 0))
    ccall(
        (:penbmi, libpenbmi),
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
            Cint,
            Ptr{Cint},
            Ptr{Cint},
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
        q_nzs,
        q_col,
        q_row,
        q_val,
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
        ki_dim,
        ki_idx,
        kj_idx,
        ki_nzs,
        ki_val,
        ki_col,
        ki_row,
        ioptions,
        foptions,
        iresults,
        fresults,
        info,
    )
    return fx[], x0, uoutput, iresults, fresults, info[]
end

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

include("MOI_wrapper.jl")

end # module
