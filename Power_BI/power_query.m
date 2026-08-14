// =============================================================================
// Customer Shopping Behaviour Analysis — Power Query (M) scripts
//
// Two loading options below. Use OPTION A (MySQL) — it demonstrates the full
// Python -> SQL -> Power BI pipeline, which is the point of the project.
// OPTION B (CSV) is the fallback if the MySQL connector gives you trouble.
//
// To use: Home > Transform data > New Source > Blank Query > Advanced Editor,
// then paste one query at a time and rename it to match the table name.
// =============================================================================


// -----------------------------------------------------------------------------
// OPTION A — MySQL (recommended)
// -----------------------------------------------------------------------------
// Requires the MySQL Connector/NET installed on your machine. If Power BI
// prompts for it, install from dev.mysql.com then restart Power BI Desktop.
// Credentials are entered once in the Power BI auth prompt, NOT stored here.

// --- Query name: fact_purchase ---
let
    Source = MySQL.Database("localhost:3306", "customer_behaviour"),
    Data = Source{[Schema="customer_behaviour", Item="fact_purchase"]}[Data],
    TypedData = Table.TransformColumnTypes(
        Data,
        {
            {"purchase_key", Int64.Type},
            {"customer_id", Int64.Type},
            {"item_key", Int64.Type},
            {"location_key", Int64.Type},
            {"season", type text},
            {"size", type text},
            {"color", type text},
            {"purchase_amount", Int64.Type},
            {"review_rating", type number},
            {"review_rating_imputed", Int64.Type},
            {"received_discount", Int64.Type},
            {"shipping_type", type text},
            {"payment_method", type text},
            {"purchase_frequency_days", Int64.Type},
            {"purchases_per_year", type number},
            {"est_annual_value", type number}
        }
    )
in
    TypedData


// --- Query name: dim_customer ---
let
    Source = MySQL.Database("localhost:3306", "customer_behaviour"),
    Data = Source{[Schema="customer_behaviour", Item="dim_customer"]}[Data],
    TypedData = Table.TransformColumnTypes(
        Data,
        {
            {"customer_id", Int64.Type},
            {"age", Int64.Type},
            {"age_band", type text},
            {"gender", type text},
            {"loyalty_tier", type text},
            {"segment", type text},
            {"is_subscriber", Int64.Type},
            {"previous_purchases", Int64.Type}
        }
    )
in
    TypedData


// --- Query name: dim_item ---
let
    Source = MySQL.Database("localhost:3306", "customer_behaviour"),
    Data = Source{[Schema="customer_behaviour", Item="dim_item"]}[Data],
    TypedData = Table.TransformColumnTypes(
        Data,
        {
            {"item_key", Int64.Type},
            {"item_purchased", type text},
            {"category", type text}
        }
    )
in
    TypedData


// --- Query name: dim_location ---
let
    Source = MySQL.Database("localhost:3306", "customer_behaviour"),
    Data = Source{[Schema="customer_behaviour", Item="dim_location"]}[Data],
    TypedData = Table.TransformColumnTypes(
        Data,
        {
            {"location_key", Int64.Type},
            {"location", type text}
        }
    )
in
    TypedData


// -----------------------------------------------------------------------------
// OPTION B — CSV fallback
// -----------------------------------------------------------------------------
// Point DataFolder at your data/processed directory. Using a single parameter
// means the whole model repoints in one edit if the folder moves.
//
// Create the parameter first: Manage Parameters > New > Name "DataFolder",
// Type Text, Current Value: C:\Users\<you>\Downloads\data\processed

// --- Query name: fact_purchase ---
let
    Source = Csv.Document(
        File.Contents(DataFolder & "\fact_purchase.csv"),
        [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]
    ),
    Promoted = Table.PromoteHeaders(Source, [PromoteAllScalars = true]),
    TypedData = Table.TransformColumnTypes(
        Promoted,
        {
            {"purchase_key", Int64.Type},
            {"customer_id", Int64.Type},
            {"item_key", Int64.Type},
            {"location_key", Int64.Type},
            {"season", type text},
            {"size", type text},
            {"color", type text},
            {"purchase_amount", Int64.Type},
            {"review_rating", type number},
            {"review_rating_imputed", type logical},
            {"received_discount", type logical},
            {"shipping_type", type text},
            {"payment_method", type text},
            {"purchase_frequency_days", Int64.Type},
            {"purchases_per_year", type number},
            {"est_annual_value", type number}
        }
    )
in
    TypedData

// Repeat the same pattern for dim_customer.csv, dim_item.csv, dim_location.csv,
// changing only the file name and the column type list.


// -----------------------------------------------------------------------------
// SORT-ORDER HELPER — age_band
// -----------------------------------------------------------------------------
// Without this, Power BI sorts age bands alphabetically and "18-24" lands next
// to "65+". Add this column to dim_customer, then in Model view select
// age_band > Column tools > Sort by column > age_band_order.

// Add as a custom column step inside dim_customer:
//   Table.AddColumn(TypedData, "age_band_order", each
//       let b = [age_band] in
//       if b = "18-24" then 1
//       else if b = "25-34" then 2
//       else if b = "35-44" then 3
//       else if b = "45-54" then 4
//       else if b = "55-64" then 5
//       else 6,
//       Int64.Type)

// Do the same for loyalty_tier (New=1, Developing=2, Established=3, Loyal=4)
// and season (Spring=1, Summer=2, Fall=3, Winter=4).


// -----------------------------------------------------------------------------
// MODEL RELATIONSHIPS (set in Model view, not in Power Query)
// -----------------------------------------------------------------------------
// dim_customer[customer_id]   1 --> *  fact_purchase[customer_id]
// dim_item[item_key]          1 --> *  fact_purchase[item_key]
// dim_location[location_key]  1 --> *  fact_purchase[location_key]
//
// All three: single-direction filtering (dimension filters fact). Do NOT set
// bi-directional — it creates ambiguity and slows the model with no benefit here.
//
// Then hide the key columns from report view (right-click > Hide in report view):
// all three *_key columns in fact_purchase, plus customer_id in fact_purchase.
// Report users should never drag a surrogate key onto a visual.
