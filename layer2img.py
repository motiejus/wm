#!/usr/bin/python3
import argparse
import geopandas
import psycopg2
import matplotlib.pyplot as plt

from matplotlib import rc

# CMAP = 'Set3'  # is nice too
CMAP = 'tab20c'

BOUNDS = ('xmin', 'ymin', 'xmax', 'ymax')
BLACK, GREEN, ORANGE, PURPLE = '#000000', '#1b9e77', '#d95f02', '#7570b3'
PSQL_CREDS = "host=127.0.0.1 dbname=osm user=osm password=osm"

# see `NOTICE` in the LaTeX document; this is the width of the main text block.
TEXTWIDTH_CM = 12.12364


def inch(cm):
    return cm / 2.54


def parse_args():
    parser = argparse.ArgumentParser(
            description='Convert a geometry to an image')
    parser.add_argument('--group1-select', required=True)
    parser.add_argument('--group1-linestyle')

    simplify = parser.add_mutually_exclusive_group()
    simplify.add_argument('--group1-simplifydp', type=int)
    simplify.add_argument('--group1-simplifyvw', type=int)
    parser.add_argument('--group1-chaikin', type=bool)

    parser.add_argument('--group2-select')
    parser.add_argument('--group2-linestyle')
    simplify = parser.add_mutually_exclusive_group()
    simplify.add_argument('--group2-simplifydp', type=int)
    simplify.add_argument('--group2-simplifyvw', type=int)
    parser.add_argument('--group2-chaikin', type=bool)

    parser.add_argument('--group3-select')
    parser.add_argument('--group3-linestyle')
    simplify = parser.add_mutually_exclusive_group()
    simplify.add_argument('--group3-simplifydp', type=int)
    simplify.add_argument('--group3-simplifyvw', type=int)
    parser.add_argument('--group3-chaikin', type=bool)

    parser.add_argument('--widthdiv',
                        default=1, type=float, help='Width divisor')

    parser.add_argument('-o', '--outfile', metavar='<file>')
    return parser.parse_args()


def read_layer(select, width):
    if not select:
        return
    way = "way"
    conn = psycopg2.connect(PSQL_CREDS)
    sql = "SELECT {way} as way1 FROM {select}".format(way=way, select=select)
    return geopandas.read_postgis(sql, con=conn, geom_col='way1')


def plot_args(geom, color, maybe_linestyle):
    if geom is None:
        return

    if geom.geom_type[0] == 'Polygon':
        return {'cmap': CMAP}

    r = {'color': color}
    if maybe_linestyle == 'invisible':
        r['color'] = (0, 0, 0, 0)
    elif maybe_linestyle:
        r['linestyle'] = maybe_linestyle
    return r


def main():
    args = parse_args()
    width = TEXTWIDTH_CM / args.widthdiv
    group1 = read_layer(args.group1_select, width)
    group2 = read_layer(args.group2_select, width)
    group3 = read_layer(args.group3_select, width)
    c1 = plot_args(group1, BLACK, args.group1_linestyle)
    c2 = plot_args(group2, ORANGE, args.group2_linestyle)
    c3 = plot_args(group3, GREEN, args.group3_linestyle)

    rc('text', usetex=True)
    fig, ax = plt.subplots()
    fig.set_figwidth(inch(width))

    group1 is not None and group1.plot(ax=ax, **c1)
    group2 is not None and group2.plot(ax=ax, **c2)
    group3 is not None and group3.plot(ax=ax, **c3)

    ax.axis('off')
    ax.margins(0, 0)
    if args.outfile:
        fig.savefig(args.outfile, bbox_inches='tight', dpi=600)
    else:
        plt.show()


if __name__ == '__main__':
    main()
