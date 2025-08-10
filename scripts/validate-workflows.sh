#!/bin/bash
# Script to validate GitHub Actions workflows
# Usage: ./validate-workflows.sh

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Validating GitHub Actions workflows...${NC}"

# Check if actionlint is installed
if ! command -v actionlint &> /dev/null
then
    echo -e "${YELLOW}actionlint not found. Installing...${NC}"
    # Install actionlint
    go install github.com/rhysd/actionlint/cmd/actionlint@latest
fi

# Directory containing workflow files
WORKFLOWS_DIR=".github/workflows"

# Check if workflows directory exists
if [ ! -d "$WORKFLOWS_DIR" ]; then
    echo -e "${RED}Workflows directory not found: $WORKFLOWS_DIR${NC}"
    exit 1
fi

# Count total workflows
TOTAL_WORKFLOWS=$(find "$WORKFLOWS_DIR" -name "*.yml" | wc -l)
echo -e "${YELLOW}Found $TOTAL_WORKFLOWS workflow files to validate${NC}"

# Validate each workflow file
VALID_COUNT=0
INVALID_COUNT=0
INVALID_FILES=""

for workflow in $(find "$WORKFLOWS_DIR" -name "*.yml"); do
    echo -e "${YELLOW}Validating $workflow...${NC}"
    
    # Run actionlint on the workflow file
    if actionlint "$workflow"; then
        echo -e "${GREEN}✓ $workflow is valid${NC}"
        VALID_COUNT=$((VALID_COUNT + 1))
    else
        echo -e "${RED}✗ $workflow has errors${NC}"
        INVALID_COUNT=$((INVALID_COUNT + 1))
        INVALID_FILES="$INVALID_FILES\n- $workflow"
    fi
    echo "----------------------------------------"
done

# Test a dry run of act if available
if command -v act &> /dev/null; then
    echo -e "${YELLOW}Testing workflows with act (dry run)...${NC}"
    act -n
else
    echo -e "${YELLOW}act not installed. Consider installing it to test workflows locally:${NC}"
    echo -e "${YELLOW}https://github.com/nektos/act${NC}"
fi

# Print summary
echo -e "${YELLOW}Validation Summary:${NC}"
echo -e "${GREEN}Valid workflows: $VALID_COUNT${NC}"
if [ $INVALID_COUNT -gt 0 ]; then
    echo -e "${RED}Invalid workflows: $INVALID_COUNT${NC}"
    echo -e "${RED}Invalid files:$INVALID_FILES${NC}"
    echo -e "${YELLOW}Please fix the errors in the above files.${NC}"
    exit 1
else
    echo -e "${GREEN}All workflows are valid!${NC}"
fi

echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. Push changes to trigger CI pipeline"
echo -e "2. Check workflow execution in GitHub Actions tab"
echo -e "3. For manual testing, use workflow_dispatch triggers"
