"""
Test runner wrapper with automatic failure evidence collection.

Wraps the main automation logic in a try/except that calls
save_failure_artifacts() before re-raising any exception.
QA can then view the evidence at http://localhost:5001/failures.
"""

from automation.artifact_manager import save_failure_artifacts


def run_test(driver):
    """
    Replace the body of this function with your actual test logic.
    The try/except here ensures artifacts are collected on any failure.
    """
    try:
        _test_body(driver)
    except Exception as e:
        save_failure_artifacts(driver, e)
        raise


def _test_body(driver):
    """Main automation steps go here."""
    raise NotImplementedError("Replace with your automation logic.")
