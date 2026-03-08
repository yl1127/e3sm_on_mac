# E3SM on macOS: Package Installation

This guide covers installing all required libraries for compiling E3SM on macOS with GCC 11.

## Prerequisites

- macOS with Command Line Tools installed
- Homebrew package manager
- At least 10GB of free disk space

### Required Homebrew Packages

Install these before running the installation script:

```bash
# Compiler
brew install gcc@11

# Required for building MOAB
brew install cmake autoconf automake libtool
```

## Quick Start: Automated Installation Script

For convenience, use the automated installation script [`scripts/install_e3sm_libs.sh`](scripts/install_e3sm_libs.sh) that handles all packages in one go or step-by-step.

**Download and run the script:**

```bash
# Clone or download this documentation repository
# No need to copy script - can run from anywhere!

# View help and library versions
/path/to/mac-notes/scripts/install_e3sm_libs.sh --help

# Option 1: Interactive mode (recommended for first time)
/path/to/mac-notes/scripts/install_e3sm_libs.sh

# Option 2: Install everything at once (uses default ~/packages for builds)
/path/to/mac-notes/scripts/install_e3sm_libs.sh all

# Option 3: Specify custom build directory
/path/to/mac-notes/scripts/install_e3sm_libs.sh --packages-dir /tmp/e3sm-builds all

# Option 4: Custom build and install directories
/path/to/mac-notes/scripts/install_e3sm_libs.sh \
  --packages-dir /tmp/builds \
  --install-dir /opt/e3sm \
  all

# Option 5: Install specific packages
/path/to/mac-notes/scripts/install_e3sm_libs.sh openmpi
/path/to/mac-notes/scripts/install_e3sm_libs.sh hdf5
/path/to/mac-notes/scripts/install_e3sm_libs.sh netcdf-c
/path/to/mac-notes/scripts/install_e3sm_libs.sh netcdf-fortran
/path/to/mac-notes/scripts/install_e3sm_libs.sh pnetcdf
/path/to/mac-notes/scripts/install_e3sm_libs.sh moab      # includes Eigen3, GKlib, METIS, ParMETIS

# Verify installation
/path/to/mac-notes/scripts/install_e3sm_libs.sh verify
```

**Command-line options:**
- `-h, --help` - Show detailed help with library versions
- `-p, --packages-dir DIR` - Build directory (default: `~/packages`)
- `-i, --install-dir DIR` - Installation directory (default: `~/local/gcc11`)

**Features:**
- ✅ Checks prerequisites automatically
- ✅ Downloads packages if not already present
- ✅ Skips already-installed packages
- ✅ Uses all available CPU cores for compilation
- ✅ Verifies each installation
- ✅ Provides shell configuration at the end
- ✅ Interactive or command-line mode
- ✅ **Run from anywhere** - no need to copy script
- ✅ Customizable build and install directories
- ✅ Color-coded output for easy reading

**Time estimate:** 30-60 minutes for complete installation.

---

## Manual Installation (Step-by-Step)

If you prefer to install packages manually or the script encounters issues, follow these detailed steps:

## Installation Directory Setup

First, create a directory structure for your installations:

```bash
# Create package download directory
mkdir -p ~/packages
cd ~/packages

# Set installation prefix (all libraries will be installed here)
export INSTALL_PREFIX=$HOME/local/gcc11
mkdir -p $INSTALL_PREFIX
```

**Important:** Add this to your shell profile (`~/.zshrc` or `~/.bash_profile`):
```bash
export INSTALL_PREFIX=$HOME/local/gcc11
```

## Manual Step 1: Install GCC 11

E3SM requires a Fortran compiler. Install GCC 11 via Homebrew:

```bash
brew install gcc@11
```

Verify the installation:
```bash
gfortran-11 --version
```

## Manual Step 2: Set Up macOS SDK Path

GCC on macOS needs to know where to find system libraries. Set the SDK root:

```bash
export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk
export LIBRARY_PATH=$SDKROOT/usr/lib:$LIBRARY_PATH
```

**Critical:** Add these to your shell profile:
```bash
export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk
export LIBRARY_PATH=$SDKROOT/usr/lib:$LIBRARY_PATH
```

## Manual Step 3: Install OpenMPI (Parallel Computing Library)

OpenMPI must be installed **first** because HDF5 and NetCDF need MPI support.

```bash
cd ~/packages
curl -LO https://download.open-mpi.org/release/open-mpi/v5.0/openmpi-5.0.6.tar.gz
tar -xzf openmpi-5.0.6.tar.gz
cd openmpi-5.0.6

# Configure with GCC 11
./configure \
    CC=clang \
    CXX=clang++ \
    FC=gfortran-11 \
    --prefix=$INSTALL_PREFIX \
    --enable-mpi-fortran=yes \
    --with-libevent=internal

# Compile and install
make -j4
make install
cd ..
```

**Update PATH immediately** (also add to shell profile):
```bash
export PATH=$INSTALL_PREFIX/bin:$PATH
export LD_LIBRARY_PATH=$INSTALL_PREFIX/lib:$LD_LIBRARY_PATH
export DYLD_LIBRARY_PATH=$INSTALL_PREFIX/lib:$DYLD_LIBRARY_PATH
```

Verify MPI installation:
```bash
$INSTALL_PREFIX/bin/mpicc --version
$INSTALL_PREFIX/bin/mpif90 --version
```

## Manual Step 4: Install HDF5 with Parallel I/O

```bash
cd ~/packages
curl -LO https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-1.14/hdf5-1.14.5/src/hdf5-1.14.5.tar.gz
tar -xzf hdf5-1.14.5.tar.gz
cd hdf5-1.14.5

# Configure with MPI compilers for parallel I/O
./configure \
    --prefix=$INSTALL_PREFIX \
    --enable-fortran \
    --enable-parallel \
    CC=$INSTALL_PREFIX/bin/mpicc \
    FC=$INSTALL_PREFIX/bin/mpif90

# Compile and install
make -j$(sysctl -n hw.ncpu)
make install
cd ..
```

Verify HDF5:
```bash
$INSTALL_PREFIX/bin/h5pcc --version
```

## Manual Step 5: Install NetCDF-C with Parallel Support

```bash
cd ~/packages
curl -LO https://github.com/Unidata/netcdf-c/archive/refs/tags/v4.9.3.tar.gz
tar -xzf v4.9.3.tar.gz
cd netcdf-c-4.9.3

# Set compiler flags
export CPPFLAGS="-I$INSTALL_PREFIX/include"
export LDFLAGS="-L$INSTALL_PREFIX/lib"

# Configure with parallel support
./configure \
    --prefix=$INSTALL_PREFIX \
    --enable-netcdf4 \
    --enable-parallel4 \
    --disable-dap \
    CC=$INSTALL_PREFIX/bin/mpicc

# Compile and install
make -j$(sysctl -n hw.ncpu)
make install
cd ..
```

Verify NetCDF-C has parallel support:
```bash
$INSTALL_PREFIX/bin/nc-config --has-parallel4  # Should output "yes"
```

## Manual Step 6: Install NetCDF-Fortran

```bash
cd ~/packages
curl -LO https://github.com/Unidata/netcdf-fortran/archive/refs/tags/v4.6.2.tar.gz
tar -xzf v4.6.2.tar.gz
cd netcdf-fortran-4.6.2

# Set compiler flags
export CPPFLAGS="-I$INSTALL_PREFIX/include"
export LDFLAGS="-L$INSTALL_PREFIX/lib"

# Configure with MPI compilers
./configure \
    --prefix=$INSTALL_PREFIX \
    CC=$INSTALL_PREFIX/bin/mpicc \
    FC=$INSTALL_PREFIX/bin/mpif90

# Compile and install
make -j$(sysctl -n hw.ncpu)
make install
cd ..
```

Verify NetCDF-Fortran:
```bash
$INSTALL_PREFIX/bin/nf-config --version
```

## Manual Step 7: Set NetCDF Environment Variables

E3SM's CIME build system needs to know where NetCDF is installed:

```bash
export NETCDF_PATH=$INSTALL_PREFIX
export NETCDF_C_PATH=$INSTALL_PREFIX
export NETCDF_FORTRAN_PATH=$INSTALL_PREFIX
```

**Add these to your shell profile** so they're always available.

## Manual Step 8 (Optional): Install MOAB and Dependencies

[MOAB](https://sigma.mcs.anl.gov/moab-library/) (Mesh-Oriented datABase) is required for E3SM configurations that use unstructured meshes with online remapping (e.g., TempestRemap). If you do not need MOAB, you can skip this step.

MOAB requires several additional libraries: **Eigen3**, **GKlib**, **METIS**, and **ParMETIS**. It also downloads **TempestRemap** and **Zoltan** during its own build.

### Prerequisites

Install the following via Homebrew (if not already installed):

```bash
brew install cmake autoconf automake libtool
```

### Step 8a: Install Eigen3 (header-only)

```bash
cd ~/packages
curl -LO https://gitlab.com/libeigen/eigen/-/archive/3.4.0/eigen-3.4.0.tar.gz
tar -xzf eigen-3.4.0.tar.gz
cd eigen-3.4.0

mkdir -p build && cd build
cmake .. \
    -DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DBUILD_TESTING=OFF
make install
cd ../..
```

### Step 8b: Install GKlib

GKlib must be compiled with `clang` on ARM macOS because GCC 11's `include-fixed/stdio.h` is broken on this platform.

```bash
cd ~/packages
git clone https://github.com/KarypisLab/GKlib.git
cd GKlib

mkdir -p build && cd build
cmake .. \
    -DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DBUILD_SHARED_LIBS=OFF \
    -DGKLIB_BUILD_APPS=OFF \
    -DNO_X86=ON
make -j$(sysctl -n hw.ncpu)
make install
cd ../..
```

> **Note:** `-DGKLIB_BUILD_APPS=OFF` avoids building test apps that use x86 assembly, and `-DNO_X86=ON` disables x86-specific code paths.

### Step 8c: Install METIS v5.2.1

```bash
cd ~/packages
git clone https://github.com/KarypisLab/METIS.git
cd METIS
git checkout v5.2.1

# Symlink GKlib source (METIS expects it as a subdirectory)
ln -sf ../GKlib GKlib

# Generate metis.h with correct type widths
mkdir -p build/xinclude
echo "#define IDXTYPEWIDTH 32" > build/xinclude/metis.h
echo "#define REALTYPEWIDTH 32" >> build/xinclude/metis.h
cat include/metis.h >> build/xinclude/metis.h
cp include/CMakeLists.txt build/xinclude/

cd build
cmake .. \
    -DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DGKLIB_PATH="$HOME/packages/GKlib" \
    -DCMAKE_VERBOSE_MAKEFILE=1
make -j$(sysctl -n hw.ncpu)
make install
cd ../..
```

### Step 8d: Install ParMETIS

```bash
cd ~/packages
git clone https://github.com/KarypisLab/ParMETIS.git
cd ParMETIS
git checkout main

mkdir -p build && cd build
cmake .. \
    -DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX \
    -DCMAKE_C_COMPILER=$INSTALL_PREFIX/bin/mpicc \
    -DCMAKE_CXX_COMPILER=$INSTALL_PREFIX/bin/mpicxx \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DGKLIB_PATH="$INSTALL_PREFIX" \
    -DMETIS_PATH="$INSTALL_PREFIX" \
    -DCMAKE_VERBOSE_MAKEFILE=1
make -j$(sysctl -n hw.ncpu)
make install
cd ../..
```

> **Note:** `GKLIB_PATH` and `METIS_PATH` point to `$INSTALL_PREFIX` (where the installed headers with proper type defines are located), not to the source directories.

### Step 8e: Install MOAB

```bash
cd ~/packages
git clone https://bitbucket.org/fathomteam/moab.git
cd moab
git checkout master

autoreconf -fi

mkdir -p build && cd build
../configure \
    CC=$INSTALL_PREFIX/bin/mpicc \
    CXX=$INSTALL_PREFIX/bin/mpicxx \
    FC=$INSTALL_PREFIX/bin/mpif90 \
    F77=$INSTALL_PREFIX/bin/mpif77 \
    LIBS="-lGKlib" \
    --prefix=$INSTALL_PREFIX \
    --enable-debug --enable-optimize \
    --with-mpi=$INSTALL_PREFIX \
    --with-hdf5=$INSTALL_PREFIX \
    --with-netcdf=$INSTALL_PREFIX \
    --with-pnetcdf=$INSTALL_PREFIX \
    --with-metis=$INSTALL_PREFIX \
    --with-parmetis=$INSTALL_PREFIX \
    --with-eigen3=$INSTALL_PREFIX/include/eigen3 \
    --download-tempestremap \
    --download-zoltan

make -j$(sysctl -n hw.ncpu)
make install
cd ../..
```

> **Note:** `LIBS="-lGKlib"` is required because `libmetis.a` depends on GKlib symbols. The `--with-eigen3` path points to `$INSTALL_PREFIX/include/eigen3` (where the `Eigen/` directory resides). TempestRemap and Zoltan are downloaded and built automatically by MOAB's configure.

Verify MOAB:
```bash
ls $INSTALL_PREFIX/lib/libMOAB.a
```

## Manual Step 9: Final Verification

Run these commands to verify all installations:

```bash
echo "=== OpenMPI ==="
which mpicc mpif90
mpicc --version
mpif90 --version

echo "=== HDF5 ==="
which h5pcc
h5pcc --version

echo "=== NetCDF-C ==="
which nc-config
nc-config --version
nc-config --has-parallel4

echo "=== NetCDF-Fortran ==="
which nf-config
nf-config --version

echo "=== Environment Variables ==="
echo "INSTALL_PREFIX: $INSTALL_PREFIX"
echo "SDKROOT: $SDKROOT"
echo "PATH: $PATH"
echo "NETCDF_PATH: $NETCDF_PATH"
```

## Manual Step 10: Complete Shell Profile Configuration

Add all these lines to your `~/.zshrc` (or `~/.bash_profile` for bash):

```bash
# E3SM Build Environment
export INSTALL_PREFIX=$HOME/local/gcc11

# macOS SDK (required for GCC linking)
export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk
export LIBRARY_PATH=$SDKROOT/usr/lib:$LIBRARY_PATH

# PATH - put gcc11 installation FIRST to avoid Homebrew conflicts
export PATH=$INSTALL_PREFIX/bin:$PATH
export LD_LIBRARY_PATH=$INSTALL_PREFIX/lib:$LD_LIBRARY_PATH
export DYLD_LIBRARY_PATH=$INSTALL_PREFIX/lib:$DYLD_LIBRARY_PATH

# NetCDF paths for CIME
export NETCDF_PATH=$INSTALL_PREFIX
export NETCDF_C_PATH=$INSTALL_PREFIX
export NETCDF_FORTRAN_PATH=$INSTALL_PREFIX
```

After adding these, reload your shell:
```bash
source ~/.zshrc  # or source ~/.bash_profile
```

## Troubleshooting

### Issue: Homebrew Conflicts

If you have Homebrew's OpenMPI installed, it may conflict with your GCC 11 installation because Homebrew packages are typically built with the latest GCC version.

**Solution:** Ensure your `$INSTALL_PREFIX/bin` is **first** in your PATH, before `/opt/homebrew/bin`.

### Issue: Cannot Find System Libraries

If you see errors like `library not found for -lSystem`, ensure `SDKROOT` is set correctly:
```bash
echo $SDKROOT  # Should show /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk
```

### Issue: NetCDF Not Found During Build

If CIME cannot find NetCDF, verify all three environment variables are set:
```bash
echo $NETCDF_PATH
echo $NETCDF_C_PATH
echo $NETCDF_FORTRAN_PATH
```

## Next Steps

Once all packages are installed and verified:
1. Configure CIME for your machine (see `02-cime-configuration.md`)
2. Create and compile an E3SM case (see `03-case-creation-and-build.md`)
3. Download input data (see `04-input-data.md`)
4. Run your case (see `05-running-cases.md`)

## Build Time

Total time for all installations: approximately 30-60 minutes depending on your Mac's performance.
