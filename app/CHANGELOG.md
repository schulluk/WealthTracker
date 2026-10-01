# Changelog

## Next: 1.4.0

- A failed VIAC sync now says what VIAC returned instead of a cryptic decimal error, and a missing total fails the sync rather than recording a zero balance
- Commerzbank accounts are now kept up to date by hand: the bank only offers scan-the-graphic photoTAN over its data interface, so the sync button and the credential fields are gone, the balance is entered as a snapshot, and transactions come from the CSV export
- App transactions: search the list by text or amount, and one Show filter for everything, uncategorized only or transfers only
- App transactions: a new "Create a rule from this" action in the category sheet, prefilled with the booking's merchant and category
- App spending: the category history sheet can open the transaction list narrowed to that category
- App rules: tapping a rule opens it for editing — target (category or transfer), spread, and under Advanced the regex switch, the payments/income direction and the amount bounds; a line under the form says how many existing transactions the rule would change, and how many are claimed by an earlier rule or already have a category
- App spending: month, quarter or year, chosen in one period control that the chart, the breakdown and the transaction list all follow
- App spending: spent, income and net for the selected period, each against the period before and against the average of the last six
- App spending: budgets are shown in the app now — how much of this period's budget is left, and per category as a target marker on its bar with what is left or over
- App spending: the breakdown lists categories as ranked bars with their share and how they compare with their own average; tapping one opens its history (total, average, highest, and a bar per period)
- Web: the wealth chart's y-axis now fits the range on screen instead of always starting at zero, so movements within a period are actually visible
- Web: a dashboard icon in the top navigation, first of the icons on the right, so getting back no longer means clicking the app name
- Swisscard accounts can be synced from the app again: the card no longer counts as a manual account, and its sync button starts the login that texts you a code (it stays out of "Sync all", which runs unattended)
- Tapping the "Syncing accounts" bar opens a live breakdown: accounts still in progress on top, finished ones below, each moving down as it completes
- Transactions can now be marked as transfers by hand (checkbox in the web transaction list, switch in the app's category sheet), excluding them from the spending report — needed for broker funding that auto-detection cannot pair
- Importing historical transactions now reports the date range the bank actually served and warns when it is shorter than requested
- Syncs for brokers that report holdings (IBKR, Morgan Stanley) now record per-asset positions; a Holdings card on the dashboard (web and app) shows them merged across accounts
- New wealth simulation (chart icon on the start screen): Monte Carlo projection of total wealth with percentile bands, in today's purchasing power; defaults derived from your accounts, spending, and holdings, all adjustable, with an optional target amount and the probability of reaching it
- Simulation assumptions you change are saved to your profile and shared between web and app; assumptions you leave untouched keep updating from your data, and clearing a field goes back to the derived value
- Simulation polish: readable y-axis labels (K/M, no overlap or duplicates), a red line marking the target amount and the year the median path reaches it, sticky tap-to-inspect showing median/75%/95% values above the chart, an explanation under every assumption field, and instant horizon switching (no recalculation)
- Spending chart fixes: month labels no longer overlap, y-axis ticks are evenly spaced without duplicate values, and the breakdown total in the donut uses a thousands separator
- Transaction lists now show the counterparty name instead of a leading IBAN, and the booking text gets two lines instead of one
- AI suggestions: the settings card now explains upfront that a round proposes both categories and rules; a banner at the top announces proposed rules with a switch to skip creating them, select or deselect all with one tap in the app bar, and the apply button breaks its count into categories and rules
- Categories can now be renamed and deleted in the app under Spending settings
- Transactions tab now lists all accounts together in chronological order, with a collapsible filter for account and uncategorized-only, account chips on each row, and a load-more footer
- Chart axis labels use the fewest decimals that keep every label distinct, and can no longer wrap into two lines
- Simulation: picking a longer horizon than the server covered now re-runs the simulation instead of leaving the chart clipped at the previously selected horizon
- Transactions list loads further pages automatically while scrolling (no more load-more button) and pages load faster
- Fix similar with AI: after manually re-categorizing a transaction, a new action asks Gemini which other transactions belong to the same merchant or purpose; you review its picks (and an optional rule) before anything is changed. Re-labeling only considers the last 18 months; uncategorized entries are offered at any age
- A corrective rule from the fix-similar flow is inserted before the rule that caused the mislabel (rules are first-match-wins), and no rule is proposed when the existing rules already classify the merchant correctly
- Consolidate rules with AI: a new button in Spending settings asks Gemini to merge duplicate rules and drop dead ones; you review the resulting set including removed rules before it replaces the old one
- AI review sheets show amounts with 2 decimals instead of the raw 4-decimal value, and the fix-similar sheet lists each entry's current label instead of a cramped old-to-new pair (the target category is in the title)
- AI suggestions: the proposed category chip moved below the entry text — beside it, a long category name squeezed the merchant into a sliver
- AI proposes more concise category names: one word where possible, no "A & B" composites
- Transaction history can now be backfilled from a bank CSV export in the web app (ZKB "with details" and DKB formats, auto-detected); re-imports and EBICS-synced ZKB entries are deduplicated. The file determines its own account (DKB via its IBAN, ZKB by currency), with a picker only when several accounts match; per-account import is also available from the dashboard account list
- Categorization rules can be regular expressions (new checkbox in the web rule form, validated in the browser and on the server); AI rule consolidation leaves regex rules untouched, and the app displays them read-only
- Web transactions list now shows all accounts in one chronological list with an account column (dropdown only narrows), matching the app
- Web: category and transfer are one dropdown now — pick a category, "Transfer (excluded)", or create a new category right from the row; the transfer checkbox column is gone and remaining checkboxes render as switches
- Rules can mark matches as transfers ("Transfer" option as the rule target), excluding recurring transfers like broker top-ups from spending automatically; manual not-a-transfer decisions always win
- New "+ Rule" action on every web transaction row prefills the rule form from that transaction
- Commerzbank CSV export is now recognized by the transaction import, including automatic account matching via the file's own IBAN and counterparty-IBAN extraction for transfer pairing
- Monthly spending report is much faster: exchange rates are loaded in bulk instead of queried (or fetched from the rate API) per transaction date
- Web rule form: the match-text input now takes the full row width with the regex switch right next to it
- Web AI card: "Get suggestions" is a prominent full-width button in the card body instead of sitting next to Change/delete; model pricing and the data disclosure collapse to just the model name
- Web: the Import history card is collapsed by default, and the spending tab survives a page refresh (it is part of the URL)
- Web: import and AI outcomes now show as green success banners (yellow for warnings) instead of muted hint text; CSV import hints mention Commerzbank
- AI suggestions split into two flows (web and app): "Suggest rules" proposes reusable rules for recurring merchants (now aware of your existing rules, so no duplicates), "Categorize items" labels one-off transactions — no more mixed review round
- Historical exchange rates are fetched in yearly ranges (one API call per currency per year) instead of one call per missing day; a first-time 24-month spending view no longer stalls for many seconds
- Rules now default to a compact by-category view (web and app): one group of chips per category, with a filter on the web; the flat first-match-wins list with drag-to-reorder moved behind an Order toggle
- AI rule suggestions merge near-identical merchant spellings ("dm-drogerie" / "dm.drogerie") into one regex rule instead of one rule per spelling
- AI rule suggestions can improve an existing rule in place (shown as "replaces ...") when it misses spellings seen in your transactions — e.g. a "youtubepremium" rule becomes a regex also matching "youtube premium"; exact duplicates of existing rules are no longer suggested
- AI suggestions can now propose transfers: recurring own-account movements (broker top-ups, credit-card settlements) can be marked "Transfer (excluded)" per transaction or via a suggested transfer rule
- Swisscard accounts can now sync on demand: tap sync, enter the code the bank sends by SMS, and the card balance and transactions are pulled in (web and app). Swisscard is skipped by Sync All, since it always needs a code typed in that moment
- Sync code prompts now say where the code came from (SMS versus authenticator app) instead of always naming an app
- Swisscard credit-card exports can now be imported: add a Swisscard account and import its CSV, and the monthly settlement pairs with the debit on the paying bank account so only the card purchases count as spending
- Duplicate detection now also catches entries the two feeds dated a day or two apart, and never merges two payments that share a day and an amount but carry different contract or card numbers
- Fixed transactions appearing twice when the same account was imported through two paths (for example a ZKB EBICS sync and the account's CSV export, whose wording differs): the importer now recognizes an entry already imported from another source. Existing duplicates can be cleaned up with the new dedupe_transactions maintenance command
- Web rules can now be edited: click a rule to change its match text, regex flag, target category or spread
- Web transactions can be filtered by category, including uncategorized-only and transfers-only
- Rules with a match text that already exists are rejected instead of silently added (a duplicate rule could never match, since the first rule wins)
- Transfer rules no longer offer a spread — a transfer is excluded from spending, so there is nothing to amortize
- Removed the "Detect transfers" button: transfer detection already runs automatically after every import
- Budgets per category: set a monthly target under Spending settings and the insights show how much of it is left (or how far over), as a marker on each category bar and a line above the chart. Targets scale with the period on screen — a quarter shows three times the monthly target, a year twelve — and the summary says how much of your spending the budgeted categories actually cover
- Insights page rebuilt around one period control: pick Month, Quarter or Year and step through periods — the chart, the breakdown and the transaction list all follow it, instead of each carrying its own month and uncategorized switch
- Spending can now be viewed per quarter and per year, so "what do subscriptions cost me in a year" is one number instead of twelve rows added up
- New summary row: spent, income and net for the selected period, each compared against the previous period and against the average of the previous ones (an average that ignores periods with no data, so a category added last month is not "up 500%")
- Breakdown is now category chips over a ranked bar list: several chips can be picked at once and their combined total is shown ("Groceries + Dining Out = EUR 648, 12.6% of this month"), which the old single-select dropdown could not answer
- Clicking a category name opens its own history: what it costs per period across the whole window, its average, and its highest period
- Web transaction list follows the selected period and the picked chips, with one button to widen it to all periods; the separate month and category dropdowns are gone
- Changing a transaction's category or spread by hand now asks whether the rule that classified it should change too (web and app) — otherwise the same rule keeps sending every future booking of that merchant to the old category
- Web transaction list can be sorted by clicking a column header (date, transaction text, category, amount), ascending or descending; sorting runs on the server so it covers every page, not just the loaded ones
- Transaction rows whose bank feed leaves the counterparty empty (ZKB card purchases) no longer render entirely in muted grey — whatever names the transaction is now the primary line
- Category dropdowns and lists are now sorted the way a reader expects: case-insensitively and with umlauts filed under their base letter ("Ärzte" with A, "eBay" with E) instead of after Z, where the database collation put them
- Spending categories past the fourteenth are now hatched (diagonal stripes, then dots, then crosshatch) in the web charts and legends instead of repeating a color, and get a lighter or darker shade in both web and app — the first fourteen stay solid
- Spending chart colors: every category now gets a distinct color (with eight in the palette, a ninth category became a twin of the first — "Restaurants" was indistinguishable from "Housing", "Subscriptions" from "Uncategorized"), and Uncategorized is always the same grey instead of taking a category color
- Web spending chart tooltip is no longer painted over by the legend below it, which made its background look see-through
- Long booking texts in the web transaction list are cut off after two lines with a "more" chip that reveals the rest (a DKB Rechnungsabschluss used to fill the screen with one row)
- Web transaction list no longer scrolls sideways: date and account share a column, counterparty and description share the one column that takes the leftover width, and long bank wording wraps instead of pushing the amount out of sight
- Transactions can now be filtered by month (web and app), and picking a month in the insights — a bar in the chart or the breakdown arrows — filters the transaction list to it automatically
- "Only uncategorized" no longer lists transfers: they have no category by design, and they buried the entries that still need a label
- A single transaction can now be spread over 3, 6 or 12 months (column in the web transaction list, segmented control in the app's category sheet) — for one-off yearly bills that have no rule to carry the spread; marking a transaction as a transfer drops its spread
- Fetching transaction history from a bank that sends a one-time code (Swisscard) now asks for that code instead of failing, and resumes the same fetch once it is entered
- Web rules: a group's plus chip moves the rule form directly below that group with the category prefilled (changing the dropdown by hand never moves it); the regex switch turns itself on while typing pattern syntax like brackets or pipes (manual toggles stay put), and saving a "regex" without any regex syntax asks whether to save it as plain text instead

- Start screen now refreshes automatically after an automatic sync or after adding a snapshot from the account detail screen (no more pull-to-refresh needed)
- A "Syncing accounts" bar below the app bar now shows while a Sync All run is in progress, including automatic syncs on app open
- Sync results (synced count or per-account errors) are now also shown after automatic syncs
- New Spending screen (chart icon on the start screen): month-to-month spending by category, with a normalized view that spreads yearly bills across their months, and a per-month breakdown you can step through
- Spending screen now has a Transactions tab: pick an account and assign a category to any transaction by tapping it
- Spending settings (tune icon): manage categorization rules including drag-to-reorder, and request Gemini category suggestions to review and confirm (the Gemini key and model are still configured in the web app)
- ZKB CSV import now skips pending entries (rows the bank has not booked yet), which were being counted as spending and would return a second time once booked
- Cross-source duplicate detection now ignores the bank's own template wording, so two different merchants charging the same amount to the same card are no longer treated as one payment; the dedupe command prints the row each deletion duplicates
- Web: "+ Rule" on a transaction opens a dialog instead of jumping to the Configuration tab
- Web: creating or editing a rule now shows how many existing transactions it would classify, with examples, and says when an earlier rule would claim them first
- Web: dropdowns and budget fields no longer render as white boxes on the dark background
- Web: in the normalized view the transaction list now also shows bills booked earlier whose spread reaches into the selected period, each stating the share counted (e.g. "6/12"), so the list adds up to the category total in the breakdown
- Rules can now be limited by amount under a new Advanced section: a direction (any, payments only, income only) plus an at least / at most range, each bound inclusive or exclusive. Sizes are written without a sign, so a one franc payment is "Payments, under 2". Two rules may share match text when their amount conditions differ, which lets the same merchant go to different categories by size or direction
- Web: the rule dialog is two columns, with the match count in its own so it no longer pushes the form down as you type
- Web: dialogs close with the Escape key, and no longer close when a text selection started inside the dialog ends outside it
- Web: a search box on the transaction list matches the booking text or an amount; amounts are matched on their size, so searching 13.45 (or 13,45) finds both a payment and a refund of that amount
- Bug fixes and improvements.

## 1.3.8
- Added Zürcher Kantonalbank (ZKB) as a broker: accounts connect via EBICS and sync end-of-day balances. EBICS credentials are set up once on the web app (one-time key exchange) and shared across all your ZKB accounts.
- A ZKB account behaves like a manual account until its EBICS key exchange is activated by the bank: it prompts you to add snapshots by hand instead of showing a sync action that would fail.
- Bug fixes and improvements.

## 1.3.7

- Bug fixes and improvements.

## 1.3.6

- Sync reminder can now repeat every day, every 3 days, weekly, or monthly (default every 3 days) instead of only daily
- New option to shift reminders that fall on a weekend to the next weekday, with an optional setting to also skip US market holidays (e.g. Good Friday, Christmas)
- Per-account chart y-axis now adapts to the visible value range with clean tick steps (100, 250, 500, 1k, 2.5k, 5k, 10k, ...)
- Per-account chart now loads the full snapshot history instead of just the most recent 100 entries
- Chart y-axis labels switch to 2 decimals (e.g. "13.20K", "1.25M") when step size would otherwise produce duplicate-looking ticks

## 1.3.5

- Stability improvements
- Tap an account card to view its history, balance chart, and full snapshot list

## 1.3.4

- Upgrade dependencies to the latest versions
- Quick snapshot sheet auto-closes after the last account is submitted
- 30-day chart range now forces daily granularity; previous setting restored when switching back
- Chart performance improved with downsampling for large datasets
- Y-axis labels always show 2 decimal places for million values
- Monthly aggregation method (last/min/max/avg) is now a user setting
- Sync no longer blocks the UI — graphs and manual data work while syncing
