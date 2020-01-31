#!/bin/bash
# Copyright (c) 2019 Denis Trofimov (den.a.trofimov@yandex.ru)
# Distributed under the MIT License.
# See accompanying file LICENSE.md or copy at http://opensource.org/licenses/MIT

set -ev

echo 'starting server...'

# app installed into "${CMAKE_INSTALL_PREFIX}/bin"
test_appserver_core