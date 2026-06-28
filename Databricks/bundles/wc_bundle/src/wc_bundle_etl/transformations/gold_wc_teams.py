"""Silver → Gold: rankings and country-level summaries for World Cup teams."""
from databricks.sdk.runtime import spark
from pyspark import pipelines as dp
from pyspark.sql import functions as F
from pyspark.sql.window import Window


@dp.table(
    comment="World Cup teams ranked by offensive and possession metrics.",
)
def wc_teams_gold_rankings():
    silver_df = spark.read.table("wc_teams_silver")

    overall_window = Window.orderBy(
        F.col("goals_assists_per90").desc_nulls_last(),
        F.col("goals_per90").desc_nulls_last(),
    )
    country_window = Window.partitionBy("team_country").orderBy(
        F.col("goals_assists_per90").desc_nulls_last(),
        F.col("goals_per90").desc_nulls_last(),
    )

    return (
        silver_df
        .withColumn("overall_rank", F.row_number().over(overall_window))
        .withColumn("country_rank", F.row_number().over(country_window))
        .withColumn(
            "offensive_tier",
            F.when(F.col("goals_assists_per90") >= 2.0, "elite")
            .when(F.col("goals_assists_per90") >= 1.5, "strong")
            .when(F.col("goals_assists_per90") >= 1.0, "average")
            .otherwise("developing"),
        )
        .withColumn("_refreshed_at", F.current_timestamp())
    )


@dp.table(
    comment="Country-level rollups of World Cup team performance.",
)
def wc_teams_gold_country_summary():
    silver_df = spark.read.table("wc_teams_silver")

    return (
        silver_df
        .groupBy("team_country")
        .agg(
            F.count("*").alias("team_count"),
            F.sum("goals").alias("total_goals"),
            F.sum("assists").alias("total_assists"),
            F.sum("goals_assists").alias("total_goal_involvements"),
            F.avg("possession").alias("avg_possession"),
            F.avg("goals_per90").alias("avg_goals_per90"),
            F.avg("assists_per90").alias("avg_assists_per90"),
            F.avg("goals_assists_per90").alias("avg_goals_assists_per90"),
            F.sum("cards_yellow").alias("total_yellow_cards"),
            F.sum("cards_red").alias("total_red_cards"),
            F.max("goals").alias("max_team_goals"),
        )
        .withColumn("_refreshed_at", F.current_timestamp())
    )
