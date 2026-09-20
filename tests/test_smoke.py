from importlib.metadata import version

import funwall


def test_package_version() -> None:
    assert funwall.__version__ == version("funwall") == "1.1.7"
