#!/usr/bin/awk -f

BEGIN {
    print "DROP TABLE IF EXISTS rivers;";
    printf "CREATE TABLE rivers AS SELECT name,way FROM planet_osm_line WHERE "
    for (i = 1; i < ARGC; i++) {
        printf "name='%s'", ARGV[i]
        if (i != ARGC - 1)
            printf " OR ";
    }
    print ";";
}
