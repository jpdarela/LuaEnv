"""
Test runner for LuaEnv download management unit tests.

This script configures the Python path and runs the download manager tests
with proper test discovery and reporting.
"""

import sys
import os
import unittest
from pathlib import Path

def setup_test_environment():
    """Setup the Python path for testing."""
    # Get project root directory
    project_root = Path(__file__).parent.parent
    backend_dir = project_root / "backend"
    tests_dir = project_root / "tests"

    # Add directories to Python path
    sys.path.insert(0, str(backend_dir))
    sys.path.insert(0, str(tests_dir))

    print(f"Project root: {project_root}")
    print(f"Backend directory: {backend_dir}")
    print(f"Tests directory: {tests_dir}")
    print(f"Python path: {sys.path[:3]}...")
    print()

def run_download_tests():
    """Run download manager unit tests."""
    print("=" * 60)
    print("LuaEnv Download Manager Unit Tests")
    print("=" * 60)

    # Setup environment
    setup_test_environment()

    # Discover and run tests
    loader = unittest.TestLoader()
    start_dir = Path(__file__).parent / "unit"
    suite = loader.discover(start_dir, pattern='test_download_*.py')

    # Run tests with detailed output
    runner = unittest.TextTestRunner(
        verbosity=2,
        failfast=False,
        buffer=True
    )

    result = runner.run(suite)

    # Print summary
    print("\n" + "=" * 60)
    print("TEST SUMMARY")
    print("=" * 60)
    print(f"Tests run: {result.testsRun}")
    print(f"Failures: {len(result.failures)}")
    print(f"Errors: {len(result.errors)}")
    print(f"Skipped: {len(result.skipped)}")

    if result.failures:
        print("\nFAILURES:")
        for test, traceback in result.failures:
            print(f"  - {test}: {traceback.split('AssertionError:')[-1].strip()}")

    if result.errors:
        print("\nERRORS:")
        for test, traceback in result.errors:
            print(f"  - {test}: {traceback.split(':')[-1].strip()}")

    success = len(result.failures) == 0 and len(result.errors) == 0
    print(f"\nResult: {'PASSED' if success else 'FAILED'}")

    return success

def run_specific_test(test_name=None):
    """Run a specific test method or test class."""
    setup_test_environment()

    if test_name:
        # Run specific test
        suite = unittest.TestLoader().loadTestsFromName(test_name)
    else:
        # Run all download tests
        return run_download_tests()

    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)

    return len(result.failures) == 0 and len(result.errors) == 0

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Run LuaEnv download manager unit tests")
    parser.add_argument("--test", "-t", help="Run specific test method (e.g., test_download_manager.TestDownloadManager.test_load_empty_registry)")
    parser.add_argument("--list", "-l", action="store_true", help="List available test methods")

    args = parser.parse_args()

    if args.list:
        # List available tests
        setup_test_environment()
        from unit.test_download_manager import TestDownloadManager

        print("Available test methods:")
        for method_name in dir(TestDownloadManager):
            if method_name.startswith("test_"):
                print(f"  - test_download_manager.TestDownloadManager.{method_name}")
        sys.exit(0)

    # Run tests
    if args.test:
        success = run_specific_test(args.test)
    else:
        success = run_download_tests()

    sys.exit(0 if success else 1)
