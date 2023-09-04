#!/usr/bin/env python3
"""Provide log functions."""

import sys

from loguru import logger

logger.add("violet.py.log", rotation="10MB")
logger.add(sys.stdout)
