#!/usr/bin/python3
import argparse
import geopandas
import psycopg2
import matplotlib.pyplot as plt

from matplotlib import rc

# CMAP = 'Set3'  # is nice too
CMAP = 'tab20c'

BOUNDS = ('xmin', 'ymin', 'xmax', 'ymax')
INCH_MM = 25.4
INCH_CM = INCH_MM / 10
BLACK, GREEN, ORANGE, PURPLE = '#000000', '#1b9e77', '#d95f02', '#7570b3'
PSQL_CREDS = "host=127.0.0.1 dbname=osm user=osm password=osm"

# see `NOTICE` in the LaTeX document; this is the width of the main text block.
TEXTWIDTH_CM = 12.12364
TEXTWIDTH_INCH = TEXTWIDTH_CM * 10 / INCH_MM

SCALES = {
    "GDR10": 10000,
    "GDR50": 50000,
    "GDR250": 250000,
}


def wm_clip(string):
    if not string:
        return None
    name, gdr = string.split(":")
    if scale := SCALES.get(gdr):
        return name, scale
    scales = ",".join(SCALES.keys())
    raise argparse.ArgumentTypeError("invalid scale. Expected %s" % scales)


def parse_args():
    parser = argparse.ArgumentParser(
            description='Convert geopackage to an image')
    parser.add_argument('--group1-select', required=True)
    parser.add_argument('--group1-cmap', type=bool)
    parser.add_argument('--group1-linestyle')

    parser.add_argument('--group2-select')
    parser.add_argument('--group2-cmap', type=bool)
    parser.add_argument('--group2-linestyle')

    parser.add_argument('--group3-select')
    parser.add_argument('--group3-cmap', type=bool)
    parser.add_argument('--group3-linestyle')

    parser.add_argument('--wmclip',
                        type=wm_clip,
                        help="Clip for scale. E.g. salcia-visincia:GDR10",
                        )
    parser.add_argument('--widthdiv',
                        default=1, type=float, help='Width divisor')

    parser.add_argument('-o', '--outfile', metavar='<file>')
    return parser.parse_args()


def read_layer(select, width_in, maybe_wmclip):
    if not select:
        return
    way = "way"
    if maybe_wmclip:
        name, scale = maybe_wmclip
        way = "st_intersection(way, wm_bbox('{name}', {scale}, {width}))".format(
                name=name,
                scale=scale,
                width=width_in * INCH_CM,
        )
    conn = psycopg2.connect(PSQL_CREDS)
    sql = "SELECT {way} as way1 FROM {select}".format(way=way, select=select)
    print("sql: %s" % sql)
    return geopandas.read_postgis(sql, con=conn, geom_col='way1')


def plot_args(color, maybe_cmap, maybe_linestyle):
    if maybe_cmap:
        r = {'cmap': CMAP}
    else:
        r = {'color': color}
    if maybe_linestyle == 'invisible':
        r['color'] = (0, 0, 0, 0)
    elif maybe_linestyle:
        r['linestyle'] = maybe_linestyle
    return r


def main():
    args = parse_args()
    width = TEXTWIDTH_INCH / args.widthdiv
    group1 = read_layer(args.group1_select, width, args.wmclip)
    group2 = read_layer(args.group2_select, width, args.wmclip)
    group3 = read_layer(args.group3_select, width, args.wmclip)
    c1 = plot_args(BLACK, args.group1_cmap, args.group1_linestyle)
    c2 = plot_args(ORANGE, args.group2_cmap, args.group2_linestyle)
    c3 = plot_args(GREEN, args.group3_cmap, args.group3_linestyle)

    rc('text', usetex=True)
    fig, ax = plt.subplots()
    #fig.set_figwidth(width)

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
