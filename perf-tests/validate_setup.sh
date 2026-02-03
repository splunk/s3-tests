#!/bin/bash
# validate_setup.sh - Quick validation of benchmarking framework setup

set -e

echo "========================================="
echo "S3 Benchmarking Framework Setup Validator"
echo "========================================="
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

check_command() {
    local cmd=$1
    local install_hint=$2
    
    if command -v "$cmd" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $cmd is installed ($(command -v $cmd))"
        return 0
    else
        echo -e "${RED}✗${NC} $cmd is NOT installed"
        echo "  Install: $install_hint"
        ERRORS=$((ERRORS + 1))
        return 1
    fi
}

check_python_package() {
    local package=$1
    
    if python3 -c "import $package" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Python package '$package' is installed"
        return 0
    else
        echo -e "${RED}✗${NC} Python package '$package' is NOT installed"
        ERRORS=$((ERRORS + 1))
        return 1
    fi
}

check_file() {
    local file=$1
    local type=$2
    
    if [[ -f "$file" ]]; then
        echo -e "${GREEN}✓${NC} $type exists: $file"
        return 0
    else
        echo -e "${RED}✗${NC} $type NOT found: $file"
        ERRORS=$((ERRORS + 1))
        return 1
    fi
}

check_config() {
    local file=$1
    local required_vars=("$@")
    
    if [[ ! -f "$file" ]]; then
        echo -e "${RED}✗${NC} Configuration file not found: $file"
        ERRORS=$((ERRORS + 1))
        return 1
    fi
    
    source "$file"
    
    local missing=0
    for var in "${required_vars[@]:1}"; do
        if [[ -z "${!var}" ]] || [[ "${!var}" == *"YOUR_"* ]]; then
            echo -e "${YELLOW}⚠${NC} Variable '$var' not configured in $file"
            WARNINGS=$((WARNINGS + 1))
            missing=1
        fi
    done
    
    if [[ $missing -eq 0 ]]; then
        echo -e "${GREEN}✓${NC} Configuration complete: $file"
        return 0
    else
        echo -e "${YELLOW}⚠${NC} Configuration incomplete: $file"
        return 1
    fi
}

echo "1. Checking required commands..."
echo "-----------------------------------"
check_command "warp" "brew install minio/stable/warp (macOS) or download from github.com/minio/warp"
check_command "jq" "brew install jq (macOS) or apt-get install jq (Linux)"
check_command "python3" "Install Python 3.7+ from python.org"
echo ""

echo "2. Checking Python packages..."
echo "-----------------------------------"
check_python_package "pandas"
check_python_package "matplotlib"
check_python_package "seaborn"
check_python_package "jinja2"
echo ""

if [[ $ERRORS -gt 0 ]]; then
    echo -e "${RED}Missing Python packages detected.${NC}"
    echo "Install with: pip3 install pandas matplotlib seaborn jinja2"
    echo ""
fi

echo "3. Checking framework files..."
echo "-----------------------------------"
check_file "warp_s3_benchmark.sh" "Main benchmark script"
check_file "report.py" "Report generation script"
check_file "BENCHMARKING.md" "Documentation"
check_file "QUICKSTART.md" "Quick start guide"
echo ""

echo "4. Checking configuration files..."
echo "-----------------------------------"
if [[ -f "targets/aws.env" ]]; then
    check_config "targets/aws.env" S3_ENDPOINT S3_ACCESS_KEY S3_SECRET_KEY S3_BUCKET S3_REGION
else
    echo -e "${YELLOW}⚠${NC} targets/aws.env not found (optional)"
    WARNINGS=$((WARNINGS + 1))
fi

if [[ -f "targets/other.env" ]]; then
    check_config "targets/other.env" S3_ENDPOINT S3_ACCESS_KEY S3_SECRET_KEY S3_BUCKET
else
    echo -e "${YELLOW}⚠${NC} targets/other.env not found (optional)"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

echo "5. Checking script permissions..."
echo "-----------------------------------"
if [[ -x "warp_s3_benchmark.sh" ]]; then
    echo -e "${GREEN}✓${NC} warp_s3_benchmark.sh is executable"
else
    echo -e "${YELLOW}⚠${NC} warp_s3_benchmark.sh is not executable"
    echo "  Fix with: chmod +x warp_s3_benchmark.sh"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

echo "========================================="
echo "Summary"
echo "========================================="

if [[ $ERRORS -eq 0 ]] && [[ $WARNINGS -eq 0 ]]; then
    echo -e "${GREEN}✓ All checks passed! You're ready to run benchmarks.${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Review QUICKSTART.md for usage examples"
    echo "  2. Configure targets/aws.env and targets/other.env"
    echo "  3. Create S3 buckets if they don't exist"
    echo "  4. Run: ./warp_s3_benchmark.sh --target aws"
    exit 0
elif [[ $ERRORS -eq 0 ]]; then
    echo -e "${YELLOW}⚠ Setup incomplete: $WARNINGS warning(s)${NC}"
    echo ""
    echo "You can run benchmarks, but:"
    echo "  - Review and configure target files (targets/*.env)"
    echo "  - Replace placeholder values (YOUR_*) with real credentials"
    echo ""
    echo "See QUICKSTART.md for configuration help."
    exit 0
else
    echo -e "${RED}✗ Setup failed: $ERRORS error(s), $WARNINGS warning(s)${NC}"
    echo ""
    echo "Please install missing dependencies:"
    echo "  - See QUICKSTART.md for installation instructions"
    echo "  - Or run: brew install minio/stable/warp jq (macOS)"
    echo "  - Python packages: pip3 install pandas matplotlib seaborn jinja2"
    exit 1
fi
