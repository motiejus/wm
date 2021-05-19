#!/usr/bin/python3
import argparse
import geopandas
import psycopg2
import matplotlib.pyplot as plt

from matplotlib import rc, patches

INCH = 25.4  # mm
BOUNDS = ('xmin', 'ymin', 'xmax', 'ymax')
GREEN, ORANGE, PURPLE = '#1b9e77', '#d95f02', '#7570b3'


def plt_size(string):
    if not string:
        return None
    try:
        w, h = string.split("x")
        return float(w) / INCH, float(h) / INCH
    except Exception as e:
        raise argparse.ArgumentTypeError from e


def parse_args():
    parser = argparse.ArgumentParser(
            description='Convert geopackage to an image')
    group1 = parser.add_mutually_exclusive_group()
    group1.add_argument('--group1-infile')
    group1.add_argument('--group1-table')
    parser.add_argument('-o', '--outfile', metavar='<file>')
    parser.add_argument(
            '--size', type=plt_size, help='Figure size in mm (WWxHH)')
    parser.add_argument( '--clip', type=float, nargs=4, metavar=BOUNDS)

    group2 = parser.add_mutually_exclusive_group()
    group2.add_argument('--group2-infile', type=str)
    group2.add_argument('--group2-table', type=str)

    group3 = parser.add_mutually_exclusive_group()
    group3.add_argument('--group3-infile', type=str)
    group3.add_argument('--group3-table', type=str)
    return parser.parse_args()


def read_layer(maybe_table, maybe_file):
    if maybe_table:
        conn = psycopg2.connect("host=127.0.0.1 dbname=osm user=osm")
        sql = "SELECT geom FROM %s" % maybe_table
        return geopandas.read_postgis(sql, con=conn, geom_col='geom')
    elif maybe_file:
        return geopandas.read_file(maybe_file)


def main():
    args = parse_args()
    group1 = read_layer(args.group1_table, args.group1_infile)
    group2 = read_layer(args.group2_table, args.group2_infile)
    group3 = read_layer(args.group3_table, args.group3_infile)

    rc('text', usetex=True)
    fig, ax = plt.subplots()
    if args.size:
        fig.set_size_inches(args.size)
    if c := args.clip:
        ax.set_xlim(left=c[0], right=c[2])
        ax.set_ylim(bottom=c[1], top=c[3])

    if group1 is not None:
        group1.plot(ax=ax, color=PURPLE)
    if group2 is not None:
        group2.plot(ax=ax, color=ORANGE)
    if group3 is not None:
        group3.plot(ax=ax, color=GREEN)

    ax.axis('off')
    ax.margins(0, 0)
    fig.tight_layout(0)
    if args.outfile:
        fig.savefig(args.outfile, bbox_inches=0, dpi=600)
    else:
        plt.show()


if __name__ == '__main__':
    main()
