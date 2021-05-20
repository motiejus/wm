Wang–Müller line generalization algorithm in PostGIS
----------------------------------------------------

This is Wang–Müller line generalization algorithm implementation in PostGIS.
Following "Line generalization based on analysis of shape characteristics" by
the same authors, 1998.

Status
------

Mostly works. Read `mj-msc-full.pdf` for visual examples and possible gotchas.

![line simplification example](https://raw.githubusercontent.com/motiejus/wm/main/salvis.png)

Structure
---------

There are 2 main deliverables:

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
```

To execute the algorithm, run:

- `make test` for tests with synthetic data.
- `make test-rivers` for tests with real rivers. You may adjust the rivers and
  data source (e.g. use a different country instead of Lithuania) by changing
  the `Makefile` and the test files. Left as an exercise for the reader.

N.B. the `make test-rivers` fails (see `test-rivers.sql`), because with higher
`dhalfcircle` values, the unionized river (`salvis`) is going on top of itself,
making the resulting geometry invalid during the process.

Building the paper (pdf)
------------------------

```
# make -j mj-msc-full.pdf
```

`mj-msc.tex` results in `mj-msc-full.pdf`. This step needs quite a few
or a container: see `Dockerfile` for dependencies or `in-container` to run
it all in the container.

Contributing
------------

This repository does not accept contributoins. Please fork it. If a fork has
improved the algorithm substantially, you are welcome to ping me, I will link
to it in this README.

Credit
------

[Nacionalinė Žemės Tarnyba](http://nzt.lt/) for the river data sets.


License
-------

GPLv2 or later.
