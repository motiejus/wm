#!/usr/bin/awk -f

BEGIN {
  FS="[() ]"
}

/small_angle constant real default radians/ {
  if(d) {
    exit 1
  } else {
    printf ("\\newcommand{\\smallAngle}{\\frac{\\pi}{%d}}\n",180/$8);
    d=1
  }
}

END{
  if(!d){
    exit 1
  }
}
