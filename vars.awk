#!/usr/bin/awk -f

BEGIN { FS="[() ]" }

/small_angle constant real default radians/ {
  if(d) {
    exit 1
  } else {
    d = sprintf("\\newcommand{\\smallAngle}{\\frac{\\pi}{%d}}\n",180/$8);
  }
}

END{
  if(d) {
    print d > "vars.inc.tex"
  } else {
    exit 1
  }
}
