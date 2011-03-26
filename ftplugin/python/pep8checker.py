# -*- coding: utf8 -*-

from subprocess import Popen, PIPE
import tempfile
import os
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

        cmd = "%s %s" % (self.cmd, temp_file_path)

        try:
            p = Popen(cmd, shell=True, stdout=PIPE, stderr=PIPE)
            stdout, _stderr = p.communicate()
            if p.returncode == 0:
                # no pep8 violation
                return []
            elif p.returncode == 1:
                # we got any pep8 violations.
                pass
            elif p.returncode > 1:
                # TODO: notify error by other reason
                return []
        finally:
            os.unlink(temp_file_path)

        l = list()
        # Return each pep8 report
        for line in stdout.split("\n"):
            if not line.strip():
                continue
            _path, line = line.split(':', 1)
            lineno, line = line.split(':', 1)
            _columnno, description = line.split(':', 1)
            l.append((lineno, description))
        return l
