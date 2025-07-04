#!/usr/bin/env python3
"""
Comprehensive test runner for the Lua MSVC Build project.
Runs all unit and integration tests.
"""

import sys
import unittest
import argparse
from pathlib import Path

# Add the project directories to the Python path
project_root = Path(__file__).parent.parent.absolute()
backend_dir = project_root / "backend"
tests_dir = project_root / "tests"

for path in [project_root, backend_dir, tests_dir]:
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

def main():
    """Run all unit and integration tests."""
    parser = argparse.ArgumentParser(description="Run Lua MSVC Build test suite")
    parser.add_argument("--unit", action="store_true", help="Run only unit tests")
    parser.add_argument("--integration", action="store_true", help="Run only integration tests")
    parser.add_argument("--list", "-l", action="store_true", help="List all available tests")
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose output")

    args = parser.parse_args()

    print("Lua MSVC Build Test Suite")
    print("=" * 60)

    # If no specific type requested, run all
    run_unit = args.unit or not (args.unit or args.integration)
    run_integration = args.integration or not (args.unit or args.integration)

    suite = unittest.TestSuite()
    loader = unittest.TestLoader()

    try:
        if run_unit:
            from tests.unit.test_download_manager import TestDownloadManager
            suite.addTests(loader.loadTestsFromTestCase(TestDownloadManager))
            print("✓ Loaded unit tests (22 tests)")

            if args.list:
                print("\nUnit Tests:")
                for method_name in dir(TestDownloadManager):
                    if method_name.startswith("test_"):
                        print(f"  - {method_name}")

        if run_integration:
            from tests.integration.test_download_script import TestDownloadScript
            suite.addTests(loader.loadTestsFromTestCase(TestDownloadScript))
            print("✓ Loaded integration tests (25 tests)")

            if args.list:
                print("\nIntegration Tests:")
                for method_name in dir(TestDownloadScript):
                    if method_name.startswith("test_"):
                        print(f"  - {method_name}")

    except ImportError as e:
        print(f"Error importing tests: {e}")
        return False

    if args.list:
        print(f"\nTotal: {suite.countTestCases()} tests")
        return True

    if suite.countTestCases() == 0:
        print("No tests found.")
        return False

    print(f"\nRunning {suite.countTestCases()} tests...")
    print("=" * 60)

    # Run tests
    verbosity = 2 if args.verbose else 1
    runner = unittest.TextTestRunner(verbosity=verbosity)
    result = runner.run(suite)

    print("=" * 60)
    if result.wasSuccessful():
        print(f"✓ All {result.testsRun} tests passed!")
    else:
        print(f"✗ {len(result.failures)} failures, {len(result.errors)} errors")

        if result.failures:
            print("\nFailures:")
            for test, trace in result.failures:
                print(f"  - {test}")

        if result.errors:
            print("\nErrors:")
            for test, trace in result.errors:
                print(f"  - {test}")

    return result.wasSuccessful()

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
