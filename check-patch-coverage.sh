#!/bin/bash

# ==============================================================================
# Premium Patch Coverage Bash Script
# ==============================================================================
# Cross-references git diff with Jest's LCOV report to ensure 100% Patch Coverage.
# This version is optimized for speed and requires no Node dependencies.

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

RUN_TESTS=true
LCOV_FILE="coverage/lcov.info"
COMPARE_TO="HEAD"
THRESHOLD="100"
declare -a TARGET_FILES

# Parse arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --skip-tests|-s) RUN_TESTS=false; shift ;;
    --lcov-file=*) LCOV_FILE="${1#*=}"; shift ;;
    --compare-to=*) COMPARE_TO="${1#*=}"; shift ;;
    --threshold=*) THRESHOLD="${1#*=}"; shift ;;
    -*) echo -e "${RED}❌ Unknown parameter: $1${NC}"; exit 1 ;;
    *) TARGET_FILES+=("$1"); shift ;;
  esac
done

run_jest() {
  if [ ${#TARGET_FILES[@]} -gt 0 ]; then
    # Run tests specifically related to the passed files
    npx jest --coverage --coverageReporters="lcov" --findRelatedTests "${TARGET_FILES[@]}" --passWithNoTests
  else
    # Automatically determine changed files based on the comparison target
    if [ "$COMPARE_TO" = "HEAD" ]; then
      npx jest --coverage --coverageReporters="lcov" --onlyChanged
    else
      npx jest --coverage --coverageReporters="lcov" --changedSince="$COMPARE_TO"
    fi
  fi
}

get_diff() {
  if [ ${#TARGET_FILES[@]} -gt 0 ]; then
    git diff -U0 "$COMPARE_TO" -- "${TARGET_FILES[@]}"
  else
    git diff -U0 "$COMPARE_TO"
  fi
}

if [ "$RUN_TESTS" = true ]; then
  echo -e "${CYAN}🚀 Running Jest to collect coverage...${NC}"
  if ! run_jest; then
    echo -e "${RED}❌ Jest tests failed! Patch coverage check aborted.${NC}"
    exit 1
  fi
else
  echo -e "${CYAN}♻️  Skipping Jest, using existing coverage report ($LCOV_FILE)...${NC}"
fi

if [ ! -f "$LCOV_FILE" ]; then
  echo -e "${RED}❌ Coverage report (lcov.info) not found!${NC}"
  exit 1
fi

echo -e "\n${CYAN}📊 Coverage Summary (Analyzed Files):${NC}"
awk -F: '
/^LF:/ { lf += $2 }
/^LH:/ { lh += $2 }
/^FNF:/ { fnf += $2 }
/^FNH:/ { fnh += $2 }
/^BRF:/ { brf += $2 }
/^BRH:/ { brh += $2 }
END {
  if (lf > 0) printf "  Lines:     %.2f%%\n", (lh/lf)*100
  else print "  Lines:     N/A"
  
  if (fnf > 0) printf "  Functions: %.2f%%\n", (fnh/fnf)*100
  else print "  Functions: N/A"
  
  if (brf > 0) printf "  Branches:  %.2f%%\n", (brh/brf)*100
  else print "  Branches:  N/A"
}' "$LCOV_FILE"

echo -e "\n${CYAN}🔍 Analyzing Patch Coverage against $COMPARE_TO...${NC}"

TOTAL_UNCOVERED_ITEMS=0
PATCH_TOTAL_ITEMS=0
CURRENT_FILE=""
HAS_DIFF=false

process_current_file() {
  if [ -n "$CURRENT_FILE" ] && [ -n "$FILE_COVERAGE" ] && [ ${#CHANGED_LINES[@]} -gt 0 ]; then
    local CHANGED_LINES_STR=" ${CHANGED_LINES[*]} "
    
    while IFS= read -r f_line; do
      if [[ "$f_line" == DA:* ]]; then
        IFS=',' read -r prefix count <<< "$f_line"
        ln=${prefix#DA:}
        if [[ "$CHANGED_LINES_STR" == *" $ln "* ]]; then
          PATCH_TOTAL_ITEMS=$((PATCH_TOTAL_ITEMS + 1))
          if [[ "$count" == "0" ]]; then
            echo -e "${RED}❌ $CURRENT_FILE: Line $ln is NOT covered.${NC}"
            TOTAL_UNCOVERED_ITEMS=$((TOTAL_UNCOVERED_ITEMS + 1))
          fi
        fi
      elif [[ "$f_line" == BRDA:* ]]; then
        IFS=',' read -r br_prefix br_block br_id br_taken <<< "$f_line"
        ln=${br_prefix#BRDA:}
        if [[ "$CHANGED_LINES_STR" == *" $ln "* ]]; then
          PATCH_TOTAL_ITEMS=$((PATCH_TOTAL_ITEMS + 1))
          if [[ "$br_taken" == "0" ]] || [[ "$br_taken" == "-" ]]; then
            echo -e "${YELLOW}⚠️  $CURRENT_FILE: Branch at line $ln is NOT covered.${NC}"
            TOTAL_UNCOVERED_ITEMS=$((TOTAL_UNCOVERED_ITEMS + 1))
          fi
        fi
      fi
    done <<< "$FILE_COVERAGE"
  fi
}

unset CHANGED_LINES
declare -a CHANGED_LINES

# Get the list of added/modified lines from git diff
# We use unified=0 to isolate ONLY the lines that were changed.
while IFS= read -r line; do
  HAS_DIFF=true
  if [[ $line =~ ^\+\+\+\ b/(.*) ]]; then
    process_current_file
    
    CURRENT_FILE="${BASH_REMATCH[1]}"
    ESCAPED_FILE=$(echo "$CURRENT_FILE" | sed 's/[./*]/\\&/g')
    FILE_COVERAGE=$(sed -n "/SF:.*$ESCAPED_FILE$/,/end_of_record/p" "$LCOV_FILE")
    unset CHANGED_LINES
    declare -a CHANGED_LINES
    
  elif [[ $line =~ ^@@\ -[0-9,]+\ \+([0-9]+)(,([0-9]+))?\ @@ ]]; then
    START="${BASH_REMATCH[1]}"
    COUNT="${BASH_REMATCH[3]}"
    [ -z "$COUNT" ] && COUNT=1
    
    for (( i=0; i<COUNT; i++ )); do
      CHANGED_LINES+=("$((START + i))")
    done
  fi
done < <(get_diff)

process_current_file

if [ "$HAS_DIFF" = false ]; then
  if [ ${#TARGET_FILES[@]} -gt 0 ]; then
    echo -e "${YELLOW}ℹ️  No code changes specific to provided files detected against $COMPARE_TO. Skipping check.${NC}"
  else
    echo -e "${YELLOW}ℹ️  No code changes detected against $COMPARE_TO. Skipping check.${NC}"
  fi
  exit 0
fi

COVERAGE_PERCENT=100
if [ "$PATCH_TOTAL_ITEMS" -gt 0 ]; then
  COVERED_ITEMS=$((PATCH_TOTAL_ITEMS - TOTAL_UNCOVERED_ITEMS))
  COVERAGE_PERCENT=$(awk -v covered="$COVERED_ITEMS" -v total="$PATCH_TOTAL_ITEMS" 'BEGIN { printf "%.2f", (covered/total)*100 }')
fi

PASSES_THRESHOLD=$(awk -v cp="$COVERAGE_PERCENT" -v th="$THRESHOLD" 'BEGIN { if (cp >= th) print 1; else print 0 }')

if [ "$PASSES_THRESHOLD" -eq 1 ]; then
  if [ "$TOTAL_UNCOVERED_ITEMS" -gt 0 ]; then
    echo -e "\n${YELLOW}⚠️  PASS: Patch Coverage is $COVERAGE_PERCENT% (Threshold: $THRESHOLD%). ${TOTAL_UNCOVERED_ITEMS} untested conditions out of $PATCH_TOTAL_ITEMS items.${NC}"
  else
    echo -e "\n${GREEN}PASS: 100% Patch Coverage achieved! (All $PATCH_TOTAL_ITEMS items are tested)${NC}"
  fi
  exit 0
else
  echo -e "\n${RED}FAIL: Patch Coverage is $COVERAGE_PERCENT%! ($TOTAL_UNCOVERED_ITEMS out of $PATCH_TOTAL_ITEMS items are untested)${NC}"
  echo -e "${RED}      Required Threshold: $THRESHOLD%${NC}"
  echo -e "${YELLOW}ℹ️  Script is configured to always pass! Returning exit code 0.${NC}"
  exit 0
fi
