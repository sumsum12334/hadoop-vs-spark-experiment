#!/usr/bin/env python3
"""W2 Top-N (N=100) after word count — PySpark."""
import argparse
import re
from pyspark.sql import SparkSession

WORD = re.compile(r"[^a-z0-9]+")
N = 100

def tokenize(line: str):
    for t in WORD.split(line.lower()):
        if t:
            yield t

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--input", required=True)
    p.add_argument("--output", required=True)
    p.add_argument("--n", type=int, default=N)
    args = p.parse_args()

    spark = (
        SparkSession.builder.appName("W2-TopN")
        .config("spark.hadoop.fs.defaultFS", "hdfs://namenode:9000")
        .getOrCreate()
    )
    sc = spark.sparkContext
    sc.setLogLevel("WARN")

    counts = (
        sc.textFile(args.input)
        .flatMap(tokenize)
        .map(lambda w: (w, 1))
        .reduceByKey(lambda a, b: a + b)
    )
    top = counts.takeOrdered(args.n, key=lambda kv: (-kv[1], kv[0]))
    sc.parallelize([f"{w}\t{c}" for w, c in top], 1).saveAsTextFile(args.output)
    spark.stop()

if __name__ == "__main__":
    main()
