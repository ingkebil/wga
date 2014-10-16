#!/bin/awk -f

/>/ {
    seqname=substr($0, 2, length($0)-1)
}
/^>/ {
    if (seqlen) {
        print seqname":0-"seqlen
        seqlen=0
        next
    }
}
{
    seqlen = seqlen + length($0)
}
END {
    print seqname,":0-",seqlen
}
