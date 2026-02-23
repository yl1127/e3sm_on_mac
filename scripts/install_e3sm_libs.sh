#!/bin/bash
set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Installation configuration
export INSTALL_PREFIX=${INSTALL_PREFIX:-$HOME/local/gcc11}
export SDKROOT=${SDKROOT:-/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk}
export LIBRARY_PATH=$SDKROOT/usr/lib:$LIBRARY_PATH

LIBEVENT_VERSION=2.1.12-stable
OPENMPI_VERSION=5.0.6
PNETCDF_VERSION=1.12.3
HDF5_VERSION=1.14.5
NETCDF_C_VERSION=4.9.3
NETCDF_F_VERSION=4.6.2
EIGEN3_VERSION=3.4.0
GKLIB_REPO="https://github.com/KarypisLab/GKlib.git"
METIS_REPO="https://github.com/KarypisLab/METIS.git"
METIS_TAG=v5.2.1
PARMETIS_REPO="https://github.com/KarypisLab/ParMETIS.git"
PARMETIS_BRANCH=main
MOAB_BRANCH=master

NCORES=$(sysctl -n hw.ncpu)
PACKAGES_DIR=${PACKAGES_DIR:-$HOME/packages}

# Package URLs
LIBEVENT_URL="https://github.com/libevent/libevent/releases/download/release-${LIBEVENT_VERSION}/libevent-${LIBEVENT_VERSION}.tar.gz"
OPENMPI_URL="https://download.open-mpi.org/release/open-mpi/v5.0/openmpi-${OPENMPI_VERSION}.tar.gz"
PNETCDF_URL="https://parallel-netcdf.github.io/Release/pnetcdf-${PNETCDF_VERSION}.tar.gz"
HDF5_URL="https://github.com/HDFGroup/hdf5/archive/refs/tags/hdf5_${HDF5_VERSION}.tar.gz"
NETCDF_C_URL="https://github.com/Unidata/netcdf-c/archive/refs/tags/v${NETCDF_C_VERSION}.tar.gz"
NETCDF_F_URL="https://github.com/Unidata/netcdf-fortran/archive/refs/tags/v${NETCDF_F_VERSION}.tar.gz"
EIGEN3_URL="https://gitlab.com/libeigen/eigen/-/archive/${EIGEN3_VERSION}/eigen-${EIGEN3_VERSION}.tar.gz"
MOAB_URL="https://bitbucket.org/fathomteam/moab.git"

print_status() {
    echo -e "${GREEN}==>${NC} $1"
}

print_error() {
    echo -e "${RED}ERROR:${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}WARNING:${NC} $1"
}

show_help() {
    cat << EOF
E3SM Libraries Installation Script
===================================

Automated installation of required libraries for building E3SM on macOS with GCC 11.

Libraries installed:
  - OpenMPI ${OPENMPI_VERSION} (parallel computing)
  - PNetCDF ${PNETCDF_VERSION} (parallel NetCDF with classic format)
  - HDF5 ${HDF5_VERSION} (data format with parallel I/O)
  - NetCDF-C ${NETCDF_C_VERSION} (climate data format with parallel support)
  - NetCDF-Fortran ${NETCDF_F_VERSION} (Fortran interface to NetCDF)
  - Eigen3 ${EIGEN3_VERSION} (header-only linear algebra library)
  - GKlib (graph kernel library, required by METIS/ParMETIS)
  - METIS ${METIS_TAG} (graph partitioning)
  - ParMETIS (parallel graph partitioning)
  - MOAB (Mesh-Oriented datABase with TempestRemap and Zoltan)

Usage:
  $0 [OPTIONS] [COMMAND]

Options:
  -h, --help              Show this help message
  -p, --packages-dir DIR  Directory for downloading/building packages
                          (default: \$HOME/packages)
  -i, --install-dir DIR   Installation directory
                          (default: \$HOME/local/gcc11)

Commands:
  all              Install all packages (default in interactive mode)
  openmpi          Install OpenMPI only
  pnetcdf          Install PNetCDF only
  hdf5             Install HDF5 only
  netcdf-c         Install NetCDF-C only
  netcdf-fortran   Install NetCDF-Fortran only
  eigen3           Install Eigen3 only
  gklib            Install GKlib only
  metis            Install METIS (and GKlib)
  parmetis         Install ParMETIS (and GKlib, METIS)
  moab             Install MOAB (and Eigen3, GKlib, METIS, ParMETIS)
  verify           Verify installation
  check            Check prerequisites

Examples:
  # Interactive mode
  $0

  # Install everything
  $0 all

  # Install to custom directories
  $0 --packages-dir /tmp/builds --install-dir /opt/e3sm all

  # Install specific package
  $0 openmpi

  # Verify existing installation
  $0 verify

Environment Variables:
  INSTALL_PREFIX    Installation directory (default: \$HOME/local/gcc11)
  PACKAGES_DIR      Build directory (default: \$HOME/packages)
  SDKROOT          macOS SDK path (auto-detected)

Note: Run without arguments for interactive menu mode.

EOF
    exit 0
}

check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check for Homebrew
    if ! command -v brew &> /dev/null; then
        print_error "Homebrew not found. Install from https://brew.sh/"
        exit 1
    fi
    
    # Check for GCC 11
    if ! command -v gfortran-11 &> /dev/null; then
        print_warning "GCC 11 not found. Installing via Homebrew..."
        brew install gcc@11
    fi
    
    # Check SDK
    if [ ! -d "$SDKROOT" ]; then
        print_error "macOS SDK not found at $SDKROOT"
        print_error "Install Xcode Command Line Tools: xcode-select --install"
        exit 1
    fi
    
    # Check for cmake (needed for Eigen3, METIS, ParMETIS)
    if ! command -v cmake &> /dev/null; then
        print_warning "cmake not found. Installing via Homebrew..."
        brew install cmake
    fi
    
    # Check for autotools (needed for MOAB)
    if ! command -v autoreconf &> /dev/null; then
        print_warning "autotools not found. Installing via Homebrew..."
        brew install autoconf automake libtool
    fi
    
    # Check for git (needed for MOAB)
    if ! command -v git &> /dev/null; then
        print_warning "git not found. Installing via Homebrew..."
        brew install git
    fi
    
    # Check disk space (need at least 10GB)
    available_space=$(df -g . | awk 'NR==2 {print $4}')
    if [ "$available_space" -lt 10 ]; then
        print_warning "Less than 10GB free space available"
    fi
    
    print_status "Prerequisites OK"
}

install_libevent() {
    print_status "Installing libevent ${LIBEVENT_VERSION}..."
    
    if [ -f "$INSTALL_PREFIX/lib/libevent.a" ]; then
        print_warning "libevent already installed, skipping"
        return 0
    fi
    
    cd "$PACKAGES_DIR"
    if [ ! -f "libevent-${LIBEVENT_VERSION}.tar.gz" ]; then
        curl -LO "$LIBEVENT_URL"
    fi
    
    tar -xzf libevent-${LIBEVENT_VERSION}.tar.gz
    cd libevent-${LIBEVENT_VERSION}
    
    ./configure \
        --prefix=$INSTALL_PREFIX \
        --disable-shared \
        --enable-static \
        --disable-openssl \
        CC=clang \
        CFLAGS="-mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}"
    
    make -j${NCORES}
    make install
    cd ..
    
    print_status "libevent installed successfully"
}

install_openmpi() {
    print_status "Installing OpenMPI ${OPENMPI_VERSION}..."
    
    if [ -f "$INSTALL_PREFIX/bin/mpicc" ]; then
        print_warning "OpenMPI already installed, skipping"
        return 0
    fi
    
    cd "$PACKAGES_DIR"
    if [ ! -f "openmpi-${OPENMPI_VERSION}.tar.gz" ]; then
        curl -LO "$OPENMPI_URL"
    fi
    
    tar -xzf openmpi-${OPENMPI_VERSION}.tar.gz
    cd openmpi-${OPENMPI_VERSION}
    
    ./configure \
        CC=clang \
        CXX=clang++ \
        FC=gfortran-11 \
        CFLAGS="-mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}" \
        CXXFLAGS="-mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}" \
        FCFLAGS="-mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}" \
        --prefix=$INSTALL_PREFIX \
        --enable-mpi-fortran=yes \
        --with-libevent=$INSTALL_PREFIX \
        --with-hwloc=internal \
        --with-pmix=internal
    
    make -j${NCORES}
    make install
    cd ..
    
    # Update PATH immediately
    export PATH=$INSTALL_PREFIX/bin:$PATH
    export LD_LIBRARY_PATH=$INSTALL_PREFIX/lib:$LD_LIBRARY_PATH
    export DYLD_LIBRARY_PATH=$INSTALL_PREFIX/lib:$DYLD_LIBRARY_PATH
    
    print_status "OpenMPI installed successfully"
}

install_pnetcdf() {
    print_status "Installing PNetCDF ${PNETCDF_VERSION}..."
    
    if [ -f "$INSTALL_PREFIX/bin/pnetcdf-config" ]; then
        print_warning "PNetCDF already installed, skipping"
        return 0
    fi
    
    cd "$PACKAGES_DIR"
    if [ ! -f "pnetcdf-${PNETCDF_VERSION}.tar.gz" ]; then
        curl -LO "$PNETCDF_URL"
    fi
    
    tar -xzf pnetcdf-${PNETCDF_VERSION}.tar.gz
    cd pnetcdf-${PNETCDF_VERSION}
    
    # Ensure macOS SDK libraries are available to the linker
    export SDKROOT=$(xcrun --show-sdk-path)
    export LIBRARY_PATH=$SDKROOT/usr/lib:$LIBRARY_PATH
    
    # Find gfortran library path
    local GFORTRAN_LIB=$(gfortran-11 -print-file-name=libgfortran.dylib | xargs dirname)
    
    # Set combined linker flags
    export LDFLAGS="-L$GFORTRAN_LIB -L$INSTALL_PREFIX/lib -L$SDKROOT/usr/lib"
    
    ./configure \
        --prefix=$INSTALL_PREFIX \
        CC=$INSTALL_PREFIX/bin/mpicc \
        FC=$INSTALL_PREFIX/bin/mpif90 \
        F77=$INSTALL_PREFIX/bin/mpif77 \
        CFLAGS="-mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}" \
        FCFLAGS="-mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}"
    
    make -j${NCORES}
    make install
    cd ..
    
    print_status "PNetCDF installed successfully"
}

install_hdf5() {
    print_status "Installing HDF5 ${HDF5_VERSION}..."
    
    if [ -f "$INSTALL_PREFIX/bin/h5pcc" ]; then
        print_warning "HDF5 already installed, skipping"
        return 0
    fi
    
    cd "$PACKAGES_DIR"
    if [ ! -f "hdf5-${HDF5_VERSION}.tar.gz" ]; then
        curl -LO "$HDF5_URL"
    fi
    
    tar -xzf hdf5-${HDF5_VERSION}.tar.gz
    cd hdf5-${HDF5_VERSION}
    
    ./configure \
        --prefix=$INSTALL_PREFIX \
        --enable-fortran \
        --enable-parallel \
        CC=$INSTALL_PREFIX/bin/mpicc \
        FC=$INSTALL_PREFIX/bin/mpif90 \
        CFLAGS="-mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}" \
        FCFLAGS="-mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}"
    
    make -j${NCORES}
    make install
    cd ..
    
    print_status "HDF5 installed successfully"
}

install_netcdf_c() {
    print_status "Installing NetCDF-C ${NETCDF_C_VERSION}..."
    
    if [ -f "$INSTALL_PREFIX/bin/nc-config" ]; then
        print_warning "NetCDF-C already installed, skipping"
        return 0
    fi
    
    cd "$PACKAGES_DIR"
    if [ ! -f "v${NETCDF_C_VERSION}.tar.gz" ]; then
        curl -LO "$NETCDF_C_URL"
    fi
    
    tar -xzf v${NETCDF_C_VERSION}.tar.gz
    cd netcdf-c-${NETCDF_C_VERSION}
    
    export CPPFLAGS="-I$INSTALL_PREFIX/include"
    export LDFLAGS="-L$INSTALL_PREFIX/lib"
    
    ./configure \
        --prefix=$INSTALL_PREFIX \
        --enable-netcdf4 \
        --enable-parallel4 \
        --disable-dap \
        CC=$INSTALL_PREFIX/bin/mpicc \
        CFLAGS="-mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}"
    
    make -j${NCORES}
    make install
    cd ..
    
    print_status "NetCDF-C installed successfully"
}

install_netcdf_fortran() {
    print_status "Installing NetCDF-Fortran ${NETCDF_F_VERSION}..."
    
    if [ -f "$INSTALL_PREFIX/bin/nf-config" ]; then
        print_warning "NetCDF-Fortran already installed, skipping"
        return 0
    fi
    
    cd "$PACKAGES_DIR"
    if [ ! -f "v${NETCDF_F_VERSION}.tar.gz" ]; then
        curl -LO "$NETCDF_F_URL"
    fi
    
    tar -xzf v${NETCDF_F_VERSION}.tar.gz
    cd netcdf-fortran-${NETCDF_F_VERSION}
    
    export CPPFLAGS="-I$INSTALL_PREFIX/include"
    export LDFLAGS="-L$INSTALL_PREFIX/lib"
    
    ./configure \
        --prefix=$INSTALL_PREFIX \
        CC=$INSTALL_PREFIX/bin/mpicc \
        FC=$INSTALL_PREFIX/bin/mpif90 \
        CFLAGS="-mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}" \
        FCFLAGS="-mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}"
    
    make -j${NCORES}
    make install
    cd ..
    
    print_status "NetCDF-Fortran installed successfully"
}

install_eigen3() {
    print_status "Installing Eigen3 ${EIGEN3_VERSION}..."
    
    if [ -d "$INSTALL_PREFIX/include/eigen3/Eigen" ]; then
        print_warning "Eigen3 already installed, skipping"
        return 0
    fi
    
    cd "$PACKAGES_DIR"
    if [ ! -f "eigen-${EIGEN3_VERSION}.tar.gz" ]; then
        curl -LO "$EIGEN3_URL"
    fi
    
    tar -xzf eigen-${EIGEN3_VERSION}.tar.gz
    cd eigen-${EIGEN3_VERSION}
    
    rm -rf build && mkdir -p build && cd build
    cmake .. \
        -DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        -DBUILD_TESTING=OFF
    make install
    cd ../..
    
    print_status "Eigen3 installed successfully"
}

install_gklib() {
    print_status "Installing GKlib..."
    
    if [ -f "$INSTALL_PREFIX/lib/libGKlib.a" ]; then
        print_warning "GKlib already installed, skipping"
        return 0
    fi
    
    cd "$PACKAGES_DIR"
    if [ ! -d "GKlib" ]; then
        git clone "$GKLIB_REPO"
    fi
    cd GKlib
    
    rm -rf build && mkdir -p build && cd build
    cmake .. \
        -DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX \
        -DCMAKE_C_COMPILER=clang \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        -DBUILD_SHARED_LIBS=OFF \
        -DGKLIB_BUILD_APPS=OFF \
        -DNO_X86=ON
    make -j${NCORES}
    make install
    cd ../..
    
    print_status "GKlib installed successfully"
}

install_metis() {
    print_status "Installing METIS ${METIS_TAG}..."
    
    if [ -f "$INSTALL_PREFIX/lib/libmetis.a" ] || [ -f "$INSTALL_PREFIX/lib/libmetis.dylib" ]; then
        print_warning "METIS already installed, skipping"
        return 0
    fi
    
    cd "$PACKAGES_DIR"
    if [ ! -d "METIS" ]; then
        git clone "$METIS_REPO"
    fi
    cd METIS
    git checkout ${METIS_TAG}
    
    # Ensure GKlib submodule is available
    if [ ! -f "GKlib/GKlibSystem.cmake" ]; then
        if [ -d "$PACKAGES_DIR/GKlib" ]; then
            rm -rf GKlib
            ln -s "$PACKAGES_DIR/GKlib" GKlib
        else
            git submodule update --init
        fi
    fi
    
    # Use cmake directly instead of the Makefile wrapper
    # (the Makefile mishandles gklib_path with ~ and abspath)
    rm -rf build && mkdir -p build
    
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
        -DGKLIB_PATH="$PACKAGES_DIR/GKlib" \
        -DCMAKE_VERBOSE_MAKEFILE=1
    make -j${NCORES}
    make install
    cd ../..
    
    print_status "METIS installed successfully"
}

install_parmetis() {
    print_status "Installing ParMETIS (branch: ${PARMETIS_BRANCH})..."
    
    if [ -f "$INSTALL_PREFIX/lib/libparmetis.a" ] || [ -f "$INSTALL_PREFIX/lib/libparmetis.dylib" ]; then
        print_warning "ParMETIS already installed, skipping"
        return 0
    fi
    
    cd "$PACKAGES_DIR"
    if [ ! -d "ParMETIS" ]; then
        git clone "$PARMETIS_REPO"
    fi
    cd ParMETIS
    git checkout ${PARMETIS_BRANCH}
    
    # Use cmake directly (the Makefile has the same ~/local abspath bug as METIS)
    # Point GKLIB_PATH and METIS_PATH to the install prefix where headers/libs are installed
    rm -rf build && mkdir -p build && cd build
    cmake .. \
        -DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX \
        -DCMAKE_C_COMPILER=$INSTALL_PREFIX/bin/mpicc \
        -DCMAKE_CXX_COMPILER=$INSTALL_PREFIX/bin/mpicxx \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        -DGKLIB_PATH="$INSTALL_PREFIX" \
        -DMETIS_PATH="$INSTALL_PREFIX" \
        -DCMAKE_VERBOSE_MAKEFILE=1
    make -j${NCORES}
    make install
    cd ../..
    
    print_status "ParMETIS installed successfully"
}

install_moab() {
    print_status "Installing MOAB (branch: ${MOAB_BRANCH})..."
    
    if [ -f "$INSTALL_PREFIX/lib/libMOAB.a" ] || [ -f "$INSTALL_PREFIX/lib/libMOAB.dylib" ]; then
        print_warning "MOAB already installed, skipping"
        return 0
    fi
    
    cd "$PACKAGES_DIR"
    if [ ! -d "moab" ]; then
        git clone "$MOAB_URL"
    fi
    cd moab
    git checkout ${MOAB_BRANCH}
    git pull origin ${MOAB_BRANCH} 2>/dev/null || true
    
    # Ensure autoreconf is available (needed to generate configure script)
    if ! command -v autoreconf &> /dev/null; then
        print_status "Installing autotools (required for MOAB)..."
        brew install autoconf automake libtool
    fi
    
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
    
    make -j${NCORES}
    make install
    cd ../..
    
    print_status "MOAB installed successfully"
}

verify_installation() {
    print_status "Verifying installation..."
    
    local all_ok=true
    
    # Check OpenMPI
    if [ -f "$INSTALL_PREFIX/bin/mpicc" ]; then
        echo -e "${GREEN}✓${NC} OpenMPI: $($INSTALL_PREFIX/bin/mpicc --version | head -1)"
    else
        echo -e "${RED}✗${NC} OpenMPI: NOT FOUND"
        all_ok=false
    fi
    
    # Check PNetCDF
    if [ -f "$INSTALL_PREFIX/bin/pnetcdf-config" ]; then
        echo -e "${GREEN}✓${NC} PNetCDF: $($INSTALL_PREFIX/bin/pnetcdf-config --version)"
    else
        echo -e "${RED}✗${NC} PNetCDF: NOT FOUND"
        all_ok=false
    fi
    
    # Check HDF5
    if [ -f "$INSTALL_PREFIX/bin/h5pcc" ]; then
        echo -e "${GREEN}✓${NC} HDF5: $($INSTALL_PREFIX/bin/h5pcc -showconfig | grep 'HDF5 Version' | cut -d: -f2)"
    else
        echo -e "${RED}✗${NC} HDF5: NOT FOUND"
        all_ok=false
    fi
    
    # Check NetCDF-C
    if [ -f "$INSTALL_PREFIX/bin/nc-config" ]; then
        local parallel=$($INSTALL_PREFIX/bin/nc-config --has-parallel4)
        echo -e "${GREEN}✓${NC} NetCDF-C: $($INSTALL_PREFIX/bin/nc-config --version) (parallel: $parallel)"
    else
        echo -e "${RED}✗${NC} NetCDF-C: NOT FOUND"
        all_ok=false
    fi
    
    # Check NetCDF-Fortran
    if [ -f "$INSTALL_PREFIX/bin/nf-config" ]; then
        echo -e "${GREEN}✓${NC} NetCDF-Fortran: $($INSTALL_PREFIX/bin/nf-config --version)"
    else
        echo -e "${RED}✗${NC} NetCDF-Fortran: NOT FOUND"
        all_ok=false
    fi
    
    # Check Eigen3
    if [ -d "$INSTALL_PREFIX/include/eigen3/Eigen" ]; then
        echo -e "${GREEN}✓${NC} Eigen3: ${EIGEN3_VERSION}"
    else
        echo -e "${RED}✗${NC} Eigen3: NOT FOUND"
        all_ok=false
    fi
    
    # Check GKlib
    if [ -f "$INSTALL_PREFIX/lib/libGKlib.a" ]; then
        echo -e "${GREEN}✓${NC} GKlib: installed"
    else
        echo -e "${RED}✗${NC} GKlib: NOT FOUND"
        all_ok=false
    fi
    
    # Check METIS
    if [ -f "$INSTALL_PREFIX/lib/libmetis.a" ] || [ -f "$INSTALL_PREFIX/lib/libmetis.dylib" ]; then
        echo -e "${GREEN}✓${NC} METIS: ${METIS_TAG}"
    else
        echo -e "${RED}✗${NC} METIS: NOT FOUND"
        all_ok=false
    fi
    
    # Check ParMETIS
    if [ -f "$INSTALL_PREFIX/lib/libparmetis.a" ] || [ -f "$INSTALL_PREFIX/lib/libparmetis.dylib" ]; then
        echo -e "${GREEN}✓${NC} ParMETIS: installed (branch: ${PARMETIS_BRANCH})"
    else
        echo -e "${RED}✗${NC} ParMETIS: NOT FOUND"
        all_ok=false
    fi
    
    # Check MOAB
    if [ -f "$INSTALL_PREFIX/lib/libMOAB.a" ] || [ -f "$INSTALL_PREFIX/lib/libMOAB.dylib" ]; then
        echo -e "${GREEN}✓${NC} MOAB: installed (branch: ${MOAB_BRANCH})"
    else
        echo -e "${RED}✗${NC} MOAB: NOT FOUND"
        all_ok=false
    fi
    
    if [ "$all_ok" = true ]; then
        print_status "All packages installed successfully!"
        echo ""
        print_status "Add these to your ~/.zshrc:"
        echo "export INSTALL_PREFIX=$INSTALL_PREFIX"
        echo "export SDKROOT=$SDKROOT"
        echo "export LIBRARY_PATH=\$SDKROOT/usr/lib:\$LIBRARY_PATH"
        echo "export PATH=\$INSTALL_PREFIX/bin:\$PATH"
        echo "export LD_LIBRARY_PATH=\$INSTALL_PREFIX/lib:\$LD_LIBRARY_PATH"
        echo "export DYLD_LIBRARY_PATH=\$INSTALL_PREFIX/lib:\$DYLD_LIBRARY_PATH"
        echo "export PNETCDF_PATH=\$INSTALL_PREFIX"
        echo "export NETCDF_PATH=\$INSTALL_PREFIX"
        echo "export NETCDF_C_PATH=\$INSTALL_PREFIX"
        echo "export NETCDF_FORTRAN_PATH=\$INSTALL_PREFIX"
        echo "export MOAB_PATH=\$INSTALL_PREFIX"
    else
        print_error "Some packages failed to install"
        exit 1
    fi
}

show_menu() {
    echo ""
    echo "E3SM Libraries Installation Script"
    echo "==================================="
    echo "Installation prefix: $INSTALL_PREFIX"
    echo "Packages directory: $PACKAGES_DIR"
    echo ""
    echo "1) Install all packages (recommended)"
    echo "2) Install libevent only"
    echo "3) Install OpenMPI only"
    echo "4) Install PNetCDF only"
    echo "5) Install HDF5 only"
    echo "6) Install NetCDF-C only"
    echo "7) Install NetCDF-Fortran only"
    echo "8) Install Eigen3 only"
    echo "9) Install GKlib only"
    echo "10) Install METIS only"
    echo "11) Install ParMETIS only"
    echo "12) Install MOAB (with deps)"
    echo "13) Verify installation"
    echo "14) Check prerequisites"
    echo "0) Exit"
    echo ""
    read -p "Choose an option: " choice
}

main() {
    # Parse command-line arguments
    local command=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                ;;
            -p|--packages-dir)
                PACKAGES_DIR="$2"
                shift 2
                ;;
            -i|--install-dir)
                export INSTALL_PREFIX="$2"
                shift 2
                ;;
            all|libevent|openmpi|pnetcdf|hdf5|netcdf-c|netcdf-fortran|eigen3|gklib|metis|parmetis|moab|verify|check)
                command="$1"
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    # Create directories
    mkdir -p "$PACKAGES_DIR"
    mkdir -p "$INSTALL_PREFIX"
    
    if [ -z "$command" ]; then
        # Interactive mode
        while true; do
            show_menu
            case $choice in
                1)
                    check_prerequisites
                    install_libevent
                    install_openmpi
                    install_pnetcdf
                    install_hdf5
                    install_netcdf_c
                    install_netcdf_fortran
                    install_eigen3
                    install_gklib
                    install_metis
                    install_parmetis
                    install_moab
                    verify_installation
                    break
                    ;;
                2) install_libevent ;;
                3) install_libevent && install_openmpi ;;
                4) install_pnetcdf ;;
                5) install_hdf5 ;;
                6) install_netcdf_c ;;
                7) install_netcdf_fortran ;;
                8) install_eigen3 ;;
                9) install_gklib ;;
                10) install_gklib && install_metis ;;
                11) install_gklib && install_metis && install_parmetis ;;
                12) install_eigen3 && install_gklib && install_metis && install_parmetis && install_moab ;;
                13) verify_installation ;;
                14) check_prerequisites ;;
                0) exit 0 ;;
                *) print_error "Invalid option" ;;
            esac
        done
    else
        # Command-line mode
        case "$command" in
            all)
                check_prerequisites
                install_libevent
                install_openmpi
                install_pnetcdf
                install_hdf5
                install_netcdf_c
                install_netcdf_fortran
                install_eigen3
                install_gklib
                install_metis
                install_parmetis
                install_moab
                verify_installation
                ;;
            libevent) install_libevent ;;
            openmpi) install_libevent && install_openmpi ;;
            pnetcdf) install_pnetcdf ;;
            hdf5) install_hdf5 ;;
            netcdf-c) install_netcdf_c ;;
            netcdf-fortran) install_netcdf_fortran ;;
            eigen3) install_eigen3 ;;
            gklib) install_gklib ;;
            metis) install_gklib && install_metis ;;
            parmetis) install_gklib && install_metis && install_parmetis ;;
            moab) install_eigen3 && install_gklib && install_metis && install_parmetis && install_moab ;;
            verify) verify_installation ;;
            check) check_prerequisites ;;
        esac
    fi
}

main "$@"
