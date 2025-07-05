# This is free and unencumbered software released into the public domain.
# For more details, see the LICENSE file in the project root.

import subprocess
import time
import os

# Define the path to the luaenv PowerShell script
USER_PROFILE = os.environ.get('USERPROFILE')
LUAENV_SCRIPT = os.path.join(USER_PROFILE, '.luaenv', 'bin', 'luaenv.ps1')

# Global test cases configuration
TEST_CASES = [
    {
        "name": "Default installation with alias",
        "alias": "test_default",
        "install_command": "install --alias test_default",
        "uninstall_command": "uninstall test_default --yes"
    },
    {
        "name": "Specific Lua version",
        "alias": "test_lua546",
        "install_command": "install --lua-version 5.4.6 --alias test_lua546",
        "uninstall_command": "uninstall test_lua546 --yes"
    },
    {
        "name": "DLL build",
        "alias": "test_dll",
        "install_command": "install --dll --alias test_dll",
        "uninstall_command": "uninstall test_dll --yes"
    },
    {
        "name": "Debug build",
        "alias": "test_debug",
        "install_command": "install --debug --alias test_debug",
        "uninstall_command": "uninstall test_debug --yes"
    },
    {
        "name": "DLL and Debug build",
        "alias": "test_dll_debug",
        "install_command": "install --dll --debug --alias test_dll_debug",
        "uninstall_command": "uninstall test_dll_debug --force" # Testing --force flag
    },
    {
        "name": "Custom display name",
        "alias": "test_name",
        "install_command": "install --name \"Test Custom Name\" --alias test_name",
        "uninstall_command": "uninstall test_name --yes"
    },
    {
        "name": "Skip tests",
        "alias": "test_skip_tests",
        "install_command": "install --skip-tests --alias test_skip_tests",
        "uninstall_command": "uninstall test_skip_tests --yes"
    }
]

def execute_command(command, **kwargs):
    try:
        result = subprocess.run(command, check=True, capture_output=True, text=True, **kwargs)
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        return f"Error: {e.stderr.strip()}"

def execute_luaenv_command(command, **kwargs):
    """
    Execute a luaenv command with the given arguments and return the output.
    Execute the luaenv.ps1 script through PowerShell
    """
    # Create PowerShell command to run luaenv.ps1 with the given arguments
    ps_command = f'& "{LUAENV_SCRIPT}" {command}'
    full_command = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", ps_command]
    return execute_command(full_command, **kwargs)

def verify_installation(alias):
    """
    Verify that an installation with the given alias exists.
    Returns True if the installation exists, False otherwise.
    """
    output = execute_luaenv_command("list")
    print(f"  Verification output: {output}")
    print(f"  Looking for alias: {alias}")
    exists = alias in output
    print(f"  Found in output: {exists}")
    return exists

def test_install():
    """
    Test the luaenv install command with different combinations of arguments.
    """
    print("\n=== TESTING INSTALL COMMAND ===\n")

    results = []

    # Run each test case
    for i, test_case in enumerate(TEST_CASES):
        print(f"Test {i+1}/{len(TEST_CASES)}: {test_case['name']}")
        print(f"  Command: luaenv {test_case['install_command']}")

        start_time = time.time()
        output = execute_luaenv_command(test_case['install_command'])
        end_time = time.time()

        print(f"  Command output: {output}")

        # Check if installation was successful
        print(f"  Waiting 3 seconds for installation to complete...")
        time.sleep(3)  # Give more time for async processes to complete
        success = verify_installation(test_case['alias'])

        # Record result
        result = {
            "test_name": test_case["name"],
            "command": test_case["install_command"],
            "success": success,
            "duration_seconds": round(end_time - start_time, 1)
        }
        results.append(result)

        # Print result
        status = "✅ PASS" if success else "❌ FAIL"
        print(f"  Result: {status} (took {result['duration_seconds']} seconds)")
        print()

    # Print summary
    print("\n=== INSTALL TEST SUMMARY ===")
    passes = sum(1 for r in results if r["success"])
    print(f"Tests passed: {passes}/{len(TEST_CASES)}")

    # Print failed tests if any
    failed_tests = [r for r in results if not r["success"]]
    if failed_tests:
        print("\nFailed tests:")
        for test in failed_tests:
            print(f"  - {test['test_name']}: luaenv {test['command']}")

    return results

def verify_uninstall(alias):
    """
    Verify that an installation with the given alias no longer exists.
    Returns True if the installation is gone, False if it still exists.
    """
    output = execute_luaenv_command("list")
    print(f"  Verification output: {output}")
    print(f"  Looking for alias: {alias}")

    # More detailed check
    lines = output.splitlines()
    for line in lines:
        print(f"  Checking line: '{line}'")
        # Look for the exact alias pattern, which should be format "alias: name)"
        # This prevents matching substrings like "test_dll" in "test_dll_debug"
        if f"(alias: {alias})" in line:
            print(f"  FOUND ALIAS in line: {line}")
            return False

    # Do NOT use direct string search as it can cause false positives
    # with substring matches (e.g., "test_dll" in "test_dll_debug")

    return True

def test_uninstall():
    """
    Test the luaenv uninstall command with different combinations of arguments.
    """
    print("\n=== TESTING UNINSTALL COMMAND ===\n")

    results = []

    # Run each test case
    for i, test_case in enumerate(TEST_CASES):
        uninstall_name = f"Uninstall {test_case['name']}"
        print(f"Test {i+1}/{len(TEST_CASES)}: {uninstall_name}")
        print(f"  Command: luaenv {test_case['uninstall_command']}")

        start_time = time.time()
        output = execute_luaenv_command(test_case['uninstall_command'])
        end_time = time.time()

        print(f"  Command output: {output}")

        # Special handling for DLL build - it seems to need more time
        wait_time = 15 if test_case['alias'] == 'test_dll' else 8
        print(f"  Waiting {wait_time} seconds for uninstallation to complete...")
        time.sleep(wait_time)  # Give more time for async processes to complete

        # Debug: run list command directly to see what's happening
        print(f"  Debug - Running list command directly:")
        list_output = execute_luaenv_command("list")
        print(f"  Debug - List command output: {list_output}")

        # Debug: explicitly look for the alias in the output
        print(f"  Debug - Explicitly checking if alias '{test_case['alias']}' is in list output")
        print(f"  Debug - Result: {test_case['alias'] in list_output}")

        # Run list command a second time - sometimes first one might be cached
        if test_case['alias'] == 'test_dll':
            print(f"  Debug - Running list command a second time for DLL build:")
            time.sleep(2)
            list_output = execute_luaenv_command("list")
            print(f"  Debug - Second list command output: {list_output}")
            print(f"  Debug - Second check: {test_case['alias'] in list_output}")

        success = verify_uninstall(test_case['alias'])

        # Record result
        result = {
            "test_name": uninstall_name,
            "command": test_case["uninstall_command"],
            "success": success,
            "duration_seconds": round(end_time - start_time, 1)
        }
        results.append(result)

        # Print result
        status = "✅ PASS" if success else "❌ FAIL"
        print(f"  Result: {status} (took {result['duration_seconds']} seconds)")
        print()

    # Print summary
    print("\n=== UNINSTALL TEST SUMMARY ===")
    passes = sum(1 for r in results if r["success"])
    print(f"Tests passed: {passes}/{len(TEST_CASES)}")

    # Print failed tests if any
    failed_tests = [r for r in results if not r["success"]]
    if failed_tests:
        print("\nFailed tests:")
        for test in failed_tests:
            print(f"  - {test['test_name']}: luaenv {test['command']}")

    return results

def test_specific_dll_build():
    """
    Run a focused test just for the DLL build to isolate the issue
    """
    print("\n=== TESTING SPECIFIC DLL BUILD ===\n")

    # Get the DLL build test case
    test_case = next((tc for tc in TEST_CASES if tc["alias"] == "test_dll"), None)
    if not test_case:
        print("Error: DLL build test case not found")
        return False

    print(f"Testing: {test_case['name']}")

    # Clean up any existing installation with this alias first
    print("Cleaning up any existing installation first...")
    execute_luaenv_command(test_case['uninstall_command'])
    time.sleep(3)

    # Install
    print(f"Running install command: luaenv {test_case['install_command']}")
    install_output = execute_luaenv_command(test_case['install_command'])
    print(f"Install output:\n{install_output}")

    time.sleep(3)

    # Verify installation
    list_output = execute_luaenv_command("list")
    print(f"List after install:\n{list_output}")
    install_success = test_case['alias'] in list_output
    print(f"Installation verified: {install_success}")

    if not install_success:
        print("Installation failed, skipping uninstall test")
        return False

    # Uninstall
    print(f"\nRunning uninstall command: luaenv {test_case['uninstall_command']}")
    uninstall_output = execute_luaenv_command(test_case['uninstall_command'])
    print(f"Uninstall output:\n{uninstall_output}")

    # Wait longer to make sure all processes complete
    print("Waiting 10 seconds for uninstall to complete...")
    time.sleep(10)

    # Verify uninstall
    list_output = execute_luaenv_command("list")
    print(f"List after uninstall:\n{list_output}")
    uninstall_success = test_case['alias'] not in list_output
    print(f"Uninstall verified: {uninstall_success}")

    return uninstall_success

if __name__ == "__main__":
    # Command line argument handling
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "test_dll_only":
        # Run only the DLL test
        print("\n=== RUNNING ISOLATED DLL BUILD TEST ONLY ===\n")
        test_specific_dll_build()
        sys.exit(0)

    # Run the install tests
    install_results = test_install()

    # List all installations to verify
    print("\nVerifying all installations:")
    list_output = execute_luaenv_command("list --detailed")
    print(list_output)

    # Run the uninstall tests
    uninstall_results = test_uninstall()

    # List remaining installations to verify
    print("\nVerifying remaining installations:")
    list_output = execute_luaenv_command("list")
    print(list_output)

    # Optionally, run the specific DLL build test
    print("\n=== OPTIONALLY RUNNING SPECIFIC DLL BUILD TEST ===")
    dll_build_success = test_specific_dll_build()
    print(f"DLL build test successful: {dll_build_success}")