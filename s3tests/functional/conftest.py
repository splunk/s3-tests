import os
import pytest

# Path to the generated list of tests to skip for Splunk (populated from upstream diff)
HERE = os.path.dirname(__file__)
SKIP_LIST_FILE = os.path.join(HERE, 'skip_for_splunk_tests.txt')
COMPLIANCE_LIST_FILE = os.path.join(HERE, 'splunk_compliance_tests.txt')

def _load_skip_list():
    if not os.path.exists(SKIP_LIST_FILE):
        return set()
    with open(SKIP_LIST_FILE, 'r') as f:
        return set(line.strip() for line in f if line.strip())

_SKIP_TESTS = _load_skip_list()
def _load_compliance_list():
    if not os.path.exists(COMPLIANCE_LIST_FILE):
        return set()
    with open(COMPLIANCE_LIST_FILE, 'r') as f:
        return set(line.strip() for line in f if line.strip())

_COMPLIANCE_TESTS = _load_compliance_list()

def pytest_collection_modifyitems(config, items):
    if not _SKIP_TESTS:
        return
    for item in items:
        # item.name is the test function name (e.g., test_foo)
        if item.name in _SKIP_TESTS:
            item.add_marker(pytest.mark.skip(reason='skipped_for_splunk (upstream)'))
        # mark compliance tests so they can be selected easily
        if item.name in _COMPLIANCE_TESTS:
            item.add_marker(pytest.mark.splunk_compliance_test)
