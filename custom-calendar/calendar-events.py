#!/usr/bin/env python3
"""Run Noctalia's Evolution Data Server events script with whatever ICalGLib is installed.

Noctalia pins ICalGLib 3.0, but Arch ships libical 4 (ICalGLib 4.0), so its script
fails and the built-in CalendarService stays empty. The API the script uses is the same.

Usage: calendar-events.py <noctalia calendar-events.py> <start unix> <end unix>
"""
import runpy
import sys

import gi

_require_version = gi.require_version


def require_version(namespace, version):
    if namespace == "ICalGLib":
        for candidate in (version, "4.0", "3.0"):
            try:
                return _require_version(namespace, candidate)
            except ValueError:
                pass
    return _require_version(namespace, version)


gi.require_version = require_version

script = sys.argv[1]
sys.argv = [script] + sys.argv[2:]
runpy.run_path(script, run_name="__main__")
