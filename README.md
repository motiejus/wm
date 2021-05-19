Wang–Müller algorithm in PostGIS
--------------------------------

This is a work-in-progress implementation following "Line generalization based
on analysis of shape characteristics" by Wang and Müller, 1998.

Structure
---------

There will be 2 deliverables from this folder:

- `wm.sql`, the implementation.
- paper `mj-msc-full.pdf`, a MSc thesis, explaining the whole thing.

It contains a few supporting files, notably:

- `tests.sql` synthetic unit tests.
- `test-rivers.sql` tests with real rivers.
- `Makefile` glues everything together.
- `layer2img.py` converts a PostGIS layer to an embeddable image.
- `aggregate-rivers.sql` combines multiple river objects (linestrings or
  multilinestrings) to a single one.
- `init.sql` initializes PostGIS database for running the tests.
- `rivers.sql` is an OpenStreetMap snapshot of select rivers (`Makefile`
  contains code to update them).
- ... and a few more files necessary to build the paper.

Running
-------

`make help` lists the select commands for humans. As of writing:

```
# make help
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
  the `Makefile` and the test files. Left as an exercise for the reader.

Building the paper (pdf)
------------------------

```
$ make -j$(nproc) mj-msc-full.pdf
```

`mj-msc.tex` results in `mj-msc-full.pdf`, which will be at some point
published. It needs quite a few dependencies, including a functioning Docker
environment, postgresql client, geopandas, and a pretty complete LaTeX
installation.

Contributing
------------

Please reach out to me before contributing. As of writing, this is not ready to
accept broader contributions, TODO:

[] CI.

[] It has a bug in `wm_self_crossing`: the program crashes with a river in
    Lithuania.

[] Implementation is not yet complete (stay tuned).

License
-------

Same as QGIS and PostGIS: GPL 2.0 or later.
