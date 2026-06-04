# Copyright (c) 2019: Benoît Legat and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

# Automatic installation of the PENSDP library from
# https://github.com/kocvara/pensdp
#
# PENSDP is the free SDP-only variant of the PENOPT family of solvers. The
# BMI-capable PENBMI is a commercial product; if the user has a working
# `libpenbmi` shared library, its path can be provided via the
# `PENOPT_LIBPENBMI` environment variable and it will be used in addition
# to the auto-installed PENSDP library.

using Libdl

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
    elseif Sys.iswindows()
        # `unzip` is not standard on Windows; use PowerShell's Expand-Archive.
        run(`powershell -NoProfile -Command "Expand-Archive -Path '$(archive)' -DestinationPath '$(DOWNLOAD_DIR)' -Force"`)
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
    julia_libdir = joinpath(Sys.BINDIR, Base.LIBDIR, "julia")
    os, _ = _platform()
    if os == :linux
        libpensdp_a = joinpath(lib_src, "libpensdp.a")
        isfile(libpensdp_a) || error("$(libpensdp_a) not found")
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
        libpensdp_a = joinpath(lib_src, "libpensdp.a")
        isfile(libpensdp_a) || error("$(libpensdp_a) not found")
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
    elseif os == :windows
        return _build_windows(extract_dir, lib_src)
    else
        error("Unsupported OS for automatic build: $(os)")
    end
end

function _find_vcvarsall()
    vswhere = raw"C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe"
    isfile(vswhere) || error(
        "vswhere.exe not found at $(vswhere); cannot locate Visual Studio. " *
        "Install Visual Studio Build Tools (with the C++ workload).",
    )
    vs_path = strip(read(Cmd([
        vswhere, "-latest",
        "-products", "*",
        "-requires", "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
        "-property", "installationPath",
    ]), String))
    isempty(vs_path) && error(
        "vswhere returned no Visual Studio install with the MSVC x64 tools.",
    )
    vcvarsall = joinpath(vs_path, "VC", "Auxiliary", "Build", "vcvarsall.bat")
    isfile(vcvarsall) || error("$(vcvarsall) not found")
    return vcvarsall
end

function _build_windows(extract_dir, lib_src)
    pensdp_lib = joinpath(lib_src, "pensdp64.lib")
    openblas_lib = joinpath(lib_src, "libopenblas.lib")
    f2c_lib = joinpath(lib_src, "libf2c64.lib")
    for f in (pensdp_lib, openblas_lib, f2c_lib)
        isfile(f) || error("$(f) not found")
    end
    output = joinpath(LIB_DIR, "libpensdp.dll")
    # libpensdp.dll calls into OpenBLAS at runtime; copy the bundled DLL next
    # to it so Windows finds it via the standard search order.
    openblas_dll = joinpath(extract_dir, "bin", "libopenblas.dll")
    isfile(openblas_dll) || error("$(openblas_dll) not found")
    cp(openblas_dll, joinpath(LIB_DIR, "libopenblas.dll"); force = true)
    # `pensdp64.lib` has no DLL exports, so we write a `.def` file listing the
    # single C symbol we need (no name mangling on x64).
    def_file = joinpath(LIB_DIR, "libpensdp.def")
    open(def_file, "w") do io
        println(io, "EXPORTS")
        println(io, "    pensdp")
    end
    vcvarsall = _find_vcvarsall()
    link_cmd = string(
        "link.exe /DLL /MACHINE:X64",
        " /OUT:\"", output, "\"",
        " /DEF:\"", def_file, "\"",
        " /WHOLEARCHIVE:\"", pensdp_lib, "\"",
        " \"", openblas_lib, "\"",
        " \"", f2c_lib, "\"",
    )
    cmdline = "call \"$(vcvarsall)\" x64 >nul && $(link_cmd)"
    @info "Linking shared library" cmdline
    run(`cmd /c $(cmdline)`)
    return output
end

function _write_deps(libpensdp_path)
    libpenbmi_path = get(ENV, "PENOPT_LIBPENBMI", "")
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
    extract_dir = _download_and_extract()
    libpensdp_path = _build_shared_library(extract_dir)
    _write_deps(libpensdp_path)
    @info "Penopt: PENSDP installed at $(libpensdp_path)"
    return
end

main()
