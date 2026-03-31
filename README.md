# E3SM on macOS: Complete Developer Guide

<div align="center">

**Comprehensive guide for building and running E3SM climate model on macOS laptops**

[Getting Started](#getting-started) • [Documentation](#documentation) • [Quick Reference](#quick-reference) • [Troubleshooting](#troubleshooting)

</div>

---

## Overview

This guide enables developers to build, configure, and run the **Energy Exascale Earth System Model (E3SM)** on macOS using GCC 11. Based on real-world experience with:

- **Hardware:** Apple Silicon (M-series) and Intel Macs
- **OS:** macOS 12+ (Monterey and later)
- **Compiler:** GCC 11 (via Homebrew)
- **MPI:** OpenMPI 5.0.6 (custom build)

### Why This Guide?

E3SM is typically run on HPC clusters. Getting it to work on macOS requires:
- Manual library installation (no pre-built packages)
- Custom CIME configuration (macOS not officially supported)
- Compiler workarounds (IEEE arithmetic, line length limits)
- Environment setup (SDK paths, library paths)

This guide documents all known issues and solutions.

## What You'll Learn

- ✅ Install all required scientific computing libraries from source
- ✅ Configure CIME to recognize your Mac as a supported system
- ✅ Successfully compile E3SM with GCC 11 on macOS
- ✅ Download and manage large input datasets
- ✅ Run climate model simulations on your laptop
- ✅ Troubleshoot common build and runtime errors

## Getting Started

### Prerequisites

- **macOS 12+** with Xcode Command Line Tools installed
- **Homebrew** package manager
- **10-20 GB** free disk space (more for input data)
- **8+ CPU cores** recommended
- **16+ GB RAM** recommended
- **Internet connection** for downloading packages and data

### Quick Install Check

```bash
# Check Xcode Command Line Tools
xcode-select -p
# Should output: /Library/Developer/CommandLineTools

# Check Homebrew
brew --version
# Should output: Homebrew 5.1.2

# If missing, install:

xcode-select --install
# https://brew.sh/
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Time Estimates

| Step | Time Required |
|------|---------------|
| Package installation | 30-60 minutes |
| CIME configuration | 15-30 minutes |
| First case build | 5-15 minutes |
| Input data download | 10-120 minutes (varies by resolution) |
| First run (1x1 land, 5 days) | 1-5 minutes |

**Total:** ~2-4 hours for complete setup

## Documentation

This guide is organized into five sequential sections:

### 📜 Automation Scripts

Three scripts are provided to streamline the setup process:

- **[`scripts/install_e3sm_libs.sh`](scripts/install_e3sm_libs.sh)** - Automates package compilation (see section 1)
- **[`scripts/setup_cime_config.sh`](scripts/setup_cime_config.sh)** - Generates CIME configuration files (see section 2)
- **[`scripts/brazil.sh`](scripts/brazil.sh)** - Creates and configures E3SM cases (see section 3)

All scripts support `--help` for detailed usage information and can be run from any directory.

### 1. [Package Installation](01-package-installation.md) 📦

Install all required libraries from source.

**What you'll install:**
- GCC 11 (Fortran compiler)
- OpenMPI 5.0.6 (parallel computing)
- HDF5 1.14.5 (data format)
- NetCDF-C 4.9.3 (climate data format)
- NetCDF-Fortran 4.6.2
- PNetCDF 1.12.3 (parallel NetCDF, classic format)
- *(Optional)* MOAB (mesh-oriented database for unstructured meshes)
  - Eigen3, GKlib, METIS, ParMETIS (MOAB dependencies)
  - TempestRemap, Zoltan (downloaded automatically by MOAB build)

**Time:** 30-60 minutes (longer if building MOAB)

**Start here:** [01-package-installation.md](01-package-installation.md)

### 2. [CIME Configuration](02-cime-configuration.md) ⚙️

Configure E3SM's build system to recognize your Mac.

**What you'll create:**
- Machine definition (`~/.cime/config_machines.xml`)
- Compiler settings (`~/.cime/config_compilers.xml`)
- CMake macros with all required compiler flags
- Source code modification for IEEE arithmetic

**Time:** 15-30 minutes

**Continue:** [02-cime-configuration.md](02-cime-configuration.md)

### 3. [Case Creation and Building](03-case-creation-and-build.md) 🔨

Create and compile E3SM cases.

**What you'll learn:**
- Create single-point and regional cases
- Configure model components and resolution
- Build successfully with GCC 11
- Troubleshoot common build errors

**Time:** 5-15 minutes per case

**Continue:** [03-case-creation-and-build.md](03-case-creation-and-build.md)

### 4. [Input Data Management](04-input-data.md) 💾

Download and manage model input datasets.

**What you'll learn:**
- Automatic data download
- Manual data management
- Storage optimization
- Data requirements by configuration

**Time:** 10-120 minutes (depends on configuration)

**Continue:** [04-input-data.md](04-input-data.md)

### 5. [Running Cases](05-running-cases.md) 🚀

Submit, monitor, and analyze model runs.

**What you'll learn:**
- Submit and monitor runs
- Analyze performance and output
- Handle restarts and continuations
- Optimize for laptop hardware

**Time:** Varies by simulation length

**Continue:** [05-running-cases.md](05-running-cases.md)

## Quick Reference

### Essential Environment Variables

Add these to your `~/.zshrc`:

```bash
# Installation prefix
export INSTALL_PREFIX=$HOME/local/gcc11

# macOS SDK (CRITICAL for linking)
export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk
export LIBRARY_PATH=$SDKROOT/usr/lib:$LIBRARY_PATH

# PATH must have gcc11 FIRST (before Homebrew)
export PATH=$INSTALL_PREFIX/bin:$PATH
export LD_LIBRARY_PATH=$INSTALL_PREFIX/lib:$LD_LIBRARY_PATH
export DYLD_LIBRARY_PATH=$INSTALL_PREFIX/lib:$DYLD_LIBRARY_PATH

# NetCDF paths for CIME
export NETCDF_PATH=$INSTALL_PREFIX
export NETCDF_C_PATH=$INSTALL_PREFIX
export NETCDF_FORTRAN_PATH=$INSTALL_PREFIX
```

### Common Commands

```bash
# Create a case
cd $E3SM_ROOT/cime/scripts
./create_newcase --case ~/cases/my_case --compset I1850ELM \
  --res 1x1_brazil --machine YOUR_MACHINE --compiler gnu11 --run-unsupported

# Setup, build, and run
cd ~/cases/my_case
./case.setup
./check_input_data --download
./case.build
./case.submit

# Monitor progress
tail -f ~/scratch/my_case/run/cpl.log.*

# Check status
cat CaseStatus
```

### Directory Structure

```
$HOME/
├── local/gcc11/          # All installed libraries
│   ├── bin/              # Compilers and tools
│   ├── lib/              # Libraries
│   └── include/          # Headers
├── projects/e3sm/
│   ├── e3sm/             # E3SM source code (git clone)
│   ├── cases/            # Case directories
│   ├── scratch/          # Build and run directories
│   ├── inputdata/        # Model input datasets
│   └── baselines/        # Test baselines
└── .cime/                # CIME configuration
    ├── config_machines.xml
    ├── config_compilers.xml
    └── cmake_macros/
        └── gnu11_MACHINE.cmake
```

## Troubleshooting

### Build Issues

<details>
<summary><b>Library not found for -lSystem</b></summary>

**Cause:** `SDKROOT` not set

**Solution:**
```bash
export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk
echo 'export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk' >> ~/.zshrc
```
</details>

<details>
<summary><b>MPI module version mismatch</b></summary>

**Cause:** Homebrew's OpenMPI modules built with different GCC version

**Solution:**
```bash
# Ensure your gcc11/bin is FIRST in PATH
export PATH=$HOME/local/gcc11/bin:$PATH

# Or temporarily rename Homebrew's mpi.mod
sudo mv /opt/homebrew/include/mpi.mod /opt/homebrew/include/mpi.mod.bak
```
</details>

<details>
<summary><b>IEEE arithmetic errors</b></summary>

**Cause:** GCC 11 on macOS has incomplete IEEE arithmetic support

**Solution:** Already covered in [02-cime-configuration.md](02-cime-configuration.md), Step 4:
- Add `-DNO_IEEE_ARITHMETIC` flag in CMake macros
- Modify `shr_infnan_mod.F90.in` with conditional wrapper
</details>

<details>
<summary><b>Line truncation errors</b></summary>

**Cause:** Fortran source has lines longer than default limit

**Solution:** Add `-ffree-line-length-none` to CMake macros (already in guide)
</details>

<details>
<summary><b>Cannot find NetCDF</b></summary>

**Cause:** NetCDF environment variables not set

**Solution:**
```bash
export NETCDF_PATH=$HOME/local/gcc11
export NETCDF_C_PATH=$HOME/local/gcc11
export NETCDF_FORTRAN_PATH=$HOME/local/gcc11
```
</details>

### Runtime Issues

<details>
<summary><b>Run crashes immediately</b></summary>

**Check:**
```bash
# Verify input data
./check_input_data --check

# Check for errors
grep -i error ~/scratch/CASE/run/cpl.log.*
```
</details>

<details>
<summary><b>Run too slow</b></summary>

**Solutions:**
- Use single-point or coarser resolution
- Disable debug mode: `./xmlchange DEBUG=FALSE`
- Reduce output frequency
- Increase NTASKS to use more cores
</details>

### Getting Help

1. **Check the guides** - Most issues are documented
2. **Check logs** - Build logs and run logs contain error details
3. **E3SM forum** - https://e3sm.org/support/
4. **GitHub discussions** - https://github.com/E3SM-Project/E3SM/discussions

## Use Cases

### Laptop Development Workflows

#### Code Development
```bash
# 1. Make code changes
vim $E3SM_ROOT/components/elm/src/biogeophys/CanopyFluxesMod.F90

# 2. Copy to SourceMods (optional, for case-specific changes)
cp modified_file.F90 ~/cases/my_case/SourceMods/src.elm/

# 3. Rebuild only modified component
cd ~/cases/my_case
./case.build

# 4. Test quickly with short run
./xmlchange STOP_N=1,STOP_OPTION=ndays
./case.submit
```

#### Scientific Testing
```bash
# Create control case
./create_newcase --case control --compset I2000ELM --res 1x1_brazil ...

# Create experiment case
./create_newcase --case experiment --compset I2000ELM --res 1x1_brazil ...

# Modify experiment (e.g., change parameter)
cd experiment
cat >> user_nl_elm << EOF
my_parameter = 1.5
EOF

# Run both and compare
cd control && ./case.submit
cd ../experiment && ./case.submit
```

#### Learning E3SM
```bash
# Start with simplest configuration
--compset I1850ELM --res 1x1_brazil

# Graduate to regional
--compset I2000ELM --res 1x1_mexicocityMEX

# Then atmospheric
--compset F2010 --res ne4_oQU240

# Finally coupled (if your laptop can handle it)
--compset WCYCL1850 --res ne4_oQU240
```

## Recommended Configurations for Laptops

| Configuration | Resolution | Compset | Cores | Runtime (5 sim-days) | Input Data |
|---------------|-----------|---------|-------|---------------------|------------|
| **Single-point land** | 1x1_brazil | I1850ELM | 1-2 | 1-5 min | ~1 GB |
| **Regional land** | 1x1_urbanc_alpha | I2000ELM | 2-4 | 5-15 min | ~2 GB |
| **Low-res atmosphere** | ne4_oQU240 | F2010 | 4-8 | 30-60 min | ~10 GB |
| **Coupled (not recommended)** | ne4_oQU240 | WCYCL1850 | 8+ | hours | ~50 GB |

**Recommendation:** Start with single-point land configuration for fastest iteration.

## Performance Tips

1. **Use single-point or regional grids** - 10-100x faster than global
2. **Disable debug builds** - `./xmlchange DEBUG=FALSE`
3. **Optimize task layout** - Experiment with NTASKS/NTHRDS
4. **Reduce history output** - Only write variables you need
5. **Use SSD** - Put scratch and inputdata on SSD, not external drive
6. **Close applications** - Free up RAM and CPU for E3SM

## Known Limitations

- **No batch system support** - Runs are interactive or background only
- **Performance** - ~10-100x slower than HPC clusters
- **Resolution limits** - Global high-resolution not practical
- **Memory constraints** - 16GB RAM limits configuration size
- **Coupled models slow** - Ocean/ice components are compute-intensive

## Staying Updated

### Update E3SM

```bash
cd $E3SM_ROOT
git fetch origin
git checkout main
git pull

# May need to rebuild cases
cd ~/cases/my_case
./case.build --clean-all
./case.build
```

### Update Libraries

Check for new versions periodically:
- OpenMPI: https://www.open-mpi.org/
- HDF5: https://www.hdfgroup.org/downloads/hdf5/
- NetCDF: https://www.unidata.ucar.edu/downloads/netcdf/

Rebuild with new versions:
```bash
# Rebuild libraries
cd ~/packages
# ... download new versions ...
# ... rebuild following installation guide ...

# Rebuild E3SM cases
cd ~/cases/my_case
./case.build --clean-all
./case.build
```

## Contributing

Found a bug or have improvements?

1. Test your changes thoroughly
2. Document the issue and solution
3. Share on E3SM forum or GitHub
4. Update this guide with new findings

## Additional Resources

### E3SM Project
- **Website:** https://e3sm.org/
- **GitHub:** https://github.com/E3SM-Project/E3SM
- **Documentation:** https://docs.e3sm.org/
- **Forum:** https://e3sm.org/support/

### CIME Documentation
- **User Guide:** https://esmci.github.io/cime/
- **Developer Guide:** https://esmci.github.io/cime/developers_guide/index.html

### Scientific Computing Tools
- **NCO:** http://nco.sourceforge.net/
- **CDO:** https://code.mpimet.mpg.de/projects/cdo
- **NCL:** https://www.ncl.ucar.edu/
- **Python xarray:** http://xarray.pydata.org/

## Acknowledgments

This guide was developed through practical experience building E3SM on macOS. Special thanks to:
- The E3SM development team
- CIME developers at NCAR
- The open-source scientific computing community

## License

This documentation is provided as-is for the benefit of the E3SM community. Use and modify freely.

---

<div align="center">

**Questions?** Check the individual guides or reach out to the E3SM community.

**Good luck with your climate modeling!** 🌍🔬

</div>
