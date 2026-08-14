# Power BI Build Guide
### Customer Shopping Behaviour Analysis — dashboard specification

Build order: **connect → model → measures → pages → polish**. Roughly an hour end to end.

---

## The story the dashboard has to tell

Your analysis produced one finding that everything else should serve:

> **30% of customers generate 72% of estimated annual value — and they get there by buying
> 4.3× more often, not by spending more per order.** Average order value between the two
> segments differs by just 1.23×. Discount and subscription status show no detectable effect
> on spend at all.

Design each page to make that arrive, rather than presenting twelve charts and leaving the
reader to find it. A dashboard that states a conclusion is what separates a portfolio piece
from a screenshot of the Fields pane.

**Key figures to sanity-check against as you build:**

| Metric | Expected value |
|---|---|
| Total revenue | $233,081 |
| Total customers / orders | 3,900 |
| Average order value | $59.76 |
| Estimated annual value | $4,070,553 |
| Category split | Clothing 44.7% · Accessories 31.8% · Footwear 15.5% · Outerwear 7.9% |
| Segments | High-value regulars 1,161 (71.6% of EAV) · Steady mid-tier 2,739 (28.4%) |
| Cadence | 38.2 vs 8.8 purchases/year |
| Top-decile revenue share | 16.1% |
| Subscriber rate | 27.0% |

If a card disagrees with this table, the relationship or filter direction is wrong — fix it
before moving on.

---

## Step 1 — Connect

Use **`power_query.m` → Option A (MySQL)**. Load all four tables. If the MySQL connector
misbehaves, fall back to Option B and point `DataFolder` at your `data/processed` folder.

## Step 2 — Model

In **Model view**, create the three relationships listed at the bottom of `power_query.m`,
all single-direction. Then:

- Hide every `*_key` column and `fact_purchase[customer_id]` from report view
- Add the sort-order columns for `age_band`, `loyalty_tier` and `season`, and set
  **Sort by column** on each — otherwise your age bands sort alphabetically and the dashboard
  looks careless
- Set `dim_location[location]` **Data category → State or Province** so map visuals work

## Step 3 — Measures

Create a blank table `_Measures`, then add everything from `measures.dax`. Set the formats
listed in section 8 of that file as you go — retro-formatting twenty measures is miserable.

---

## Page 1 — Executive Summary

**Purpose:** the number a commercial lead needs in ten seconds.

| Position | Visual | Fields |
|---|---|---|
| Header band | Text box | "Customer Shopping Behaviour" + subtitle |
| KPI row (5 cards) | Card | `Total Revenue` · `Total Customers` · `Avg Order Value` · `Est Annual Value` · `Subscriber Rate` |
| Left, mid | Donut | Legend `dim_item[category]`, Values `Total Revenue` |
| Right, mid | Clustered bar | Axis `dim_customer[age_band]`, Values `Avg Order Value` and `Avg Annual Value` |
| Left, lower | Map (filled) | Location `dim_location[location]`, Colour saturation `Total Revenue` |
| Right, lower | Bar (Top 10) | Axis `dim_item[item_purchased]`, Values `Total Revenue`, filter `Item Revenue Rank` ≤ 10 |
| Slicer panel | Slicers | `category`, `season`, `segment`, `age_band` |

**The key visual is the mid-right bar chart.** Two series side by side: average order value is
visibly flat across every age band, while annual value is not. Add a text box beneath it
reading *"Order size barely varies by demographic — purchase frequency is what creates value."*

## Page 2 — Customer Segments

**Purpose:** prove the cadence finding and make it actionable.

| Position | Visual | Fields |
|---|---|---|
| Top row (3 cards) | Card | `High Value Customers` · `High Value Annual Share %` · `Cadence Multiple` |
| Top row, 4th card | Card | `Order Value Multiple` — placed *directly beside* Cadence Multiple |
| Left | Scatter | X `Avg Purchases Per Year`, Y `Avg Order Value`, Legend `segment`, Details `customer_id` |
| Right | Stacked bar | Axis `segment`, Values `Annual Value Share %` and `Customer Share %` |
| Lower | Matrix | Rows `segment` → `age_band`, Values `Total Customers`, `Avg Order Value`, `Avg Annual Value`, `Subscriber Rate` |
| Below cards | Text box | Bind title to the `Insight Cadence` measure |

The two multiple cards sitting side by side (**4.3× vs 1.23×**) are the single most persuasive
thing in the whole dashboard. Give them room and don't bury them.

Enable **drill-through** on this page: create a hidden "Customer Detail" page with
`dim_customer[segment]` in the Drill through well, holding a table of individual customers.
Right-click any segment → drill through. Interviewers notice this; most portfolio dashboards
have no interactivity beyond slicers.

## Page 3 — Engagement: Discounts & Subscriptions

**Purpose:** report a null result properly. This page is your differentiator.

| Position | Visual | Fields |
|---|---|---|
| Left | Clustered column | Axis `received_discount`, Values `Avg Order Value` and `Avg Annual Value` |
| Right | Clustered column | Axis `is_subscriber`, same values |
| Lower | Table | Import `mart_hypothesis_tests.csv` — comparison, medians, p-value, Cliff's delta, verdict |
| Full width, top | Text box (bordered, muted) | See below |

Put this in the text box, in a visibly distinct style:

> **Reading this page.** Differences between these bars are not statistically distinguishable
> from noise (all effect sizes negligible, Cliff's δ < 0.05). Discount status also shows
> moderate association with subscription status and gender (Cramér's V 0.70 / 0.60), so it
> cannot be read as an independent driver. **Recommendation: run a randomised holdout test
> before scaling promotional spend.**

Almost every retail dashboard shows two near-identical bars and lets the viewer infer an
effect. Explicitly labelling near-identical bars as *no effect* demonstrates statistical
judgement more convincingly than any chart could.

## Page 4 — Product & Regional Performance

| Position | Visual | Fields |
|---|---|---|
| Left | Matrix | Rows `category` → `item_purchased`, Values `Total Revenue`, `Revenue Share %`, `Avg Review Rating` |
| Right | Bar | Axis `location`, Values `Total Revenue`, filter `Location Revenue Rank` ≤ 15 |
| Lower left | Column | Axis `season`, Values `Total Revenue`, legend `category` |
| Lower right | Cards | `Imputed Rating %` and `Avg Rating (Observed Only)` |

Those last two cards are your data-quality transparency: 0.95% of ratings were imputed and the
dashboard says so.

---

## Step 4 — Polish

This is what turns a working model into something worth screenshotting on a CV.

**Theme.** View → Themes → Customize. Use the notebook's palette so charts and dashboard match:
`#1F3A5F` (navy), `#2A9D8F` (teal), `#E9C46A`, `#E76F51`, `#8AB6D6`, `#6D6875`. Background
`#F7F8FA`. Save as a custom theme and commit the JSON to the repo.

**Consistency rules**
- One font throughout (Segoe UI), title 14pt semibold, body 10pt
- Cards: white fill, 1px `#E4E7EC` border, subtle shadow, rounded corners
- Every visual gets a title that says what it shows, not what it is — "Revenue by category",
  never "Sum of purchase_amount"
- Turn off gridlines where the data labels already carry the number

**Interactivity**
- Sync slicers across pages: View → Sync slicers, tick every page for `category` and `season`
- Add page navigation buttons in a left rail (Insert → Buttons → Navigator → Page navigator)
- Set **Edit interactions** so slicers filter rather than highlight where cross-highlighting
  would confuse

**Accessibility** — worth a line in your README given your WCAG work on PureEat's:
set alt text on every visual, check tab order (Selection pane → Tab order), and confirm the
palette clears 4.5:1 contrast.

---

## Step 5 — Ship it

1. Save as `powerbi/customer_shopping_dashboard.pbix`
2. **Export each page to PNG** (File → Export → PDF, or screenshot at high resolution) into
   `reports/figures/` and embed them in your README — recruiters will not install Power BI
   Desktop to look at your work, so the images *are* the portfolio
3. Publish to Power BI Service if you have an account, and put the public link in the README
4. If the `.pbix` exceeds 100 MB, use Git LFS — at 3,900 rows it will be a few MB, so you're fine

---

## Two things to watch

**`est_annual_value` is a proxy, not a forecast.** Label it "Est. Annual Value (modelled)" on
every visual where it appears. If an interviewer asks how you'd validate it, the answer is:
you can't with this data — it needs transaction-level history with timestamps, which is the
top limitation in your notebook.

**The segmentation is only weakly separated** (silhouette 0.286). Two clusters is a legitimate
result, but describe them as *planning groupings*, not distinct customer types. Being precise
about that is a strength, not a hedge — overselling a 0.286 silhouette is exactly the kind of
thing a technical interviewer probes.
