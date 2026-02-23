#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}==>${NC} $1"
}

print_error() {
    echo -e "${RED}ERROR:${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}WARNING:${NC} $1"
}

print_info() {
    echo -e "${BLUE}INFO:${NC} $1"
}

show_help() {
    cat << EOF
E3SM CIME Configuration Generator
==================================

Automatically generates CIME configuration files for your Mac.

Usage:
  $0 [OPTIONS]

Options:
  -h, --help              Show this help message
  -m, --machine NAME      Machine name (default: hostname)
  -c, --compiler NAME     Compiler name (default: gnu11)
  --install-prefix DIR    Installation prefix (default: \$HOME/local/gcc11)
  --cores NUM             Number of CPU cores (default: auto-detect)
  --force                 Overwrite existing configuration files

Generated Files:
  ~/.cime/config_machines.xml
  ~/.cime/config_compilers.xml
  ~/.cime/<compiler>_<machine>.cmake

Examples:
  # Auto-detect everything
  $0

  # Specify custom machine name
  $0 --machine MyMacBook

  # Use different compiler name and install prefix
  $0 --compiler gnu13 --install-prefix /opt/gcc13

  # Force overwrite existing files
  $0 --force

EOF
    exit 0
}

detect_compilers() {
    print_status "Detecting compilers..."
    
    INSTALL_PREFIX=${INSTALL_PREFIX:-$HOME/local/gcc11}
    
    # Serial compilers
    SCC=$(command -v clang || echo "")
    SCXX=$(command -v clang++ || echo "")
    SFC=$(command -v gfortran-11 || command -v gfortran || echo "")
    
    # MPI compilers
    if [ -f "$INSTALL_PREFIX/bin/mpicc" ]; then
        MPICC="$INSTALL_PREFIX/bin/mpicc"
        MPICXX="$INSTALL_PREFIX/bin/mpicxx"
        MPIFC="$INSTALL_PREFIX/bin/mpif90"
    else
        MPICC=$(command -v mpicc || echo "")
        MPICXX=$(command -v mpicxx || echo "")
        MPIFC=$(command -v mpif90 || echo "")
    fi
    
    # Validate required compilers
    local missing=()
    [ -z "$SCC" ] && missing+=("clang")
    [ -z "$SCXX" ] && missing+=("clang++")
    [ -z "$SFC" ] && missing+=("gfortran-11")
    [ -z "$MPICC" ] && missing+=("mpicc")
    [ -z "$MPICXX" ] && missing+=("mpicxx")
    [ -z "$MPIFC" ] && missing+=("mpif90")
    
    if [ ${#missing[@]} -gt 0 ]; then
        print_error "Missing compilers: ${missing[*]}"
        print_error "Please install required packages (see 01-package-installation.md)"
        exit 1
    fi
    
    print_info "Serial C compiler:     $SCC"
    print_info "Serial C++ compiler:   $SCXX"
    print_info "Serial Fortran:        $SFC"
    print_info "MPI C compiler:        $MPICC"
    print_info "MPI C++ compiler:      $MPICXX"
    print_info "MPI Fortran compiler:  $MPIFC"
}

detect_system() {
    print_status "Detecting system configuration..."
    
    # Machine name
    MACHINE_NAME=${MACHINE_NAME:-$(hostname -s)}
    
    # CPU cores
    if [ -z "$MAX_CORES" ]; then
        MAX_CORES=$(sysctl -n hw.ncpu)
    fi
    
    # SDK root
    SDKROOT=${SDKROOT:-/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk}
    if [ ! -d "$SDKROOT" ]; then
        print_warning "macOS SDK not found at $SDKROOT"
        print_warning "You may need to run: xcode-select --install"
    fi
    
    # User info
    USER_NAME=$(git config user.name 2>/dev/null || echo "Your Name")
    USER_EMAIL=$(git config user.email 2>/dev/null || echo "your.email@example.com")
    
    # Check if MOAB is installed
    MOAB_INSTALLED="false"
    if [ -f "$INSTALL_PREFIX/lib/libMOAB.a" ] || [ -f "$INSTALL_PREFIX/lib/libMOAB.dylib" ]; then
        MOAB_INSTALLED="true"
    fi

    print_info "Machine name:          $MACHINE_NAME"
    print_info "CPU cores:             $MAX_CORES"
    print_info "macOS SDK:             $SDKROOT"
    print_info "MOAB installed:        $MOAB_INSTALLED"
    print_info "Supported by:          $USER_NAME ($USER_EMAIL)"
}

generate_config_machines() {
    local output_file="$HOME/.cime/config_machines.xml"
    
    if [ -f "$output_file" ] && [ "$FORCE" != "true" ]; then
        print_warning "File exists: $output_file"
        read -p "Overwrite? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Skipping config_machines.xml"
            return
        fi
    fi
    
    print_status "Generating config_machines.xml..."
    
    cat > "$output_file" << EOF
<?xml version="1.0"?>
<config_machines version="2.0">
  <machine MACH="$MACHINE_NAME">
    <DESC>Personal MacBook, OS=macOS, system=Darwin, $MAX_CORES pes/node</DESC>
    <NODENAME_REGEX>$MACHINE_NAME</NODENAME_REGEX>
    <OS>Darwin</OS>
    <COMPILERS>$COMPILER_NAME</COMPILERS>
    <MPILIBS>openmpi</MPILIBS>
    <PROJECT>E3SM</PROJECT>
    <SAVE_TIMING_DIR/>
    <CIME_OUTPUT_ROOT>\$ENV{HOME}/projects/e3sm/scratch</CIME_OUTPUT_ROOT>
    <DIN_LOC_ROOT>\$ENV{HOME}/projects/e3sm/inputdata</DIN_LOC_ROOT>
    <DIN_LOC_ROOT_CLMFORC>\$ENV{HOME}/projects/e3sm/inputdata/atm/datm7</DIN_LOC_ROOT_CLMFORC>
    <DOUT_S_ROOT>\$CIME_OUTPUT_ROOT/archive/\$CASE</DOUT_S_ROOT>
    <BASELINE_ROOT>\$ENV{HOME}/projects/e3sm/baselines</BASELINE_ROOT>
    <CCSM_CPRNC>\$ENV{HOME}/local/gcc11/bin/cprnc</CCSM_CPRNC>
    <GMAKE_J>$MAX_CORES</GMAKE_J>
    <BATCH_SYSTEM>none</BATCH_SYSTEM>
    <SUPPORTED_BY>$USER_NAME ($USER_EMAIL)</SUPPORTED_BY>
    <MAX_TASKS_PER_NODE>$MAX_CORES</MAX_TASKS_PER_NODE>
    <MAX_MPITASKS_PER_NODE>$MAX_CORES</MAX_MPITASKS_PER_NODE>
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
      <env name="NETCDF_PATH">$INSTALL_PREFIX</env>
$(if [ "$MOAB_INSTALLED" = "true" ]; then echo "      <env name=\"MOAB_ROOT\">$INSTALL_PREFIX</env>"; fi)
    </environment_variables>
  </machine>
</config_machines>
EOF
    
    print_status "Created: $output_file"
}

generate_config_compilers() {
    local output_file="$HOME/.cime/config_compilers.xml"
    
    if [ -f "$output_file" ] && [ "$FORCE" != "true" ]; then
        print_warning "File exists: $output_file"
        read -p "Overwrite? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Skipping config_compilers.xml"
            return
        fi
    fi
    
    print_status "Generating config_compilers.xml..."
    
    cat > "$output_file" << EOF
<?xml version="1.0"?>
<config_compilers version="2.0">
  <compiler MACH="$MACHINE_NAME" COMPILER="$COMPILER_NAME">
    <MPICC>$MPICC</MPICC>
    <MPICXX>$MPICXX</MPICXX>
    <MPIFC>$MPIFC</MPIFC>
    <SCC>$SCC</SCC>
    <SCXX>$SCXX</SCXX>
    <SFC>$SFC</SFC>
  </compiler>
</config_compilers>
EOF
    
    print_status "Created: $output_file"
}

generate_cmake_macros() {
    local output_file="$HOME/.cime/${COMPILER_NAME}_${MACHINE_NAME}.cmake"
    
    if [ -f "$output_file" ] && [ "$FORCE" != "true" ]; then
        print_warning "File exists: $output_file"
        read -p "Overwrite? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Skipping cmake macros"
            return
        fi
    fi
    
    print_status "Generating CMake macros..."
    
    cat > "$output_file" << EOF
set(MPICC "$MPICC")
set(MPICXX "$MPICXX")
set(MPIFC "$MPIFC")
set(SCC "$SCC")
set(SCXX "$SCXX")
set(SFC "$SFC")

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
string(APPEND LDFLAGS " -L\$ENV{SDKROOT}/usr/lib")
string(APPEND LDFLAGS " -L$INSTALL_PREFIX/lib")
EOF
    
    print_status "Created: $output_file"
}

show_summary() {
    echo ""
    print_status "CIME configuration complete!"
    echo ""
    echo "Generated files:"
    echo "  - ~/.cime/config_machines.xml"
    echo "  - ~/.cime/config_compilers.xml"
    echo "  - ~/.cime/${COMPILER_NAME}_${MACHINE_NAME}.cmake"
    echo ""
    print_info "Machine name: $MACHINE_NAME"
    print_info "Compiler: $COMPILER_NAME"
    echo ""
    print_status "Next steps:"
    echo "1. Ensure environment variables in ~/.zshrc (see 01-package-installation.md)"
    echo "2. Verify E3SM source modification (see 02-cime-configuration.md, Step 4)"
    echo "3. Create directories:"
    echo "   mkdir -p ~/projects/e3sm/{scratch,inputdata,baselines}"
    echo "4. Test with: cd \$E3SM_ROOT/cime/scripts && ./query_config --machines"
    echo ""
}

main() {
    # Default values
    COMPILER_NAME="gnu11"
    FORCE="false"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                ;;
            -m|--machine)
                MACHINE_NAME="$2"
                shift 2
                ;;
            -c|--compiler)
                COMPILER_NAME="$2"
                shift 2
                ;;
            --install-prefix)
                INSTALL_PREFIX="$2"
                shift 2
                ;;
            --cores)
                MAX_CORES="$2"
                shift 2
                ;;
            --force)
                FORCE="true"
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    echo ""
    echo "E3SM CIME Configuration Generator"
    echo "=================================="
    echo ""
    
    # Detect system and compilers
    detect_system
    detect_compilers
    
    echo ""
    read -p "Continue with configuration? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        print_info "Aborted by user"
        exit 0
    fi
    
    # Create directories
    mkdir -p "$HOME/.cime"
    
    # Generate configuration files
    generate_config_machines
    generate_config_compilers
    generate_cmake_macros
    
    # Show summary
    show_summary
}

main "$@"
