Wang–Müller line generalization algorithm in PostGIS
----------------------------------------------------

This is Wang–Müller line generalization algorithm implementation in PostGIS.
Following "Line generalization based on analysis of shape characteristics" by
the same authors, 1998.

![line simplification example](https://raw.githubusercontent.com/motiejus/wm/main/salvis.png)

Status
------

The repository is no longer developed and archived. Notable forks:

- [github.com/openmaplt/wm](https://github.com/openmaplt/wm).

If you have used this code as a basis and created an improved version, ping me,
I will link it from this README.

Structure
---------

There are 2 main pieces:

- `wm.sql`, the implementation.
- MSc thesis `mj-msc-full.pdf` with visual examples and known issues.
- A few presentations.

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
clean              Clean the current working directory
clean-tables       Remove tables created during unit or rivers tests
help               Print this help message
mj-msc-full.pdf    Thesis for publishing
mj-msc-gray.pdf    Gray version, to inspect monochrome output
refresh-rivers     Refresh river data from national datasets
test-rivers        Rivers tests (slow)
test               Unit tests (fast)
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

Credit
------

[Nacionalinė Žemės Tarnyba](http://nzt.lt/) for the river data sets.

License
-------

GPLv2 or later.
