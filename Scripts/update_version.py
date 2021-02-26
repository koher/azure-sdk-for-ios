#!/usr/bin/python3

import glob
import logging
import os
import sys

def _log_error_and_quit(msg, out = None, err = None, code = 1):
    """ Log an error message and exit. """
    warning_color = '\033[91m'
    end_color = '\033[0m'
    if err:
        logging.error(f'{err}')
    elif out:
        logging.error(f'{out}')
    logging.error(f'{warning_color}{msg} ({code}){end_color}')
    sys.exit(code)

def _update_file(path, old, new):
    with open(path, mode='r') as f:
        data = f.read()
    data = data.replace(old, new)
    with open(path, mode='w') as f:
        f.write(data)


def main(argv):
    cwd = os.getcwd()
    if os.path.basename(cwd) != 'azure-sdk-for-ios':
        _log_error_and_quit('This script must be run from the root of the azure-sdk-for-ios repo')

    if len(argv) != 2:
        _log_error_and_quit(f'usage: python3 {__file__} old_version new_version')

    old = argv[0]
    new = argv[1]

    # TODO: maybe (?) update CHANGELOG.md

    files_to_update = [
        'README.md',
        'eng/ignore-links.txt'
    ]
    files_to_update += glob.glob(r'jazzy/*.yml')
    # may need to be more deliberate with podspecs in case there is a version
    # clash with a dependency
    files_to_update += glob.glob(r'*.podspec.json')

    for path in files_to_update:
        _update_file(path, old, new)

    # update Xcodeproj files
    xcodeproj_files = glob.glob(r'sdk/*/*/*.xcodeproj/project.pbxproj')
    for path in xcodeproj_files:
        with open(path, 'r') as f:
            data = f.readlines()

        with open(path, 'w') as f:
            for line in data:
                if "MARKETING_VERSION" in line:
                    f.write(line.replace(old, new))
                else:
                    f.write(line)


if __name__ == '__main__':
    main(sys.argv[1:])
