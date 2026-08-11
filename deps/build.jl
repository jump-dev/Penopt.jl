# Copyright (c) 2019: Benoît Legat and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

# Automatic installation of the PENSDP library from
# https://github.com/kocvara/pensdp
#
# PENSDP is the free SDP-only variant of the PENOPT family of solvers. The
# BMI-capable PENBMI is a commercial product; if the user has a PENBMI license,
# the path to `libpenbmi` can be provided via the `PENOPT_LIBPENBMI`
# environment variable and it will be used in addition to the auto-installed
# PENSDP library. The path may point either to a shared library, which is used
# as is, or to the static archive shipped by PENOPT, in which case a shared
# library is linked from it here.

using Libdl

import OpenBLAS32_jll

const PENSDP_VERSION = "2.2"
const PENSDP_REPO = "https://github.com/kocvara/pensdp"
const DEPS_DIR = @__DIR__
const USR_DIR = joinpath(DEPS_DIR, "usr")
const LIB_DIR = joinpath(USR_DIR, "lib")
const DOWNLOAD_DIR = joinpath(DEPS_DIR, "downloads")

const ARCHIVES = Dict(
    (:linux,   :x86_64) => ("pensdp22_LNX64.tar.gz",        :tar),
    (:apple,   :x86_64) => ("pensdp22_macos_intel64.zip",   :zip),
    (:windows, :x86_64) => ("pensdp22_Win64.zip",           :zip),
)

function _platform()
    if Sys.islinux()
        return (:linux, Sys.ARCH)
    elseif Sys.isapple()
        return (:apple, Sys.ARCH)
    elseif Sys.iswindows()
        return (:windows, Sys.ARCH)
    else
        error("Unsupported platform: $(Sys.KERNEL)")
    end
end

function _archive_url()
    key = _platform()
    if !haskey(ARCHIVES, key)
        error(
            "No pre-built PENSDP archive is published for $(key). " *
            "See $(PENSDP_REPO).",
        )
    end
    name, kind = ARCHIVES[key]
    return "$(PENSDP_REPO)/raw/main/bin/$(name)", name, kind
end

function _download_and_extract()
    mkpath(DOWNLOAD_DIR)
    url, name, kind = _archive_url()
    archive = joinpath(DOWNLOAD_DIR, name)
    if !isfile(archive)
        @info "Downloading $(url)"
        download(url, archive)
    end
    extract_dir = joinpath(DOWNLOAD_DIR, "Pensdp$(PENSDP_VERSION)")
    rm(extract_dir; force = true, recursive = true)
    @info "Extracting $(archive)"
    if kind == :tar
        run(`tar -xzf $(archive) -C $(DOWNLOAD_DIR)`)
    else
        run(`unzip -q -o $(archive) -d $(DOWNLOAD_DIR)`)
    end
    return extract_dir
end

# Build a shared library that exports the `pensdp` symbol so that it can be
# loaded by Julia via `Libdl.dlopen` and called with `ccall`.
function _build_shared_library(extract_dir)
    mkpath(LIB_DIR)
    lib_src = joinpath(extract_dir, "lib")
    libpensdp_a = joinpath(lib_src, "libpensdp.a")
    isfile(libpensdp_a) || error("$(libpensdp_a) not found")
    julia_libdir = joinpath(Sys.BINDIR, Base.LIBDIR, "julia")
    os, _ = _platform()
    if os == :linux
        output = joinpath(LIB_DIR, "libpensdp.so")
        libgoto = joinpath(lib_src, "libgoto2.a")
        isfile(libgoto) || error("$(libgoto) not found")
        cmd = `gcc -shared -fPIC -o $(output)
                   -L$(julia_libdir) -Wl,-rpath,$(julia_libdir)
                   -Wl,--whole-archive $(libpensdp_a) -Wl,--no-whole-archive
                   $(libgoto)
                   -lgfortran -lpthread -ldl -lm`
        @info "Linking shared library" cmd
        run(cmd)
        return output
    elseif os == :apple
        output = joinpath(LIB_DIR, "libpensdp.dylib")
        libgfortran_mac = joinpath(lib_src, "libgfortran_mac.a")
        cmd = `gcc -dynamiclib -o $(output)
                   -Wl,-force_load,$(libpensdp_a)
                   $(libgfortran_mac)
                   -framework Accelerate
                   -lpthread`
        @info "Linking shared library" cmd
        run(cmd)
        return output
    else
        error(
            "Automatic build is currently implemented for Linux and macOS. " *
            "On Windows please set `PENOPT_LIBPENBMI` (or build " *
            "`libpensdp.dll` manually) and re-run `Pkg.build(\"Penopt\")`.",
        )
    end
end

# `ar` archives, both the Unix `.a` and the MSVC `.lib` flavour, start with this
# magic number. Relying on it rather than on the file extension means that a
# shared library with an unusual name is still recognized as such.
_is_static_library(path) = open(io -> read(io, 8), path) == b"!<arch>\n"

# PENBMI is distributed as a static library. Julia can only `ccall` into a
# shared library so the archive is relinked into one, with all its objects
# force-loaded so that the `penbmi` symbol is exported.
function _build_libpenbmi(archive)
    mkpath(LIB_DIR)
    output = joinpath(LIB_DIR, "libpenbmi.$(Libdl.dlext)")
    julia_libdir = joinpath(Sys.BINDIR, Base.LIBDIR, "julia")
    os, _ = _platform()
    if os == :linux
        # PENBMI calls the LP64 BLAS and LAPACK, so the 32-bit-integer OpenBLAS
        # is linked in rather than the ILP64 one that Julia itself uses.
        libopenblas = OpenBLAS32_jll.libopenblas_path
        cmd = `gcc -shared -fPIC -o $(output)
                   -Wl,--no-undefined
                   -Wl,--whole-archive $(archive) -Wl,--no-whole-archive
                   -L$(julia_libdir) -Wl,-rpath,$(julia_libdir)
                   $(libopenblas) -Wl,-rpath,$(dirname(libopenblas))
                   -lgfortran -lpthread -ldl -lm`
    elseif os == :apple
        cmd = `gcc -dynamiclib -o $(output)
                   -Wl,-force_load,$(archive)
                   -framework Accelerate
                   -L$(julia_libdir) -Wl,-rpath,$(julia_libdir)
                   -lgfortran -lpthread -lm`
    else
        error(
            "Linking `$(archive)` into a shared library is currently " *
            "implemented for Linux and macOS only. On Windows, build " *
            "`penbmi.dll` manually, point `PENOPT_LIBPENBMI` at it and " *
            "re-run `Pkg.build(\"Penopt\")`.",
        )
    end
    @info "Linking shared library" cmd
    run(cmd)
    return output
end

function _libpenbmi_path()
    path = get(ENV, "PENOPT_LIBPENBMI", "")
    if isempty(path)
        return path
    elseif !isfile(path)
        error(
            "The `PENOPT_LIBPENBMI` environment variable is set to " *
            "`$(path)` but no such file exists.",
        )
    end
    return _is_static_library(path) ? _build_libpenbmi(path) : path
end

function _write_deps(libpensdp_path, libpenbmi_path)
    open(joinpath(DEPS_DIR, "deps.jl"), "w") do io
        println(io, "# Auto-generated by deps/build.jl - do not edit.")
        println(io, "import Libdl")
        println(io)
        println(io, "const libpensdp = ", repr(libpensdp_path))
        # When `libpenbmi` is not available, the constant is left as an empty
        # string. `has_penbmi()` guards every ccall in `Penopt.jl`, so the
        # `ccall((:penbmi, libpenbmi), ...)` site is never reached.
        println(io, "const libpenbmi = ", repr(libpenbmi_path))
        println(io)
        println(io, """
            function check_deps()
                if !isfile(libpensdp)
                    error(
                        \"\$(libpensdp) does not exist, please re-run \" *
                        \"Pkg.build(\\\"Penopt\\\") and restart Julia.\",
                    )
                end
                if Libdl.dlopen_e(libpensdp) == C_NULL
                    error(
                        \"\$(libpensdp) cannot be opened, please re-run \" *
                        \"Pkg.build(\\\"Penopt\\\") and restart Julia.\",
                    )
                end
                if !isempty(libpenbmi)
                    if !isfile(libpenbmi)
                        error(\"\$(libpenbmi) does not exist.\")
                    end
                    if Libdl.dlopen_e(libpenbmi) == C_NULL
                        error(\"\$(libpenbmi) cannot be opened.\")
                    end
                end
                return
            end""")
    end
    return
end

function main()
    libpenbmi_path = _libpenbmi_path()
    extract_dir = _download_and_extract()
    libpensdp_path = _build_shared_library(extract_dir)
    _write_deps(libpensdp_path, libpenbmi_path)
    @info "Penopt: PENSDP installed at $(libpensdp_path)"
    if !isempty(libpenbmi_path)
        @info "Penopt: PENBMI installed at $(libpenbmi_path)"
    end
    return
end

main()
