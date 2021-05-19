#!/usr/bin/python3
import argparse
import geopandas
import psycopg2
import numpy as np
import matplotlib.pyplot as plt

from matplotlib import rc

INCH = 25.4  # mm
BOUNDS = ('xmin', 'ymin', 'xmax', 'ymax')
GREEN, ORANGE, PURPLE = '#1b9e77', '#d95f02', '#7570b3'
PSQL_CREDS="host=127.0.0.1 dbname=osm user=osm password=osm"

def arrowplot(axes, x, y, narrs=30, dspace=0.1, direc='pos', \
                          hl=0.1, hw=5, c='black'):
    ''' narrs  :  Number of arrows that will be drawn along the curve

        dspace :  Shift the position of the arrows along the curve.
                  Should be between 0. and 1.

        direc  :  can be 'pos' or 'neg' to select direction of the arrows

        hl     :  length of the arrow head

        hw     :  width of the arrow head

        c      :  color of the edge and face of the arrow head
    https://stackoverflow.com/questions/8247973
    '''

    # r is the distance spanned between pairs of points
    r = [0]
    for i in range(1,len(x)):
        dx = x[i]-x[i-1]
        dy = y[i]-y[i-1]
        r.append(np.sqrt(dx*dx+dy*dy))
    r = np.array(r)

    # rtot is a cumulative sum of r, it's used to save time
    rtot = []
    for i in range(len(r)):
        rtot.append(r[0:i].sum())
    rtot.append(r.sum())

    # based on narrs set the arrow spacing
    aspace = r.sum() / narrs

    if direc is 'neg':
        dspace = -1.*abs(dspace)
    else:
        dspace = abs(dspace)

    arrowData = [] # will hold tuples of x,y,theta for each arrow
    arrowPos = aspace*(dspace) # current point on walk along data
                                 # could set arrowPos to 0 if you want
                                 # an arrow at the beginning of the curve

    ndrawn = 0
    rcount = 1
    while arrowPos < r.sum() and ndrawn < narrs:
        x1,x2 = x[rcount-1],x[rcount]
        y1,y2 = y[rcount-1],y[rcount]
        da = arrowPos-rtot[rcount]
        theta = np.arctan2((x2-x1),(y2-y1))
        ax = np.sin(theta)*da+x1
        ay = np.cos(theta)*da+y1
        arrowData.append((ax,ay,theta))
        ndrawn += 1
        arrowPos+=aspace
        while arrowPos > rtot[rcount+1]:
            rcount+=1
            if arrowPos > rtot[-1]:
                break

    # could be done in above block if you want
    for ax,ay,theta in arrowData:
        # use aspace as a guide for size and length of things
        # scaling factors were chosen by experimenting a bit

        dx0 = np.sin(theta)*hl/2. + ax
        dy0 = np.cos(theta)*hl/2. + ay
        dx1 = -1.*np.sin(theta)*hl/2. + ax
        dy1 = -1.*np.cos(theta)*hl/2. + ay

        if direc is 'neg' :
          ax0 = dx0
          ay0 = dy0
          ax1 = dx1
          ay1 = dy1
        else:
          ax0 = dx1
          ay0 = dy1
          ax1 = dx0
          ay1 = dy0

        axes.annotate('', xy=(ax0, ay0), xycoords='data',
                xytext=(ax1, ay1), textcoords='data',
                arrowprops=dict( headwidth=hw, frac=1., ec=c, fc=c))

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
    parser.add_argument('--group1-table')
    parser.add_argument('--group1-where')
    parser.add_argument('--group1-cmap', type=bool)

    parser.add_argument('--group2-table')
    parser.add_argument('--group2-where')
    parser.add_argument('--group2-cmap', type=bool)

    parser.add_argument('--group3-table')
    parser.add_argument('--group3-where')
    parser.add_argument('--group3-cmap', type=bool)

    parser.add_argument('-o', '--outfile', metavar='<file>')
    parser.add_argument(
            '--size', type=plt_size, help='Figure size in mm (WWxHH)')
    parser.add_argument( '--clip', type=float, nargs=4, metavar=BOUNDS)
    return parser.parse_args()


def read_layer(table, maybe_where=None):
    if not table:
        return
    conn = psycopg2.connect(PSQL_CREDS)
    sql = "SELECT way FROM %s" % table
    if maybe_where:
        sql += " WHERE %s" % maybe_where
    return geopandas.read_postgis(sql, con=conn, geom_col='way')

def add_lines(ax, group):
    for g in group.to_dict()['way'].values():
        for geom in getattr(g, 'geoms', [g]):
            x, y = zip(*geom.coords)
            narrs = geom.length / 25
            arrowplot(ax, np.array(x), np.array(y), narrs=narrs)

def main():
    args = parse_args()
    group1 = read_layer(args.group1_table, args.group1_where)
    group2 = read_layer(args.group2_table, args.group2_where)
    group3 = read_layer(args.group3_table, args.group3_where)

    rc('text', usetex=True)
    fig, ax = plt.subplots()
    if args.size:
        fig.set_size_inches(args.size)
    if c := args.clip:
        ax.set_xlim(left=c[0], right=c[2])
        ax.set_ylim(bottom=c[1], top=c[3])

    c1 = {'cmap': 'coolwarm'} if args.group1_cmap else {'color': ORANGE}
    c2 = {'cmap': 'coolwarm'} if args.group2_cmap else {'color': PURPLE}
    c3 = {'cmap': 'coolwarm'} if args.group3_cmap else {'color': GREEN}

    if group1 is not None:
        group1.plot(ax=ax, **c1)
        #args.group1_arrows and add_lines(ax, group1)
    if group2 is not None:
        group2.plot(ax=ax, **c2)
    if group3 is not None:
        group3.plot(ax=ax, **c3)

    ax.axis('off')
    ax.margins(0, 0)
    #fig.tight_layout(0)
    if args.outfile:
        fig.savefig(args.outfile, bbox_inches=0, dpi=600)
    else:
        plt.show()


if __name__ == '__main__':
    main()
