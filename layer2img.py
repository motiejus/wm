#!/usr/bin/python3
import argparse
import geopandas
import psycopg2
import matplotlib.pyplot as plt

from matplotlib import rc

# CMAP = 'Set3'  # this is nice too
CMAP = 'tab20c'

BOUNDS = ('xmin', 'ymin', 'xmax', 'ymax')
BLACK, GREEN, ORANGE, PURPLE = '#000000', '#1b9e77', '#d95f02', '#7570b3'
PSQL_CREDS = "host=127.0.0.1 dbname=osm user=osm password=osm"


def parse_args():
    parser = argparse.ArgumentParser(
            description='Convert geopackage to an image')
    parser.add_argument('--group1-table')
    parser.add_argument('--group1-where')
    parser.add_argument('--group1-cmap', type=bool)
    parser.add_argument('--group1-linestyle')

    parser.add_argument('--group2-table')
    parser.add_argument('--group2-where')
    parser.add_argument('--group2-cmap', type=bool)
    parser.add_argument('--group2-linestyle')

    parser.add_argument('--group3-table')
    parser.add_argument('--group3-where')
    parser.add_argument('--group3-cmap', type=bool)
    parser.add_argument('--group3-linestyle')

    parser.add_argument('--widthdiv',
                        default=1, type=float, help='Width divisor')

    parser.add_argument('-o', '--outfile', metavar='<file>')
    parser.add_argument('--clip', type=float, nargs=4, metavar=BOUNDS)
    return parser.parse_args()


def read_layer(table, maybe_where=None):
    if not table:
        return
    conn = psycopg2.connect(PSQL_CREDS)
    sql = "SELECT way FROM %s" % table
    if maybe_where:
        sql += " WHERE %s" % maybe_where
    return geopandas.read_postgis(sql, con=conn, geom_col='way')

def plot_args(color, maybe_cmap, maybe_linestyle):
    if maybe_cmap:
        r = {'cmap': CMAP}
    else:
        r = {'color': color}

    if maybe_linestyle:
        r['linestyle'] = maybe_linestyle
    return r

def main():
    args = parse_args()
    group1 = read_layer(args.group1_table, args.group1_where)
    group2 = read_layer(args.group2_table, args.group2_where)
    group3 = read_layer(args.group3_table, args.group3_where)
    c1 = plot_args(BLACK, args.group1_cmap, args.group1_linestyle)
    c2 = plot_args(ORANGE, args.group2_cmap, args.group2_linestyle)
    c3 = plot_args(GREEN, args.group3_cmap, args.group3_linestyle)

    rc('text', usetex=True)
    fig, ax = plt.subplots()
    fig.set_figwidth(8.27 / args.widthdiv)
    if c := args.clip:
        ax.set_xlim(left=c[0], right=c[2])
        ax.set_ylim(bottom=c[1], top=c[3])

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
