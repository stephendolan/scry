#!/bin/bash
# Integration test for arrow key navigation
# Tests that arrow keys correctly move the cursor.

set -e

TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

mkdir -p "$TEST_DIR/2024-01-01-alpha"
mkdir -p "$TEST_DIR/2024-01-02-beta"

cat > "$TEST_DIR/test.exp" << 'EOF'
log_user 1
set timeout 3
set test_dir [lindex $argv 0]

spawn env SCRY_PATH=$test_dir ./bin/scry cd

# Wait for initial render
expect {
    -re {alpha|beta} { }
    timeout { puts "\nFAIL: items not shown"; exit 1 }
}

# Record initial state - cursor should be on first item
sleep 0.2

# Send down arrow (ESC [ B) to move to second item
send "\033\[B"
sleep 0.2

# Send down arrow again to move to Create new
send "\033\[B"
sleep 0.2

# Send up arrow (ESC [ A) to move back
send "\033\[A"
sleep 0.2

# Press enter to select
send "\r"

expect {
    eof { }
    timeout { puts "\nFAIL: did not exit"; exit 1 }
}
EOF

# Capture full output including stderr
output=$(expect "$TEST_DIR/test.exp" "$TEST_DIR" 2>&1)

# Verify correct directory selected (down, down, up = second item = alpha)
if echo "$output" | grep -q "cd '.*alpha"; then
    echo "Arrow key integration test passed"
    exit 0
fi

# Check for explicit failures
if echo "$output" | grep -q "FAIL:"; then
    echo "FAILED: $(echo "$output" | grep "FAIL:")"
    exit 1
fi

# If we got here, something unexpected happened
echo "FAILED: no cd command in output"
echo "Output was:"
echo "$output" | tail -10
exit 1
