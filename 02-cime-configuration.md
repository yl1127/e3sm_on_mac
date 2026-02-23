# E3SM on macOS: CIME Configuration

This guide covers setting up CIME to recognize your Mac as a supported build system.

## Overview

CIME (Common Infrastructure for Modeling the Earth) is E3SM's build and case management system. To build E3SM on your Mac, CIME needs:

1. **Machine definition** - describes your computer's hardware and environment
2. **Compiler definition** - specifies compiler flags and settings for GCC 11
3. **Configuration files** - located in `~/.cime/` directory

## Quick Start (Automated)

Use the automated script to generate all configuration files:

```bash
# From anywhere
/path/to/mac-notes/scripts/setup_cime_config.sh

# Or with custom options
/path/to/mac-notes/scripts/setup_cime_config.sh --machine MyMacBook --compiler gnu11

# See all options
/path/to/mac-notes/scripts/setup_cime_config.sh --help
```

The script will:
- Auto-detect your hostname, CPU cores, and SDK location
- Find full paths to all compilers (including MPI wrappers)
- Generate all three required configuration files
- Use your git user.name and user.email for the "SUPPORTED_BY" field

**If you prefer manual configuration** or need to customize further, continue with the sections below.

## Directory Structure

Create the CIME configuration directory:

```bash
mkdir -p ~/.cime
cd ~/.cime
```

Your `~/.cime/` directory will contain:
- `config_machines.xml` - defines your machine
- `config_compilers.xml` - defines compiler settings
- `<compiler>_<machine>.cmake` - CMake compiler macros

```bash
mkdir -p ~/.cime
```

## Step 1: Create Machine Definition

Create `~/.cime/config_machines.xml`:

```xml
<?xml version="1.0"?>
<config_machines version="2.0">
  <machine MACH="PNNL-L07D666226">
    <DESC>Personal MacBook, OS=macOS, system=Darwin, 11 pes/node</DESC>
    <NODENAME_REGEX>PNNL-L07D666226</NODENAME_REGEX>
    <OS>Darwin</OS>
    <COMPILERS>gnu11</COMPILERS>
    <MPILIBS>openmpi</MPILIBS>
    <PROJECT>E3SM</PROJECT>
    <SAVE_TIMING_DIR/>
    <CIME_OUTPUT_ROOT>$ENV{HOME}/projects/e3sm/scratch</CIME_OUTPUT_ROOT>
    <DIN_LOC_ROOT>$ENV{HOME}/projects/e3sm/inputdata</DIN_LOC_ROOT>
    <DIN_LOC_ROOT_CLMFORC>$ENV{HOME}/projects/e3sm/inputdata/atm/datm7</DIN_LOC_ROOT_CLMFORC>
    <DOUT_S_ROOT>$CIME_OUTPUT_ROOT/archive/$CASE</DOUT_S_ROOT>
    <BASELINE_ROOT>$ENV{HOME}/projects/e3sm/baselines</BASELINE_ROOT>
    <CCSM_CPRNC>$ENV{HOME}/local/gcc11/bin/cprnc</CCSM_CPRNC>
    <GMAKE_J>8</GMAKE_J>
    <BATCH_SYSTEM>none</BATCH_SYSTEM>
    <SUPPORTED_BY>Your Name (your.email@example.com)</SUPPORTED_BY>
    <MAX_TASKS_PER_NODE>11</MAX_TASKS_PER_NODE>
    <MAX_MPITASKS_PER_NODE>11</MAX_MPITASKS_PER_NODE>
    <PROJECT_REQUIRED>FALSE</PROJECT_REQUIRED>
    <mpirun mpilib="openmpi">
      <executable>mpirun</executable>
      <arguments>
        <arg name="num_tasks">-np {{ total_tasks }}</arg>
      </arguments>
    </mpirun>
    <module_system type="none"/>
    <environment_variables>
      <env name="OMP_STACKSIZE">256M</env>
      <env name="NETCDF_PATH">$ENV{HOME}/local/gcc11</env>
      <!-- Include MOAB_ROOT only if MOAB was installed -->
      <env name="MOAB_ROOT">$ENV{HOME}/local/gcc11</env>
    </environment_variables>
  </machine>
</config_machines.xml>
```

**Key fields to customize:**

- `MACH`: Replace `PNNL-L07D666226` with your machine's hostname (run `hostname` to find it)
- `NODENAME_REGEX`: Same as MACH
- `CIME_OUTPUT_ROOT`: Where build files and run directories go
- `DIN_LOC_ROOT`: Where input data is stored
- `BASELINE_ROOT`: Where test baselines are stored
- `SUPPORTED_BY`: Your contact information
- `MAX_TASKS_PER_NODE`: Number of CPU cores (find with `sysctl -n hw.ncpu`)
- `GMAKE_J`: Parallel build jobs (typically same as core count)
- `NETCDF_PATH`: Path to your NetCDF installation (must match your `$INSTALL_PREFIX`)
- `MOAB_ROOT`: Path to your MOAB installation — **only include this if you installed MOAB** (see `01-package-installation.md`)

## Step 2: Create Compiler Definition

Create `~/.cime/config_compilers.xml`:

```xml
<?xml version="1.0"?>
<config_compilers version="2.0">
  <compiler MACH="PNNL-L07D666226" COMPILER="gnu11">
    <MPICC>mpicc</MPICC>
    <MPICXX>mpicxx</MPICXX>
    <MPIFC>mpif90</MPIFC>
    <SCC>clang</SCC>
    <SCXX>clang++</SCXX>
    <SFC>gfortran-11</SFC>
  </compiler>
</config_compilers>
```

**Note:** Replace `PNNL-L07D666226` with your machine name from Step 1.

## Step 3: Create CMake Compiler Macros

This is the **most critical file** - it contains all the compiler flags needed for a successful build on macOS.

Create `~/.cime/gnu11_PNNL-L07D666226.cmake`:

```cmake
set(MPICC "mpicc")
set(MPICXX "mpicxx")
set(MPIFC "mpif90")
set(SCC "clang")
set(SCXX "clang++")
set(SFC "gfortran-11")

# Required for macOS linking
string(APPEND CMAKE_EXE_LINKER_FLAGS " -framework Accelerate")

# Fortran compiler flags
string(APPEND CMAKE_Fortran_FLAGS " -DCPRGNU")
string(APPEND CMAKE_Fortran_FLAGS " -DFORTRANUNDERSCORE")
string(APPEND CMAKE_Fortran_FLAGS " -DNO_IEEE_ARITHMETIC")
string(APPEND CMAKE_Fortran_FLAGS " -fallow-argument-mismatch")
string(APPEND CMAKE_Fortran_FLAGS " -fallow-invalid-boz")
string(APPEND CMAKE_Fortran_FLAGS " -ffree-line-length-none")
string(APPEND CMAKE_Fortran_FLAGS " -mcmodel=small")

# Debug flags
string(APPEND CMAKE_Fortran_FLAGS_DEBUG " -g")
string(APPEND CMAKE_C_FLAGS_DEBUG " -g")
string(APPEND CMAKE_CXX_FLAGS_DEBUG " -g")

# Release flags
string(APPEND CMAKE_Fortran_FLAGS_RELEASE " -O2")
string(APPEND CMAKE_C_FLAGS_RELEASE " -O2")
string(APPEND CMAKE_CXX_FLAGS_RELEASE " -O2")

# Linker flags for macOS
string(APPEND LDFLAGS " -framework Accelerate")
string(APPEND LDFLAGS " -L/opt/homebrew/lib/gcc/11/")
string(APPEND LDFLAGS " -L$ENV{SDKROOT}/usr/lib")
string(APPEND LDFLAGS " -L$ENV{INSTALL_PREFIX}/lib")
```

**Important compiler flags explained:**

- `-DCPRGNU`: Identifies GNU compiler preprocessor for conditional compilation
- `-DFORTRANUNDERSCORE`: Ensures proper Fortran-C symbol name mangling (appends underscore)
- `-DNO_IEEE_ARITHMETIC`: GCC 11 on macOS has incomplete IEEE arithmetic support
- `-fallow-argument-mismatch`: Allows legacy Fortran code to compile with newer GCC
- `-fallow-invalid-boz`: Allows binary/octal/hex constants in older code
- `-ffree-line-length-none`: Removes Fortran line length limits
- `-framework Accelerate`: Links to Apple's optimized BLAS/LAPACK

**Note:** Replace `PNNL-L07D666226` in the filename with your machine name.

## Step 4: Modify E3SM Source for macOS Compatibility

Due to incomplete IEEE arithmetic support in GCC 11 on macOS, one source file needs modification.

Edit `$E3SM_ROOT/share/util/shr_infnan_mod.F90.in`:

Find the line that defines `HAVE_IEEE_ARITHMETIC` and wrap it in a conditional:

```fortran
! Original:
! #define HAVE_IEEE_ARITHMETIC

! Modified:
#if !defined(NO_IEEE_ARITHMETIC)
#define HAVE_IEEE_ARITHMETIC  
#endif
```

This allows the code to compile without IEEE arithmetic support when the `NO_IEEE_ARITHMETIC` flag is set in the CMake macros.

## Step 5: Create Required Directories

Create the directories referenced in your machine configuration:

```bash
mkdir -p ~/projects/e3sm/scratch
mkdir -p ~/projects/e3sm/inputdata
mkdir -p ~/projects/e3sm/baselines
```

## Step 6: Verify Configuration

Check that CIME recognizes your machine:

```bash
cd $E3SM_ROOT/cime/scripts
./query_config --machines
```

You should see your machine name (`PNNL-L07D666226` or whatever you named it) in the list.

Check compiler configuration:

```bash
./query_config --compilers PNNL-L07D666226
```

Should show `gnu11` as available.

## Testing Your Configuration

Create a simple test case to verify everything works:

```bash
cd $E3SM_ROOT/cime/scripts

# Create a minimal CIME test case
./create_test SMS_Ld1.ne4_oQU240.F2010 --machine PNNL-L07D666226 --compiler gnu11

# The test will create a case, build, and run it
# Check the output for any errors
```

## Common Issues and Solutions

### Issue: CIME doesn't recognize my machine

**Check:**
```bash
hostname  # Should match NODENAME_REGEX in config_machines.xml
```

If hostname doesn't match, either:
1. Update `NODENAME_REGEX` in the XML to match your hostname, OR
2. Force the machine name: `./create_case --machine PNNL-L07D666226 ...`

### Issue: Compiler not found

Verify environment variables are set:
```bash
which mpicc mpif90 gfortran-11
# Should point to $HOME/local/gcc11/bin/...
```

Ensure your `~/.zshrc` has the correct PATH from the package installation guide.

### Issue: Build fails with IEEE arithmetic errors

Verify:
1. CMake macros include `-DNO_IEEE_ARITHMETIC` flag
2. `shr_infnan_mod.F90.in` has been modified with the conditional wrapper

### Issue: Cannot find NetCDF

Verify NetCDF environment variables:
```bash
echo $NETCDF_PATH
echo $NETCDF_C_PATH  
echo $NETCDF_FORTRAN_PATH
```

All should point to `$HOME/local/gcc11`.

## Configuration Alternatives

### Different Machine Name

If you want to use a simpler machine name:

1. Change `MACH` in `config_machines.xml` to something like `"MacBookPro"`
2. Update `NODENAME_REGEX` to match your hostname or use `.*` to match anything
3. Rename CMake macros file: `gnu11_MacBookPro.cmake`
4. Update `MACH` in `config_compilers.xml`

### Multiple Compilers

To add other compilers (e.g., `clang` for C/C++ only projects), create additional compiler entries in `config_compilers.xml` and corresponding CMake macro files.

## Next Steps

With CIME configured, you're ready to:
1. Create your first E3SM case (see `03-case-creation-and-build.md`)
2. Download required input data (see `04-input-data.md`)
3. Run the model (see `05-running-cases.md`)

## References

- [CIME Documentation](https://esmci.github.io/cime/)
- [E3SM Documentation](https://e3sm.org/resources/documentation/)
