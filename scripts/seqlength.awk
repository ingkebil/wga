#!/bin/awk -f

/>/ {
    if (seqlen) {
        printf "%s %d %s\n", seqname, 0, seqlen
        seqlen=0
    }
    seqname=substr($0, 2, length($0)-1)
    next
}
{
    seqlen = seqlen + length($0)
}
END {
    printf "%s %d %s\n", seqname, 0, seqlen
}
