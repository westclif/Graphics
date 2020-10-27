"""Downloads, unzips and prepares UTR (but doesn't execute it).
This script reproduces the same download behavior as the following shell/batch files:
* https://github.cds.internal.unity3d.com/unity/utr/blob/master/utr
* https://github.cds.internal.unity3d.com/unity/utr/blob/master/utr.bat
i.e. it skips download if the target folder for the version to be dowloaded already exists.
NOTICE: This script doesn't execute UTR - it only performs the download!
This script is compatible with Python 2 and 3.
"""
from __future__ import absolute_import
import argparse
import logging
import os
import platform
import subprocess
import sys
import time
import zipfile

import requests
from requests.adapters import HTTPAdapter
from requests.packages.urllib3.util.retry import Retry

from subprocess_helpers import git_cmd

NUMBER_OF_RETRIES = 10
REQUEST_TIMEOUT_SECONDS = 10
RETRY_BACKOFF_FACTOR = 2  # Means wait 1,2,4,8... seconds
RETRY_STATUS_CODES = [
    429,  # Too Many Requests
    500,  # Internal Server Error
    502,  # Bad Gateway
    503,  # Service Unavailable
    504,  # Gateway Timeout
]


def get_platform_string():
    """For constructing the download URL."""
    p = platform.system()
    if p == 'Linux':
        return 'linux'
    if p == 'Windows':
        return 'win'
    if p == 'Darwin':
        return 'osx'
    raise Exception('Unsupported platform: {}'.format(p))


def get_username():
    if platform.system() == 'Windows':
        return os.getenv('USERNAME')
    return subprocess.check_output('whoami', shell=True)


def get_download_url(version, platform_string, username):
    url = ('https://artifactory.internal.unity3d.com/core-automation/tools/'
           'utr-standalone/preview/utr-standalone-{0}-{1}.zip'.format(platform_string, version))
    if username == 'builduser':
        url = ('https://bfartifactory.bf.unity3d.com/artifactory/ie-generic-core-automation/tools/'
               'utr-standalone/preview/utr-standalone-{0}-{1}.zip'.format(platform_string, version))
    elif username == 'bokken':
        url = ('http://artifactory-slo.bf.unity3d.com/artifactory/ie-generic-core-automation/tools/'
               'utr-standalone/preview/utr-standalone-{0}-{1}.zip'.format(platform_string, version))
    return url


def download(url, local_file):
    logging.info('Downloading into {}'.format(local_file))
    start = time.time()

    # Connection reset errors doesn't seem to be caught using the requests retry mechanisms
    # (see https://stackoverflow.com/questions/52181161/handling-exceptions-from-python-requests)
    # so we're handling it differently, with a separate counter.
    connection_reset_retry_count = 0
    success = False

    while not success and connection_reset_retry_count < NUMBER_OF_RETRIES:
        try:
            session = requests.Session()
            retries = Retry(total=NUMBER_OF_RETRIES, backoff_factor=RETRY_BACKOFF_FACTOR,
                            status_forcelist=RETRY_STATUS_CODES)
            adapter = HTTPAdapter(max_retries=retries)
            session.mount('http://', adapter)
            session.mount('https://', adapter)
            response = session.get(url, allow_redirects=True, timeout=REQUEST_TIMEOUT_SECONDS)

            download_time = time.time() - start
            download_size_mb = len(response.content) / (1024 * 1024)
            open(local_file, 'wb').write(response.content)
            success = True
            logging.info('Downloaded {0:.1f} MB in {1:.1f} seconds ({2:.1f} MB/s).'
                         .format(download_size_mb, download_time, download_size_mb / download_time))
        except requests.exceptions.RetryError:
            logging.error('Failed to download from {0} after {1} retry attempts.'
                          .format(url, NUMBER_OF_RETRIES))
            raise
        except requests.exceptions.ChunkedEncodingError as e:
            # Exponentially increasing delay in seconds.
            delay_seconds = 2 ** connection_reset_retry_count
            logging.warning(f'Got connection reset error: {e}. '
                            'Retrying in {delay_seconds} seconds...')
            time.sleep(delay_seconds)
            connection_reset_retry_count += 1


def unzip(zip_filename, target_dir):
    logging.info('Unzipping {0} into {1}'.format(zip_filename, target_dir))
    with zipfile.ZipFile(zip_filename, 'r') as zip_file:
        zip_file.extractall(target_dir)


def create_if_not_exists(dirname):
    if not os.path.isdir(dirname):
        os.mkdir(dirname)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('-v', '--version', required=True, help='The UTR version to download. '
                        'Check https://github.cds.internal.unity3d.com/unity/utr#version-history '
                        'for available releases.')
    args = parser.parse_args()

    logging.basicConfig(level=logging.DEBUG, format='[%(levelname)s] %(message)s')

    try:
        REPO_ROOT = os.path.abspath(git_cmd('rev-parse --show-toplevel', cwd='.').strip())

        # Directory creation.
        DOWNLOAD_DIR = os.path.join(REPO_ROOT, '.download')
        create_if_not_exists(DOWNLOAD_DIR)

        BIN_DIR = os.path.join(REPO_ROOT, '.bin')
        create_if_not_exists(BIN_DIR)

        UTR_VERSIONED_DIR = os.path.join(BIN_DIR, 'utr.{}'.format(args.version))

        if os.path.isdir(UTR_VERSIONED_DIR):
            logging.info('Found existing directory for UTR version {0} at {1}. Exiting...'
                         .format(args.version, UTR_VERSIONED_DIR))
            return 0

        platform_string = get_platform_string()
        username = get_username()
        url = get_download_url(args.version, platform_string, username)
        logging.info("Download URL: {}".format(url))

        zip_filename = 'utr.{}.zip'.format(args.version)
        downloaded_zipfile = os.path.join(DOWNLOAD_DIR, zip_filename)
        # (fixme): Consider being smart and skip downloading if the file exists, but there
        # is no way to be sure, so for now always do it.
        download(url, downloaded_zipfile)

        # Create the directory only if download is succesful, a failed download will
        # trigger a retry on rerunning the script.
        os.mkdir(UTR_VERSIONED_DIR)
        unzip(downloaded_zipfile, UTR_VERSIONED_DIR)

        if platform.system() != 'Windows':
            utr_executable = os.path.join(UTR_VERSIONED_DIR, 'UnifiedTestRunner')
            subprocess.check_call('chmod +x {}'.format(utr_executable), shell=True)
            logging.info('Added executable attribute on {}'.format(utr_executable))
        return 0
    except subprocess.CalledProcessError as err:
        logging.error('Failed to run "{0}"\nStdout:\n{1}\nStderr:\n{2}'
                      .format(err.cmd, err.stdout, err.stderr))
        return 1


if __name__ == '__main__':
    sys.exit(main())
