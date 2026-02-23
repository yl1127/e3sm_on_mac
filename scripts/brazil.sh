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
E3SM Case Creation Script
==========================

Creates and configures single-point land model cases for E3SM.

Usage:
  $0 [OPTIONS]

Options:
  -h, --help                Show this help message
  -e, --e3sm-root DIR       Path to E3SM repository (default: \$E3SM_ROOT or auto-detect)
  -m, --machine NAME        Machine name (default: auto-detect from CIME)
  -c, --compiler NAME       Compiler name (default: gnu11)
  -r, --res RESOLUTION      Grid resolution (default: 1x1_brazil)
  --compset COMPSET         Component set (default: I1850ELM)
  --case-name NAME          Custom case name (default: auto-generated with git hash)
  --case-dir DIR            Case directory (default: <e3sm-root>/cime/scripts/<case-name>)
  --datm-end-year YEAR      DATM forcing end year (default: 1948, limits data download)
  --build                   Build the case immediately after setup
  --submit                  Submit the case after building (implies --build)

Generated Case Name Format (if not specified):
  <res>.<compset>.<machine>.<compiler>.<git-hash>.<date>

Example:
  1x1_brazil.I1850ELM.MyMac.gnu11.abc1234.2026-02-13

Examples:
  # Auto-detect E3SM root, use defaults
  $0

  # Specify E3SM location
  $0 --e3sm-root ~/projects/e3sm/e3sm

  # Custom machine and build immediately
  $0 --machine MyMacBook --build

  # Different resolution and compset
  $0 --res 1x1_mexicocityMEX --compset I2000ELM

  # Custom case name and directory
  $0 --case-name my_test --case-dir ~/e3sm_cases

  # Download more years of forcing data
  $0 --datm-end-year 1950

Common Resolutions:
  1x1_brazil          - Single point in Brazil
  1x1_mexicocityMEX   - Single point in Mexico City
  1x1_vancouverCAN    - Single point in Vancouver
  1x1_urbanc_alpha    - Urban test point
  CLM_USRDAT          - User-defined domain

Common Compsets:
  I1850ELM            - Land-only, 1850 conditions
  I2000ELM            - Land-only, 2000 conditions
  I1850CRUELMCN       - Land with CRU-NCEP forcing

For more info, see:
  https://e3sm.org/model/running-e3sm/e3sm-quick-start/

EOF
    exit 0
}

detect_e3sm_root() {
    if [ -n "$E3SM_ROOT_ARG" ]; then
        E3SM_ROOT="$E3SM_ROOT_ARG"
    elif [ -n "$E3SM_ROOT" ]; then
        print_info "Using E3SM_ROOT from environment: $E3SM_ROOT"
    else
        # Try to auto-detect
        local search_paths=(
            "$HOME/projects/e3sm/e3sm"
            "$HOME/e3sm"
            "$HOME/E3SM"
            "$(pwd)"
        )
        
        for path in "${search_paths[@]}"; do
            if [ -d "$path/cime/scripts" ]; then
                E3SM_ROOT="$path"
                print_info "Auto-detected E3SM root: $E3SM_ROOT"
                break
            fi
        done
    fi
    
    if [ -z "$E3SM_ROOT" ]; then
        print_error "Cannot find E3SM repository"
        print_error "Please specify with --e3sm-root or set E3SM_ROOT environment variable"
        exit 1
    fi
    
    if [ ! -d "$E3SM_ROOT/cime/scripts" ]; then
        print_error "Invalid E3SM root: $E3SM_ROOT"
        print_error "Directory does not contain cime/scripts/"
        exit 1
    fi
}

detect_machine() {
    if [ -n "$MACHINE_ARG" ]; then
        MACHINE="$MACHINE_ARG"
        return
    fi
    
    # Try to detect from CIME config
    if [ -f "$HOME/.cime/config_machines.xml" ]; then
        # Extract machine name from config_machines.xml
        MACHINE=$(grep 'MACH=' "$HOME/.cime/config_machines.xml" | head -1 | sed 's/.*MACH="\([^"]*\)".*/\1/')
        if [ -n "$MACHINE" ]; then
            print_info "Detected machine from CIME config: $MACHINE"
            return
        fi
    fi
    
    # Fallback to hostname
    MACHINE=$(hostname -s)
    print_warning "Could not detect machine from CIME config, using hostname: $MACHINE"
}

get_git_hash() {
    cd "$E3SM_ROOT"
    GIT_HASH=$(git log -n 1 --format=%h 2>/dev/null || echo "nogit")
    cd - > /dev/null
}

generate_case_name() {
    if [ -n "$CASE_NAME_ARG" ]; then
        CASE_NAME="$CASE_NAME_ARG"
    else
        local date_str=$(date "+%Y-%m-%d")
        CASE_NAME="${RESOLUTION}.${COMPSET}.${MACHINE}.${COMPILER}.${GIT_HASH}.${date_str}"
    fi
}

validate_settings() {
    print_status "Validating configuration..."
    
    # Check create_newcase script exists
    if [ ! -f "$E3SM_ROOT/cime/scripts/create_newcase" ]; then
        print_error "create_newcase script not found at: $E3SM_ROOT/cime/scripts/"
        exit 1
    fi
    
    # Check if case directory already exists
    if [ -d "$CASE_DIR" ]; then
        print_error "Case directory already exists: $CASE_DIR"
        print_error "Remove it first or choose a different case name"
        exit 1
    fi
    
    print_info "E3SM root:         $E3SM_ROOT"
    print_info "Machine:           $MACHINE"
    print_info "Compiler:          $COMPILER"
    print_info "Resolution:        $RESOLUTION"
    print_info "Compset:           $COMPSET"
    print_info "Case name:         $CASE_NAME"
    print_info "Case directory:    $CASE_DIR"
    print_info "DATM end year:     $DATM_END_YEAR"
    print_info "Git hash:          $GIT_HASH"
}

create_case() {
    print_status "Creating E3SM case..."
    
    cd "$E3SM_ROOT/cime/scripts"
    
    ./create_newcase \
        --case "$CASE_DIR" \
        --res "$RESOLUTION" \
        --mach "$MACHINE" \
        --compiler "$COMPILER" \
        --compset "$COMPSET"
    
    if [ $? -ne 0 ]; then
        print_error "Case creation failed"
        exit 1
    fi
    
    print_status "Case created successfully"
}

configure_case() {
    print_status "Configuring case..."
    
    cd "$CASE_DIR"
    
    # CRITICAL: Limit atmospheric forcing data to avoid downloading 20+ years
    print_info "Setting DATM_CLMNCEP_YR_END=$DATM_END_YEAR (limits data download)"
    ./xmlchange DATM_CLMNCEP_YR_END=$DATM_END_YEAR
    
    # Configure I/O and MPI settings
    print_info "Configuring I/O and MPI settings"
    ./xmlchange PIO_TYPENAME=netcdf
    ./xmlchange MPILIB=openmpi
    ./xmlchange PIO_VERSION=2
    
    # Use local run/build directories (easier to manage on laptops)
    print_info "Setting local run and build directories"
    ./xmlchange RUNDIR=${CASE_DIR}/run
    ./xmlchange EXEROOT=${CASE_DIR}/bld
    
    print_status "Running case.setup..."
    ./case.setup
    
    if [ $? -ne 0 ]; then
        print_error "Case setup failed"
        exit 1
    fi
    
    print_status "Case configured successfully"
}

build_case() {
    if [ "$BUILD_CASE" = "true" ]; then
        print_status "Building case..."
        cd "$CASE_DIR"
        ./case.build
        
        if [ $? -ne 0 ]; then
            print_error "Build failed"
            exit 1
        fi
        
        print_status "Build completed successfully"
    fi
}

submit_case() {
    if [ "$SUBMIT_CASE" = "true" ]; then
        print_status "Submitting case..."
        cd "$CASE_DIR"
        ./case.submit
        
        if [ $? -ne 0 ]; then
            print_error "Submit failed"
            exit 1
        fi
        
        print_status "Case submitted successfully"
    fi
}

show_summary() {
    echo ""
    print_status "Case creation complete!"
    echo ""
    echo "Case directory: $CASE_DIR"
    echo ""
    print_status "Next steps:"
    
    if [ "$BUILD_CASE" != "true" ]; then
        echo "1. Navigate to case directory:"
        echo "   cd $CASE_DIR"
        echo ""
        echo "2. Review configuration (optional):"
        echo "   ./xmlquery STOP_OPTION      # Check run duration"
        echo "   ./xmlquery DATM_CLMNCEP_YR_END  # Verify forcing data limit"
        echo ""
        echo "3. Build the case:"
        echo "   ./case.build"
        echo ""
        echo "4. Download input data:"
        echo "   ./check_input_data --download"
        echo ""
        echo "5. Submit the run:"
        echo "   ./case.submit"
    elif [ "$SUBMIT_CASE" != "true" ]; then
        echo "1. Navigate to case directory:"
        echo "   cd $CASE_DIR"
        echo ""
        echo "2. Download input data:"
        echo "   ./check_input_data --download"
        echo ""
        echo "3. Submit the run:"
        echo "   ./case.submit"
    else
        echo "Case is running! Monitor progress:"
        echo "   cd $CASE_DIR"
        echo "   tail -f run/e3sm.log.*"
    fi
    
    echo ""
    print_info "For more information, see 03-case-creation-and-build.md"
    echo ""
}

main() {
    # Default values
    COMPILER="gnu11"
    RESOLUTION="1x1_brazil"
    COMPSET="I1850ELM"
    DATM_END_YEAR="1948"
    BUILD_CASE="false"
    SUBMIT_CASE="false"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                ;;
            -e|--e3sm-root)
                E3SM_ROOT_ARG="$2"
                shift 2
                ;;
            -m|--machine)
                MACHINE_ARG="$2"
                shift 2
                ;;
            -c|--compiler)
                COMPILER="$2"
                shift 2
                ;;
            -r|--res)
                RESOLUTION="$2"
                shift 2
                ;;
            --compset)
                COMPSET="$2"
                shift 2
                ;;
            --case-name)
                CASE_NAME_ARG="$2"
                shift 2
                ;;
            --case-dir)
                CASE_DIR_ARG="$2"
                shift 2
                ;;
            --datm-end-year)
                DATM_END_YEAR="$2"
                shift 2
                ;;
            --build)
                BUILD_CASE="true"
                shift
                ;;
            --submit)
                BUILD_CASE="true"
                SUBMIT_CASE="true"
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
    echo "E3SM Case Creation Script"
    echo "========================="
    echo ""
    
    # Detect and validate
    detect_e3sm_root
    detect_machine
    get_git_hash
    generate_case_name
    
    # Set case directory
    if [ -n "$CASE_DIR_ARG" ]; then
        CASE_DIR="$CASE_DIR_ARG/$CASE_NAME"
    else
        CASE_DIR="$E3SM_ROOT/cime/scripts/$CASE_NAME"
    fi
    
    validate_settings
    
    echo ""
    read -p "Continue with case creation? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        print_info "Aborted by user"
        exit 0
    fi
    
    # Execute workflow
    create_case
    configure_case
    build_case
    submit_case
    
    # Show summary
    show_summary
}

main "$@"
