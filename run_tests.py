#!/usr/bin/env python3
"""
Simple test runner for Lua MSVC Build System tests.

Runs all tests in the tests/ directory, ensuring the bootstrap test runs first.
Can also run individual test categories using command-line options.
"""

import unittest
import sys
import argparse
from pathlib import Path

def load_specific_test_classes(test_module_name, class_names):
    """Load specific test classes from a test module."""
    suite = unittest.TestSuite()
    loader = unittest.TestLoader()

    try:
        module = __import__(f'tests.{test_module_name}', fromlist=class_names)
        for class_name in class_names:
            if hasattr(module, class_name):
                test_class = getattr(module, class_name)
                class_suite = loader.loadTestsFromTestCase(test_class)
                suite.addTest(class_suite)
            else:
                print(f"[WARNING] Test class {class_name} not found in {test_module_name}")
    except ImportError as e:
        print(f"[ERROR] Failed to load test module {test_module_name}: {e}")
        return None

    return suite

def run_bootstrap_test():
    """Run the bootstrap test first."""
    print("[*] Running bootstrap test...")
    try:
        suite = load_specific_test_classes('test_download', ['TestDownloadBootstrap'])
        if suite is None:
            return False

        runner = unittest.TextTestRunner(verbosity=2, buffer=True)
        result = runner.run(suite)
        return result.wasSuccessful()
    except Exception as e:
        print(f"[ERROR] Bootstrap test failed: {e}")
        return False

def run_config_basic_tests():
    """Run basic config tests."""
    print("[*] Running config basic tests...")
    suite = load_specific_test_classes('test_config_basic', ['TestConfigBasic'])
    return suite

def run_config_cache_tests():
    """Run config cache tests."""
    print("[*] Running config cache tests...")
    suite = load_specific_test_classes('test_config_cache', ['TestConfigCache'])
    return suite

def run_config_cli_tests():
    """Run config CLI tests."""
    print("[*] Running config CLI tests...")
    suite = load_specific_test_classes('test_config_cli', ['TestConfigCommandLine', 'TestConfigCacheIntegration'])
    return suite

def run_config_tests():
    """Run all config tests."""
    print("[*] Running all config tests...")
    suite = unittest.TestSuite()

    # Add basic config tests
    basic_suite = load_specific_test_classes('test_config_basic', ['TestConfigBasic'])
    if basic_suite:
        suite.addTest(basic_suite)

    # Add cache tests
    cache_suite = load_specific_test_classes('test_config_cache', ['TestConfigCache'])
    if cache_suite:
        suite.addTest(cache_suite)

    # Add CLI tests
    cli_suite = load_specific_test_classes('test_config_cli', ['TestConfigCommandLine', 'TestConfigCacheIntegration'])
    if cli_suite:
        suite.addTest(cli_suite)

    return suite

def run_download_tests():
    """Run download tests (excluding bootstrap)."""
    print("[*] Running download tests...")
    suite = load_specific_test_classes('test_download', ['TestDownloadFunctions', 'TestDownloadIntegration', 'TestDownloadReal'])
    return suite

def run_setup_build_tests():
    """Run setup_build tests."""
    print("[*] Running setup_build tests...")
    suite = load_specific_test_classes('test_setup_build', ['TestSetupBuildReal', 'TestSetupBuildMissingDirectories'])
    return suite

def run_all_tests():
    """Run all tests with bootstrap first."""
    print("[*] Running all tests...")
    suite = unittest.TestSuite()
    loader = unittest.TestLoader()

    # First, run the bootstrap test
    if not run_bootstrap_test():
        print("[ERROR] Bootstrap test failed, aborting remaining tests")
        return False

    # Then discover and add all other tests
    print("[*] Discovering remaining tests...")
    all_tests = loader.discover('tests', pattern='test_*.py')

    # Filter out the bootstrap test to avoid running it twice
    for test_group in all_tests:
        for test_case in test_group:
            # Skip the bootstrap test case since we already ran it
            if hasattr(test_case, '_testMethodName'):
                test_class_name = test_case.__class__.__name__
                if test_class_name != 'TestDownloadBootstrap':
                    suite.addTest(test_case)
            else:
                # Handle test suites
                for test in test_case:
                    if hasattr(test, '_testMethodName'):
                        test_class_name = test.__class__.__name__
                        if test_class_name != 'TestDownloadBootstrap':
                            suite.addTest(test)

    # Run the remaining tests
    if suite.countTestCases() > 0:
        runner = unittest.TextTestRunner(verbosity=2, buffer=True)
        result = runner.run(suite)
        return result.wasSuccessful()

    return True

def main():
    """Main function with argument parsing."""
    parser = argparse.ArgumentParser(
        description='Test runner for Lua MSVC Build System',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python run_tests.py                 # Run all tests (default)
  python run_tests.py --config        # Run all config tests
  python run_tests.py --config-basic  # Run basic config tests only
  python run_tests.py --config-cache  # Run config cache tests only
  python run_tests.py --config-cli    # Run config CLI tests only
  python run_tests.py --download      # Run download tests only
  python run_tests.py --setup-build   # Run setup_build tests only

Note: The bootstrap test will always run first when needed.
        """
    )

    parser.add_argument(
        '--config',
        action='store_true',
        help='Run all config tests (basic, cache, and CLI)'
    )

    parser.add_argument(
        '--config-basic',
        action='store_true',
        help='Run basic config tests only'
    )

    parser.add_argument(
        '--config-cache',
        action='store_true',
        help='Run config cache tests only'
    )

    parser.add_argument(
        '--config-cli',
        action='store_true',
        help='Run config CLI tests only'
    )

    parser.add_argument(
        '--download',
        action='store_true',
        help='Run download tests only'
    )

    parser.add_argument(
        '--setup-build',
        action='store_true',
        help='Run setup_build tests only'
    )

    args = parser.parse_args()

    print("Lua MSVC Build System - Test Runner")
    print("=" * 40)

    # Determine which tests to run
    if args.config_basic:
        print("Running basic config tests only.")
        suite = run_config_basic_tests()
        needs_bootstrap = False
    elif args.config_cache:
        print("Running config cache tests only.")
        suite = run_config_cache_tests()
        needs_bootstrap = False
    elif args.config_cli:
        print("Running config CLI tests only.")
        suite = run_config_cli_tests()
        needs_bootstrap = False
    elif args.config:
        print("Running all config tests.")
        suite = run_config_tests()
        needs_bootstrap = False
    elif args.download:
        print("Running download tests only.")
        print("Note: Bootstrap test will run first to ensure required files are available.")
        if not run_bootstrap_test():
            print("[ERROR] Bootstrap test failed, aborting download tests")
            sys.exit(1)
        suite = run_download_tests()
        needs_bootstrap = False
    elif args.setup_build:
        print("Running setup_build tests only.")
        print("Note: Bootstrap test will run first to ensure required files are available.")
        if not run_bootstrap_test():
            print("[ERROR] Bootstrap test failed, aborting setup_build tests")
            sys.exit(1)
        suite = run_setup_build_tests()
        needs_bootstrap = False
    else:
        # Default: run all tests
        print("Running all tests.")
        print("Note: The bootstrap test will run first to ensure all required files are available.")
        success = run_all_tests()
        if success:
            print("\n" + "=" * 40)
            print("[+] All tests passed!")
        else:
            print("\n" + "=" * 40)
            print("[X] Some tests failed!")
        sys.exit(0 if success else 1)

    # Run the selected test suite
    if suite and suite.countTestCases() > 0:
        print()
        runner = unittest.TextTestRunner(verbosity=2, buffer=True)
        result = runner.run(suite)

        # Show summary
        print("\n" + "=" * 40)
        if result.wasSuccessful():
            print("[+] All tests passed!")
            print(f"[*] Ran {result.testsRun} tests successfully")
        else:
            print("[X] Some tests failed!")
            print(f"[*] Ran {result.testsRun} tests")
            print(f"[X] Failures: {len(result.failures)}")
            print(f"[X] Errors: {len(result.errors)}")
            print(f"[-] Skipped: {len(result.skipped) if hasattr(result, 'skipped') else 0}")

            if result.failures:
                print("\n[!] Failed tests:")
                for test, traceback in result.failures:
                    print(f"  - {test}")

            if result.errors:
                print("\n[!] Error tests:")
                for test, traceback in result.errors:
                    print(f"  - {test}")

        # Exit with error code if tests failed
        sys.exit(0 if result.wasSuccessful() else 1)
    else:
        print("[ERROR] No tests found or failed to load test suite")
        sys.exit(1)

if __name__ == '__main__':
    main()
