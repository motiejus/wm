#!/usr/bin/awk -f

BEGIN { FS="[(); ]" }

/small_angle constant real default radians/ {
  x1 += 1;
  d1 = sprintf("\\newcommand{\\smallAngle}{$%d^\\circ$}",$8);
}
/isolation_threshold constant real default / {
  x2 += 1;
  d2 = sprintf("\\newcommand{\\isolationThreshold}{%.1f}",$7);
}
/scale constant float default / {
  x3 += 1;
  d3 = sprintf("\\newcommand{\\exaggerationEnthusiasm}{%.1f}",$7);
}

END{
  if(x1 == 1 && x2 == 1 && x3 == 1) {
    print d1 > "vars.inc.tex"
    print d2 >> "vars.inc.tex"
    print d3 >> "vars.inc.tex"
  } else {
    exit 1
  }
}
