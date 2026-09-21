#!/usr/bin/env python3
"""W3 PageRank-lite K=5 — memory-friendlier Spark version.

Keeps K=5 / damping=0.85 semantics, but avoids groupByKey().mapValues(list).cache()
on string adjacency lists (that OOM'd on size_L under 16g). Uses int node ids,
edge RDD persist MEMORY_AND_DISK, and join-based contributions.
"""
import argparse
from pyspark import StorageLevel
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
        .config("spark.serializer", "org.apache.spark.serializer.KryoSerializer")
        .getOrCreate()
    )
    sc = spark.sparkContext
    sc.setLogLevel("WARN")

    # Parse as ints (generator uses 0..n_nodes-1 numeric ids)
    edges = (
        sc.textFile(args.input)
        .map(lambda line: line.strip())
        .filter(lambda line: line and not line.startswith("#"))
        .map(lambda line: line.split())
        .filter(lambda parts: len(parts) >= 2)
        .map(lambda parts: (int(parts[0]), int(parts[1])))
        .persist(StorageLevel.MEMORY_AND_DISK)
    )

    # out-degree; dangling nodes handled via missing join side
    outdeg = (
        edges.map(lambda e: (e[0], 1))
        .reduceByKey(lambda a, b: a + b)
        .persist(StorageLevel.MEMORY_AND_DISK)
    )

    nodes = (
        edges.flatMap(lambda e: [e[0], e[1]])
        .distinct()
        .persist(StorageLevel.MEMORY_AND_DISK)
    )
    n = nodes.count()
    if n == 0:
        raise SystemExit("empty graph")

    # Materialize edge count once so lineage stays shallow across iterations
    _ = edges.count()
    _ = outdeg.count()

    ranks = nodes.map(lambda node: (node, 1.0 / n))

    for _ in range(args.iterations):
        # (src, (rank, deg)) -> (src, rank/deg)
        rank_over_deg = (
            ranks.join(outdeg)
            .mapValues(lambda rd: (rd[0] / rd[1]) if rd[1] else 0.0)
        )
        # edges (src,dst) join (src, contrib) -> (dst, contrib)
        contribs = (
            edges.join(rank_over_deg)
            .map(lambda x: (x[1][0], x[1][1]))
            .reduceByKey(lambda a, b: a + b)
        )
        # nodes with no inbound contrib get 0 from reduce; leftOuter join back
        ranks = (
            nodes.map(lambda node: (node, 0.0))
            .leftOuterJoin(contribs)
            .mapValues(
                lambda z: (1.0 - args.damping) / n
                + args.damping * (z[1] if z[1] is not None else 0.0)
            )
        )

    ranks.map(lambda kv: f"{kv[0]}\t{kv[1]:.10f}").saveAsTextFile(args.output)
    edges.unpersist()
    outdeg.unpersist()
    nodes.unpersist()
    spark.stop()


if __name__ == "__main__":
    main()