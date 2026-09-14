#!/usr/bin/env python3
"""W1 WordCount — PySpark (semantic parity with MR streaming)."""
import argparse
import re
from pyspark.sql import SparkSession

WORD = re.compile(r"[^a-z0-9]+")

def tokenize(line: str):
    for t in WORD.split(line.lower()):
        if t:
            yield t

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--input", required=True)
    p.add_argument("--output", required=True)
    args = p.parse_args()

    spark = (
        SparkSession.builder.appName("W1-WordCount")
        .config("spark.hadoop.fs.defaultFS", "hdfs://namenode:9000")
        .getOrCreate()
    )
    sc = spark.sparkContext
    sc.setLogLevel("WARN")

    rdd = sc.textFile(args.input)
    counts = (
        rdd.flatMap(tokenize)
        .map(lambda w: (w, 1))
        .reduceByKey(lambda a, b: a + b)
    )
    # Save as text: word\\tcount
    counts.map(lambda kv: f"{kv[0]}\t{kv[1]}").saveAsTextFile(args.output)
    spark.stop()

if __name__ == "__main__":
    main()
