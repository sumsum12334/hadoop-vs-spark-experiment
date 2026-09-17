#!/usr/bin/env python3
"""W3 PageRank-lite K=5 with Spark cache on the link graph."""
import argparse
from pyspark.sql import SparkSession

DAMPING = 0.85
K = 5

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--input", required=True, help="HDFS path to edge list (src dst)")
    p.add_argument("--output", required=True)
    p.add_argument("--iterations", type=int, default=K)
    p.add_argument("--damping", type=float, default=DAMPING)
    args = p.parse_args()

    spark = (
        SparkSession.builder.appName("W3-PageRank-lite")
        .config("spark.hadoop.fs.defaultFS", "hdfs://namenode:9000")
        .getOrCreate()
    )
    sc = spark.sparkContext
    sc.setLogLevel("WARN")

    edges = (
        sc.textFile(args.input)
        .map(lambda line: line.strip())
        .filter(lambda line: line and not line.startswith("#"))
        .map(lambda line: line.split())
        .filter(lambda parts: len(parts) >= 2)
        .map(lambda parts: (parts[0], parts[1]))
    )

    # adjacency lists; cache — key Spark advantage for iterative W3
    links = edges.groupByKey().mapValues(list).cache()
    nodes = edges.flatMap(lambda e: [e[0], e[1]]).distinct().cache()
    n = nodes.count()
    if n == 0:
        raise SystemExit("empty graph")

    ranks = nodes.map(lambda node: (node, 1.0 / n))

    for _ in range(args.iterations):
        # contribs
        contribs = links.join(ranks).flatMap(
            lambda nd: (
                [(d, nd[1][1] / len(nd[1][0])) for d in nd[1][0]]
                if nd[1][0]
                else [(nd[0], nd[1][1])]  # dangling mass stays (simplified)
            )
        )
        ranks = contribs.reduceByKey(lambda a, b: a + b).mapValues(
            lambda sum_c: (1.0 - args.damping) / n + args.damping * sum_c
        )

    ranks.map(lambda kv: f"{kv[0]}\t{kv[1]:.10f}").saveAsTextFile(args.output)
    links.unpersist()
    nodes.unpersist()
    spark.stop()

if __name__ == "__main__":
    main()
