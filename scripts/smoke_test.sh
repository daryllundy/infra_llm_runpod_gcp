#!/usr/bin/env bash
# Usage: ./smoke_test.sh <POD_IP> [API_KEY]
set -e

# Function to display usage
usage() {
    echo "Usage: $0 <POD_IP> [API_KEY]"
    echo "  POD_IP: IP address of the LLM service"
    echo "  API_KEY: Optional API key (defaults to 'your-secret-api-key')"
    echo ""
    echo "Example: $0 192.168.1.100"
    echo "Example: $0 192.168.1.100 my-custom-api-key"
    exit 1
}

# Validate input parameters
if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    echo "Error: Invalid number of arguments"
    usage
fi

POD_IP=$1
API_KEY=${2:-"your-secret-api-key"}

# Validate IP address format
if ! [[ $POD_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    echo "Error: Invalid IP address format: $POD_IP"
    echo "Please provide a valid IPv4 address (e.g., 192.168.1.100)"
    exit 1
fi

# Check if curl is available
if ! command -v curl &> /dev/null; then
    echo "Error: curl is not installed or not in PATH"
    echo "Please install curl to run this smoke test"
    exit 1
fi

echo "Starting smoke test for LLM service at $POD_IP:8000"
echo "Using API key: ${API_KEY:0:10}..."

# Test the service with error handling
echo "Sending test request..."
if response=$(curl -s -w "\n%{http_code}" \
    http://$POD_IP:8000/v1/chat/completions \
    -H "Authorization: Bearer $API_KEY" \
    -H 'Content-Type: application/json' \
    -d '{ "model": "meta-llama/Llama-3-8B-Instruct.Q4_K_M.gguf", "messages":[{"role":"user","content":"Hello"}] }' \
    2>/dev/null); then

    # Extract HTTP status code and response body
    http_code=$(echo "$response" | tail -n1)
    response_body=$(echo "$response" | head -n -1)

    echo "HTTP Status Code: $http_code"

    if [ "$http_code" -eq 200 ]; then
        echo "✅ SUCCESS: LLM service is responding correctly"
        echo "Response: $response_body"
    elif [ "$http_code" -eq 401 ]; then
        echo "❌ FAILED: Authentication failed (HTTP 401)"
        echo "Please check your API key"
        exit 1
    elif [ "$http_code" -eq 404 ]; then
        echo "❌ FAILED: Endpoint not found (HTTP 404)"
        echo "Service may not be running or endpoint is incorrect"
        exit 1
    else
        echo "❌ FAILED: Unexpected HTTP status code: $http_code"
        echo "Response: $response_body"
        exit 1
    fi
else
    echo "❌ FAILED: Could not connect to service at $POD_IP:8000"
    echo "Please check:"
    echo "  - Service is running"
    echo "  - IP address is correct"
    echo "  - Port 8000 is accessible"
    echo "  - Firewall allows connections"
    exit 1
fi

echo "✅ Smoke test completed successfully!"
