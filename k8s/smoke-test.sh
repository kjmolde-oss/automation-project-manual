#!/bin/bash
BASE_URL=$1

echo "🧪 Starting smoke test on ${BASE_URL}..."

# Test 1: Check the Home Page
echo "Checking / ..."
curl --fail --connect-timeout 10 "${BASE_URL}/"

# Test 2: Check the /login Page
echo "Checking /login ..."
curl --fail --connect-timeout 10 "${BASE_URL}/login"

# Test 3: Check a specific API endpoint
echo "Checking /api/health ..."
curl --fail --connect-timeout 10 "${BASE_URL}/api/health"

echo "✅ All smoke tests passed!"