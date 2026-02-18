#!/usr/bin/python
from setuptools import setup

# When installing from s3tests/ (e.g. pip install -e ./s3tests from repo root),
# the s3tests package is this directory.
setup(
    name='s3tests',
    version='0.0.1',
    package_dir={'s3tests': '.'},
    packages=['s3tests', 's3tests.functional'],

    author='Tommi Virtanen',
    author_email='tommi.virtanen@dreamhost.com',
    description='Unofficial Amazon AWS S3 compatibility tests',
    license='MIT',
    keywords='s3 web testing',

    install_requires=[
        'boto3 >=1.0.0',
        'PyYAML',
        'munch >=2.0.0',
        'gevent >=1.0',
        'isodate >=0.4.4',
        ],
    )
