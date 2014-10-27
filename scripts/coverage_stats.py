#!/usr/bin/env python
# encoding: utf-8

from __future__ import print_function
from __future__ import division    
import sys

def read_ref(filename):
    """Reads in a FASTA file and returns a dict with chrom: length

    Args:
        filename (str): The name of the FASTA file

    Returns (dict): { chrom: length }

    """
    with open(filename) as handle:
        lines = (line.strip() for line in handle)
        length_of={} # chrom_name => lenght
        chrom_name=''
        chrom_len=0
        for line in lines:
            if (line[0] == '>'):
                if (chrom_name):
                    length_of[chrom_name] = chrom_len
                    chrom_len=0
                chrom_name=line[1:]
            else:
                chrom_len += len(line)

        length_of[chrom_name]=chrom_len

    return length_of

def main(argv):
    length_of = read_ref(argv[1]) # calc the lengths of the chroms of the reference sequence
    lines = open(argv[0], 'r').readlines() 

    #coverages = ( 5, 10, 20, 50, 100, 150, 200, 250, 500, 1000, 2000, 5000 )
    coverages = (10, 100, 1000)

    stats = {} # chrom_name => { coverage => count }}
    for line in lines:
        line = line.split("\t")
        for coverage in coverages:
            if int(line[3]) >= coverage:
                try:
                    stats[ line[0] ][ coverage ] += 1
                except KeyError:
                    stats[ line[0] ] = dict(zip(coverages,[0] * len(coverages)))
        # DEBUG
        #if int(line[3]) > 100:
        #    break
        # DEBUG

    print("Chrom\tLength")
    for coverage in coverages:
        print("%s\t" % coverage, end="")
        print("%%\t", end="")
    print()
    for chrom in sorted(stats):
        print("%s\t" % chrom, end="")                   # chrom name
#        print(length_of[chrom])                         # chrom len
        for stat in sorted(stats[chrom]):
            print("%d\t" % stats[chrom][stat], end="")  
            print("%2.2f\t" % (stats[chrom][stat]/length_of[chrom]*100), end="")  
        print()

if __name__ == '__main__':
    main(sys.argv[1:])
