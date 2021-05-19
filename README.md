Wang–Müller line generalization algorithm in PostGIS
----------------------------------------------------

This is Wang–Müller line generalization algorithm implementation in PostGIS.
Following "Line generalization based on analysis of shape characteristics" by
the same author, 1998.

Status
------

It mostly works. Read `mj-msc-full.pdf` for visual examples and possible
gotchas.

![line simplification example](https://raw.githubusercontent.com/motiejus/wm/main/salvis.png)

Structure
---------

There are be 2 deliverables:

- `wm.sql`, the implementation.
- paper `mj-msc-full.pdf`, a MSc thesis, explaining it.

It contains a few supporting files, notably:

- `tests.sql` synthetic unit tests.
- `test-rivers.sql` tests with real rivers.
- `Makefile` glues everything together.
- `layer2img.py` converts a PostGIS layer to an embeddable image.
- `aggregate-rivers.sql` combines multiple river objects (linestrings or
  multilinestrings) to a single one.
- `init.sql` initializes PostGIS database for running the tests.
- `rivers-*.sql` are national dataset snapshots of rivers (`Makefile`
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
refresh-rivers     Refresh river data from national datasets
clean              Clean the current working directory
clean-tables       Remove tables created during unit or rivers tests
help               Print this help message
wc                 Character and page count
```

To execute the algorithm, run:

- `make test` for tests with synthetic data.
- `make test-rivers` for tests with real rivers. You may adjust the rivers and
  data source (e.g. use a different country instead of Lithuania) by changing
  the `Makefile` and the test files. Left as an exercise for the reader.

N.B. the `make test-rivers` fails (see `test-rivers.sql`), because with higher
`dhalfcircle` values, the unionized river (`salvis`) is going on top of itself,
making the resulting geometry invalid.

Building the paper (pdf)
------------------------

```
# make -j$(nproc) mj-msc-full.pdf
```

`mj-msc.tex` results in `mj-msc-full.pdf`, which will be at some point
published to this repo. It needs quite a few dependencies, including a
functioning Docker environment, postgresql client, geopandas, pygments,
osm2pgsql, poppler, and a "quite extensive" LaTeX installation. Tested on
Debian 11.

`in-container` script may be helpful if the above sounds like too much.

Contributing
------------

This repository will soon be frozen and does not accept contributions. Please
fork it. If fork has improved the algorithm substantially, feel free to ping
me, I will link to it in this README.

Credit
------

[Nacionalinė Žemės Tarnyba](http://nzt.lt/) for the river data sets.


License
-------

GPLv2 or later.
