##
#
#   The pyroute2 project is dual licensed, see README.license.md for details
#
#

# python ?= python

setup_check := $(shell util/check_setup.sh ${python})

include Makefile.in

ifeq ("${has_pip}", "false")
	exit 1
endif

##
# Python-related configuration
#

##
# Python -W flags:
#
#  ignore  -- completely ignore
#  default -- default action
#  all     -- print all warnings
#  module  -- print the first warning occurence for a module
#  once    -- print each warning only once
#  error   -- fail on any warning
#
#  Would you like to know more? See man 1 python
#
wlevel ?= once

##
# Other options
#
# root      -- install root (default: platform default)
# lib       -- lib installation target (default: platform default)
# coverage  -- whether to produce html coverage (default: false)
# pdb       -- whether to run pdb on errors (default: false)
# module    -- run only the specified test module (default: run all)
#
ifdef root
	override root := "--root=${root}"
endif

ifdef lib
	override lib := "--install-lib=${lib}"
endif

.PHONY: all
all:
	@echo targets:
	@echo
	@echo \* clean -- clean all generated files
	@echo \* docs -- generate project docs \(requires sphinx\)
	@echo \* test -- run functional tests \(see README.make.md\)
	@echo \* install -- install lib into the system
	@echo

.PHONY: clean
clean:
	@rm -f VERSION
	@rm -f Makefile.in
	@rm -rf dist build MANIFEST
	@rm -f docs-build.log
	@rm -f docs/general.rst
	@rm -f docs/changelog.rst
	@rm -f docs/makefile.rst
	@rm -f docs/report.rst
	@rm -rf docs/api
	@rm -rf docs/html
	@rm -rf docs/doctrees
	@[ -z "${keep_coverage}" ] && rm -f  tests/.coverage ||:
	@rm -rf tests/htmlcov
	@[ -z "${keep_coverage}" ] && rm -rf tests/cover ||:
	@rm -rf tests/examples
	@rm -rf tests/bin
	@rm -rf tests/pyroute2
	@rm -f  tests/*xml
	@rm -f  tests/tests.json
	@rm -f  tests/tests.log
	@rm -rf pyroute2.egg-info
	@rm -rf tests-workspaces
	@find pyroute2 -name "*pyc" -exec rm -f "{}" \;
	@find pyroute2 -name "*pyo" -exec rm -f "{}" \;

VERSION:
	@${python} util/update_version.py

docs/html:
	@cp README.rst docs/general.rst
	@cp README.make.md docs/makefile.rst
	@cp README.report.md docs/report.rst
	@cp CHANGELOG.md docs/changelog.rst
	@[ -f docs/_templates/private.layout.html ] && ( \
	    mv -f docs/_templates/layout.html docs/_templates/layout.html.orig; \
		cp docs/_templates/private.layout.html docs/_templates/layout.html; ) ||:
	@export PYTHONPATH=`pwd`; \
		${MAKE} -C docs html || export FAIL=true ; \
		[ -f docs/_templates/layout.html.orig ] && ( \
			mv -f docs/_templates/layout.html.orig docs/_templates/layout.html; ) ||: ;\
		unset PYTHONPATH ;\
		[ -z "$$FAIL" ] || false
	@find docs -name 'aafig-*svg' -exec ${python} util/aafigure_mapper.py docs/aafigure.map '{}' \;

docs: install docs/html

check_parameters:
	@if [ ! -z "${skip_tests}" ]; then \
		echo "'skip_tests' is deprecated, use 'skip=...' instead"; false; fi

.PHONY: format
format:
	@pre-commit run -a

.PHONY: test
test: check_parameters
	@export PYTHON=${python}; \
		export PYTEST=${pytest}; \
		export WLEVEL=${wlevel}; \
		export PDB=${pdb}; \
		export COVERAGE=${coverage}; \
		export LOOP=${loop}; \
		export WORKSPACE=${workspace}; \
		export PYROUTE2_TEST_DBNAME=${dbname}; \
		export SKIPDB=${skipdb}; \
		export PYTEST_PATH=${module}; \
		export BREAK_ON_ERRORS=${break}; \
		export NODEPLOY=${nodeploy}; \
		/usr/bin/env bash -x ./tests/run_pytest.sh

.PHONY: test-platform
test-platform:
	@${python} -c "\
import logging;\
logging.basicConfig();\
from pr2modules.config.test_platform import TestCapsRtnl;\
from pprint import pprint;\
pprint(TestCapsRtnl().collect())"

.PHONY: upload
upload: dist
	${python} -m twine upload dist/*

.PHONY: setup
setup:
	$(MAKE) clean
	$(MAKE) VERSION

.PHONY: dist
dist: setup
	${python} setup.py sdist
	${python} -m twine check dist/*

.PHONY: install
install: dist
	rm -f dist/pyroute2.minimal*
	${python} -m pip install dist/pyroute2* ${root}

.PHONY: install-minimal
install-minimal: dist
	${python} -m pip install dist/pyroute2.minimal* ${root}

.PHONY: uninstall
uninstall: setup
	${python} -m pip uninstall -y pyroute2

.PHONY: audit-imports
audit-imports:
	findimports -n pyroute2 2>/dev/null | awk -f util/imports_dict.awk

# deprecated:
epydoc clean-version update-version force-version README.md setup.ini develop pytest test-format:
	@echo Deprecated target, see README.make.md
