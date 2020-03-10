#!/usr/bin/env bash

set -eo pipefail

istioctl verify-install
istioctl manifest apply --skip-confirmation
(kubectl label namespace default istio-injection=enabled || true)