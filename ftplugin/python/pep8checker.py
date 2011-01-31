# -*- coding: utf8 -*-

import traceback
import subprocess
import tempfile
import os
from StringIO import StringIO

import sys


class Pep8Checker(object):

    def __init__(self, cmd, buffer):
        self.cmd = cmd
        self.buffer = buffer

    @classmethod
    def close_fd(cls, fd, force=True):
        try:
            os.close(fd)
        except:
            if not force:
                raise

    @classmethod
    def delete_file(cls, path, force=True):
        try:
            os.unlink(path)
        except:
            if not force:
                raise

    def check(self):
        """
        Return a list to check current buffer on the fly.
        """
        # dump current buffer to a temp file to check on the fly.
        temp_file_fd, temp_file_path = tempfile.mkstemp()
        try:
            for line in self.buffer:
                os.write(temp_file_fd, line + "\n")
        except:
            traceback.print_exc(file=sys.stdout)
            self.delete_file(temp_file_path)
            return []
        finally:
            self.close_fd(temp_file_fd)

        # Because the call function requires real file, we make a temp file.
        # Otherwise we could use StringIO as a file.
        stdout_file_fd, stdout_file_path = tempfile.mkstemp()
        try:
            # os.fdopen may close the file descriptor.
            stdout = os.fdopen(stdout_file_fd, 'rw')
        except:
            traceback.print_exc(file=sys.stdout)
            self.delete_file(temp_file_path)
            self.delete_file(stdout_file_path)
            return []

        cmd = "%s %s" % (self.cmd, temp_file_path)

        try:
            code = subprocess.call(cmd, shell=True, stdout=stdout)
            if code == 0:
                # no pep8 violation
                return []
            elif code == 1:
                stdout.seek(0)
                result = StringIO(stdout.read())
            elif code > 1:
                # TODO: notify error by other reason
                return []
        except:
            traceback.print_exc(file=sys.stdout)
            return []
        finally:
            stdout.close()
            self.delete_file(temp_file_path)
            self.delete_file(stdout_file_path)

        l = list()
        # Return each pep8 report
        for line in result:
            _path, line = line.split(':', 1)
            lineno, line = line.split(':', 1)
            _columnno, description = line.split(':', 1)
            l.append((lineno, description))
        return l
