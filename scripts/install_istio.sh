#!/usr/bin/env bash

set -eo pipefail

istioctl verify-install
istioctl manifest apply --skip-confirmation