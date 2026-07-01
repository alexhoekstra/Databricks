"""Bronze → Silver: clean and enrich World Cup team statistics."""
from databricks.sdk.runtime import spark
from pyspark import pipelines as dp
from pyspark.sql import functions as F


def _bronze_table_name() -> str:
    catalog = spark.conf.get("bronze_catalog", "main")
    schema = spark.conf.get("bronze_schema", "wc")
    table = spark.conf.get("bronze_table", "wc_teams_bronze")
    return f"{catalog}.{schema}.{table}"


@dp.table(
    comment="Cleaned World Cup team statistics sourced from wc_teams_bronze.",
)
def wc_teams_silver():
    bronze_df = spark.read.table(_bronze_table_name())

    silver_df = (
        bronze_df
        .withColumn("team", F.trim(F.col("team")))
        .withColumn("team_country", F.trim(F.col("team_country")))
        .withColumn("players_used", F.col("players_used").cast("int"))
        .withColumn("avg_age", F.col("avg_age").cast("double"))
        .withColumn("possession", F.col("possession").cast("double"))
        .withColumn("games", F.col("games").cast("int"))
        .withColumn("games_starts", F.col("games_starts").cast("int"))
        .withColumn("minutes", F.col("minutes").cast("int"))
        .withColumn("minutes_90s", F.col("minutes_90s").cast("double"))
        .withColumn("goals", F.col("goals").cast("int"))
        .withColumn("assists", F.col("assists").cast("int"))
        .withColumn("goals_assists", F.col("goals_assists").cast("int"))
        .withColumn("goals_pens", F.col("goals_pens").cast("int"))
        .withColumn("pens_made", F.col("pens_made").cast("int"))
        .withColumn("pens_att", F.col("pens_att").cast("int"))
        .withColumn("cards_yellow", F.col("cards_yellow").cast("int"))
        .withColumn("cards_red", F.col("cards_red").cast("int"))
        .withColumn("goals_per90", F.col("goals_per90").cast("double"))
        .withColumn("assists_per90", F.col("assists_per90").cast("double"))
        .withColumn("goals_assists_per90", F.col("goals_assists_per90").cast("double"))
        .withColumn("cards_total", F.col("cards_yellow") + F.col("cards_red"))
        .withColumn(
            "pen_conversion_rate",
            F.when(F.col("pens_att") > 0, F.col("pens_made") / F.col("pens_att")),
        )
        .withColumn(
            "goal_involvement_per_game",
            F.when(F.col("games") > 0, F.col("goals_assists") / F.col("games")),
        )
        .withColumn(
            "minutes_per_game",
            F.when(F.col("games") > 0, F.col("minutes") / F.col("games")),
        )
        .withColumn("_processed_at", F.current_timestamp())
        .filter(F.col("team").isNotNull() & (F.length("team") > 0))
    )

    return silver_df
