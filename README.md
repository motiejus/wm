Wang–Müller algorithm in PostGIS
--------------------------------

This is a work-in-progress implementation following "Line generalization based
on analysis of shape characteristics" by Wang and Müller, 1998 paper.

Structure
---------

Detailed implementation description: `mj-msc.tex`. It is describing in detail
what is implemented and what isn't, and why.

Algorithm itself: `wm.sql`. This is the main file you probably want to look at.

Synthetic tests are in `tests.sql`. They are exercising various pieces of the
algorithm and asserting the results are what expect them to be.

Tests with real rivers are in `test-rivers.sql`.

`Makefile` glues everything together.

Executing the algorithm
-----------------------

```
$ make help
mj-msc-full.pdf    Thesis for publishing
test               Unit tests (fast)
test-rivers        Rivers tests (slow)
clean              Clean the current working directory
clean-tables       Remove tables created during unit or rivers tests
help               Print this help message
wc                 Character and page count
refresh-rivers     Refresh rivers.sql from Open Street Maps
```

To execute the algorithm, run:

- `make test` for tests with synthetic data.
- `make test-rivers` for tests with real rivers. You may adjust the rivers and
  data source (e.g. use a different country instead of Lithuania) by changing
  the `Makefile` and the test files.

Building the paper (pdf)
------------------------

`mj-msc.tex` results in `mj-msc-full.pdf`, which will be at some point
published. It needs quite a few dependencies, including a functioning Docker
environment.

License
-------

GPL 2.0 or later. Same as QGIS and PostGIS.
