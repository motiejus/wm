#!/usr/bin/python3
import argparse
import geopandas
import psycopg2
import matplotlib.pyplot as plt
from matplotlib import rc

CMAP = 'tab20c'  # 'Set3'  # is nice too
PSQL_CREDS = "host=127.0.0.1 dbname=osm user=osm password=osm"
COLORS = {
    'black': '#000000',
    'green': '#1b9e77',
    'orange': '#d95f02',
    'purple': '#7570b3',
}
# see `NOTICE` in the LaTeX document; this is the width of the main text block.
TEXTWIDTH_CM = 12.12364


def color(string):
    if not string:
        string = 'black'
    return COLORS[string]


def inch(cm):
    return cm / 2.54


def parse_args():
    kwcolor = {'type': color, 'default': 'black'}

    parser = argparse.ArgumentParser(
            description='Convert a geometry to an image')
    parser.add_argument('--group1-select')
    parser.add_argument('--group1-linestyle')
    parser.add_argument('--group1-color', **kwcolor)

    parser.add_argument('--group2-select')
    parser.add_argument('--group2-linestyle')
    parser.add_argument('--group2-color', **kwcolor)

    parser.add_argument('--group3-select')
    parser.add_argument('--group3-linestyle')
    parser.add_argument('--group3-color', **kwcolor)

    parser.add_argument('--widthdiv',
                        default=1, type=float, help='Width divisor')
    parser.add_argument('--quadrant', type=int, choices=(1, 2, 3, 4))

    parser.add_argument('-o', '--outfile', metavar='<file>')
    return parser.parse_args()


def read_layer(select, width, maybe_quadrant):
    if not select:
        return
    way = "way"
    if maybe_quadrant:
        way = "wm_quadrant(way, {})".format(maybe_quadrant)

    conn = psycopg2.connect(PSQL_CREDS)
    sql = "SELECT {way} as way1 FROM {select}".format(way=way, select=select)
    return geopandas.read_postgis(sql, con=conn, geom_col='way1')


def plot_args(geom, color, maybe_linestyle):
    if geom is None:
        return

    # polygons either have fillings or lines
    if geom.geom_type[0] == 'Polygon':
        if maybe_linestyle:
            return {
                'edgecolor': 'black',
                'linestyle': maybe_linestyle,
                'color': (0, 0, 0, 0),
            }
        else:
            return {'cmap': CMAP, 'alpha': .25}

    r = {'color': color}
    if maybe_linestyle == 'invisible':
        r['color'] = (0, 0, 0, 0)
    elif maybe_linestyle:
        r['linestyle'] = maybe_linestyle
    return r


def main():
    args = parse_args()
    width = TEXTWIDTH_CM / args.widthdiv
    group1 = read_layer(args.group1_select, width, args.quadrant)
    group2 = read_layer(args.group2_select, width, args.quadrant)
    group3 = read_layer(args.group3_select, width, args.quadrant)
    c1 = plot_args(group1, args.group1_color, args.group1_linestyle)
    c2 = plot_args(group2, args.group2_color, args.group2_linestyle)
    c3 = plot_args(group3, args.group3_color, args.group3_linestyle)

    rc('text', usetex=True)
    fig, ax = plt.subplots()
    fig.set_figwidth(inch(width))

    group1 is not None and group1.plot(ax=ax, linewidth=.75, **c1)
    group2 is not None and group2.plot(ax=ax, linewidth=.75, **c2)
    group3 is not None and group3.plot(ax=ax, linewidth=.75, **c3)

    ax.axis('off')
    ax.margins(0, 0)
    if args.outfile:
        fig.savefig(args.outfile, bbox_inches='tight', dpi=600)
    else:
        plt.show()


if __name__ == '__main__':
    main()
