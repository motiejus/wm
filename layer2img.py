#!/usr/bin/python3
"""
Convert PostGIS geometries to an image. To scale.

Accepts a few geometry fine-tuning parameters.
"""

import argparse
import geopandas
import psycopg2
from matplotlib import rc
import matplotlib.pyplot as plt

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

QUADRANTS = {'tr':1, 'br':2, 'bl':3, 'tl':4}

def color(string):
    return COLORS[string if string else 'black']


def inch(cm):
    return cm / 2.54


def parse_args():
    kwcolor = {'type': color, 'default': 'black'}
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--g1-select')
    parser.add_argument('--g1-linestyle')
    parser.add_argument('--g1-label')
    parser.add_argument('--g1-color', **kwcolor)
    parser.add_argument('--g2-select')
    parser.add_argument('--g2-linestyle')
    parser.add_argument('--g2-label')
    parser.add_argument('--g2-color', **kwcolor)
    parser.add_argument('--g3-select')
    parser.add_argument('--g3-linestyle')
    parser.add_argument('--g3-label')
    parser.add_argument('--g3-color', **kwcolor)
    parser.add_argument('--legend',
            help="Legend location, following matplotlib rules", default='best')
    parser.add_argument('--widthdiv', default=1, type=float,
            help="Divide the width by this number "
            "(useful when two images are laid horizontally "
            "in the resulting file")
    parser.add_argument('--quadrant', choices=QUADRANTS.keys(),
            help="Image is comprised of 4 quadrants. This variable, "
            "when non-empty, will clip and return the requested quadrant")
    parser.add_argument('--outfile', metavar='<file>',
            help="If unset, displayed on the screen")
    return parser.parse_args()


def read_layer(select, width, maybe_quadrant):
    if not select:
        return
    way = "way"
    if maybe_quadrant:
        way = "wm_quadrant(way, {})".format(QUADRANTS[maybe_quadrant])

    conn = psycopg2.connect(PSQL_CREDS)
    sql = "SELECT {way} as way1 FROM {select}".format(way=way, select=select)

    return geopandas.read_postgis(sql, con=conn, geom_col='way1')


def plot_args(geom, color, maybe_linestyle, maybe_label):
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

    if maybe_label:
        r['label'] = '\\normalfont %s' % maybe_label

    return r


def main():
    args = parse_args()
    width = TEXTWIDTH_CM / args.widthdiv
    g1 = read_layer(args.g1_select, width, args.quadrant)
    g2 = read_layer(args.g2_select, width, args.quadrant)
    g3 = read_layer(args.g3_select, width, args.quadrant)
    c1 = plot_args(g1, args.g1_color, args.g1_linestyle, args.g1_label)
    c2 = plot_args(g2, args.g2_color, args.g2_linestyle, args.g2_label)
    c3 = plot_args(g3, args.g3_color, args.g3_linestyle, args.g3_label)

    rc('text', usetex=True)
    rc('text.latex', preamble='\\usepackage{numprint}\n')
    fig, ax = plt.subplots(constrained_layout=True)
    fig.set_figwidth(inch(width))

    g1 is not None and g1.plot(ax=ax, linewidth=.75, **c1)
    g2 is not None and g2.plot(ax=ax, linewidth=.75, **c2)
    g3 is not None and g3.plot(ax=ax, linewidth=.75, **c3)

    ax.legend(loc=args.legend, frameon=False)
    ax.axis('off')
    ax.margins(0, 0)
    if args.outfile:
        fig.savefig(args.outfile, bbox_inches='tight', dpi=600)
    else:
        plt.show()


if __name__ == '__main__':
    main()
