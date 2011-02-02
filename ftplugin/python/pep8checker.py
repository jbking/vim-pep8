# -*- coding: utf8 -*-

import subprocess
import tempfile
import os
from StringIO import StringIO
from hashlib import md5
from ordered_dict import OrderedDict


class Pep8Checker(object):

    def __init__(self, cmd, cache_limit=10):
        self.cmd = cmd
        self.cache_limit = cache_limit
        self.cache = OrderedDict()

    def check(self, buffer):
        """
        Return a list to check current buffer on the fly.
        """
        # Caching with a digest.
        data = '\n'.join(buffer) + '\n'
        key = md5(data).digest()
        if key in self.cache:
            return self.cache[key]
        # Dequeue the oldest cache in caching FIFO queue.
        if len(self.cache) > self.cache_limit:
            self.cache.popitem(0)
        self.cache[key] = result = self._check(data)
        return result

    def _check(self, data):
        assert isinstance(data, (unicode, str))

        # dump current data to a temp file to check on the fly.
        temp_file_fd, temp_file_path = tempfile.mkstemp()
        try:
            os.write(temp_file_fd, data)
        except:
            os.unlink(temp_file_path)
            raise
        finally:
            os.close(temp_file_fd)

        # Because the call function requires real file, we make a temp file.
        # Otherwise we could use StringIO as a file.
        stdout_file_fd, stdout_file_path = tempfile.mkstemp()
        try:
            # os.fdopen may close then re-open the file descriptor.
            stdout = os.fdopen(stdout_file_fd, 'rw')
        except:
            os.unlink(temp_file_path)
            os.unlink(stdout_file_path)
            raise

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
        finally:
            stdout.close()
            os.unlink(temp_file_path)
            os.unlink(stdout_file_path)

        l = list()
        # Return each pep8 report
        for line in result:
            _path, line = line.split(':', 1)
            lineno, line = line.split(':', 1)
            _columnno, description = line.split(':', 1)
            l.append((lineno, description))
        return l
