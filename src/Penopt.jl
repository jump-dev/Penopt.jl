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
    q_val::Vector{Cdouble}, # Mismatch with doc which starts with q_val, assuming the doc is false
    ci::Vector{Cdouble}, # c vector
    bi_dim::Vector{Cint},
    bi_idx::Vector{Cint},
    bi_val::Vector{Cdouble}, # b vectors
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

include("MOI_wrapper.jl")

end # module
