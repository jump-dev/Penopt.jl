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

"""
    has_penbmi()

Return whether the commercial PENBMI library, required by [`penbmi`](@ref) and
`Penopt.BMI.Optimizer`, was found by `Pkg.build("Penopt")`. See the
`Installation` section of the README to install it.
"""
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

import MathOptInterface as MOI
_tridim(n) = MOI.dimension(MOI.PositiveSemidefiniteConeTriangle(n))

include("MOI_wrapper.jl")
include("SDP.jl")
include("BMI.jl")

end # module
