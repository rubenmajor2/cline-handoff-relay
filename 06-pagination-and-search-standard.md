# Pagination + Search Standard — EMSU Routes

## The rule

**Any EMSU route that renders a list, table, or card-grid of rows from the database MUST use the shared `lib/ruben_paginate.php` helper for pagination + search.** No more one-off `LIMIT 100` or `LIMIT 300` hardcaps. No more route-specific `?search=` vs `?q=` vs `?search_term=` param drift. No more invisible rows when a table crosses the cap.

This rule applies to every file under `/var/www/emtskills/routes/*.php` that currently renders a list, and every NEW route we build from here on. If a route has 50+ rows today or might reasonably grow past 100, it uses the helper.

## Why this rule exists

On 2026-04-23 the orchestrator_ideas.php page was hard-capped at `LIMIT 300`. The table had 465 rows. ~165 ideas were silently invisible from the browser — the only way to see them was to run SQL directly. That was the immediate trigger.

The broader problem: 97+ EMSU routes still have hand-rolled `LIMIT N` with no pagination, no page count, no total count, and no search box. Each one is a latent "silently hide rows" bug waiting to trip someone. Plus every time a developer writes one more list route from scratch, they reinvent 80 lines of search + pagination CSS/HTML/query-param handling, often with drift (different param names, different per-page options, different button styling).

Shipping once-per-helper + enforcing its use across routes saves ~1-2 hours of dev time per new list page, eliminates the silent-hide bug class permanently, and keeps the UX uniform across the whole admin portal.

## What the helper provides

Lives at `/var/www/emtskills/lib/ruben_paginate.php`. Already shipped and in use by `routes/orchestrator_ideas.php` as the reference implementation.

Functions exported:

- `ruben_paginate_state(array $opts = []): array` — reads `?page`, `?per_page`, `?q` from `$_GET` and returns a normalized state array `{page, per_page, offset, q, per_page_options, q_param, preserve_qs}`. Safety-caps `per_page` at 500.
- `ruben_paginate_apply(string $sql): string` — appends `LIMIT :_pg_limit OFFSET :_pg_offset` to a SELECT. Caller binds `:_pg_limit` and `:_pg_offset` as `PDO::PARAM_INT`.
- `ruben_paginate_link(array $pg, int $page, ?int $perPage = null): string` — builds a URL that preserves every existing GET param except `page`/`per_page`, then stamps in the requested ones. Use this for custom tab/filter links.
- `ruben_search_render(array $pg, array $opts = []): void` — renders a uniform search form at the top of the list (magnifier icon + placeholder + Search button + Clear-search link when active). Accepts a `hidden` map to preserve other filter params (tabs, status, priority) across search submits.
- `ruben_paginate_render(array $pg, int $total, int $pageRowCount): void` — renders the uniform pagination bar (« ‹ 1 … 5 6 [7] 8 9 … 19 › », showing X-Y of TOTAL, per-page: 25/50/100/250). Call once above the list AND once below it.

All CSS is scoped to `.ruben-search` / `.ruben-pager` and emitted inline on first call. No separate CSS file to manage.

## The required route skeleton

Every list route should follow this shape. Copy and adapt.

```php
<?php
declare(strict_types=1);

require_once __DIR__ . '/../lib/auth.php';
require_once __DIR__ . '/../lib/ruben_nav.php';         // if it's a RUBEN-family page
require_once __DIR__ . '/../lib/ruben_paginate.php';    // <-- REQUIRED
require_once __DIR__ . '/../lib/db.php';

requireLogin();
$pdo = db('portal'); // or db('moodle'), etc.

// 1. Read filter params + pagination/search state.
$statusFilter = (string)($_GET['status'] ?? 'active');
$pg = ruben_paginate_state([
    'per_page'         => 25,
    'per_page_options' => [25, 50, 100, 250],
    'q_param'          => 'q',
]);

// 2. Build WHERE parts + binds ONCE. Reuse for COUNT and SELECT.
$whereParts = [];
$binds = [];
if ($statusFilter !== 'all') {
    $whereParts[] = "t.status = :status";
    $binds[':status'] = $statusFilter;
}
if ($pg['q'] !== '') {
    $whereParts[] = "(t.title LIKE :q OR t.description LIKE :q)";
    $binds[':q'] = '%' . $pg['q'] . '%';
}
$whereSql = $whereParts ? 'WHERE ' . implode(' AND ', $whereParts) : '';

// 3. Count the full filtered set (for the pagination bar).
$countStmt = $pdo->prepare("SELECT COUNT(*) FROM my_table t {$whereSql}");
foreach ($binds as $k => $v) $countStmt->bindValue($k, $v);
$countStmt->execute();
$totalFiltered = (int)$countStmt->fetchColumn();

// 4. Fetch ONLY the current page.
$sql = "SELECT t.* FROM my_table t {$whereSql}
        ORDER BY t.updated_at DESC
        LIMIT :_pg_limit OFFSET :_pg_offset";
$stmt = $pdo->prepare($sql);
foreach ($binds as $k => $v) $stmt->bindValue($k, $v);
$stmt->bindValue(':_pg_limit',  $pg['per_page'], PDO::PARAM_INT);
$stmt->bindValue(':_pg_offset', $pg['offset'],   PDO::PARAM_INT);
$stmt->execute();
$rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
?>
<!doctype html>
<html>
<head>...</head>
<body>

<?php ruben_nav_render('ideas_pipeline'); // if RUBEN family, else skip ?>

<?php
// Search bar. Preserve any OTHER filter params via `hidden`.
ruben_search_render($pg, [
    'q'      => 'Search titles and descriptions...',
    'hidden' => ['status' => $statusFilter],
]);
?>

<!-- Your tabs/filters here. If you build tab links, use ruben_paginate_link()
     with the new filter swapped in, OR build the href manually but include
     per_page + the current q to preserve state. -->

<?php ruben_paginate_render($pg, $totalFiltered, count($rows)); ?>

<?php if (empty($rows)): ?>
  <div class="empty">No rows match the current filters.</div>
<?php else: ?>
  <?php foreach ($rows as $r): ?>
    <!-- render $r -->
  <?php endforeach; ?>
<?php endif; ?>

<?php ruben_paginate_render($pg, $totalFiltered, count($rows)); ?>

</body>
</html>
```

## Naming conventions (non-negotiable)

- **Search param name is always `q`.** Not `search`, not `search_term`, not `filter`. If you need a second search box on the same page (rare), use `q2`. The helper defaults to `q`.
- **Pagination params are always `page` and `per_page`.** Both 1-indexed for `page`. `per_page` is an integer in the helper's `per_page_options` list.
- **Default `per_page` is 25.** Options are `[25, 50, 100, 250]` unless the list items are unusually tall (then use `[10, 25, 50, 100]`) or unusually short (then use `[50, 100, 250, 500]`).
- **Tab/filter links preserve `q`, `per_page`, and current filter state.** Use `ruben_paginate_link()` or manually append `&q=...&per_page=...` to every tab link. Pagination state should survive switching tabs as long as the tab still makes sense.
- **Never mix `LIMIT <hardcoded>` and pagination.** If pagination is present, there is no business-level cap. The safety cap in the helper (500/page, 500 per_page max) is enough.

## When this rule does NOT apply

- **Detail/show pages** (`?student_id=123`). Those render one record, not a list. No pagination needed.
- **Dashboards with a fixed small number of cards** (e.g. "5 top stats" cards). No rows, no pagination.
- **API endpoints** that return JSON. Those have their own pagination convention (cursor-based). This rule is for HTML routes.
- **Report PDFs / exports.** Those deliberately export everything, not a page. Use `LIMIT 5000` or similar hard cap for memory safety, document the cap in a comment, but no `ruben_paginate_render`.
- **Pages with <= 30 rows in the foreseeable future** where pagination would be pure overhead. If the table is `chat_info_leaks` with 6 rows ever, skip the helper — but add a code comment: `// no pagination: table stays small by design`. This is the only case where opting out is OK.

## Rollout plan (for Cline sessions touching these routes)

As of 2026-04-23, 97 route files have a hard-cap `LIMIT N` and no use of `ruben_paginate`. We are not doing a flag-day rewrite — that's too risky. Instead:

1. **Any time I (Cline) edit a list route for a different reason, also migrate it to the helper** in the same PR. "Boy scout rule" — leave the file better than you found it.
2. **When Ruben specifically asks "why are some rows missing from page X",** that route gets migrated immediately.
3. **The orchestrator_ideas rollout tracking idea** (see admin_portal.orchestrator_ideas — search for `pagination-helper-rollout`) tracks the count of migrated files. When a file is migrated, append its name to the idea's `implementation_log`. Idea stays open until all 97 are done.

A greppable "is this route migrated?" check:

```sh
grep -l "ruben_paginate" /var/www/emtskills/routes/*.php
```

That list should grow by at least 1-3 every week until the count matches the list-route count.

## Red-flag patterns to catch and fix

When editing a route file, watch for these and replace with the helper:

- `LIMIT 100` / `LIMIT 300` / `LIMIT 500` without a matching OFFSET or COUNT → not paginated, will silently hide rows once table grows.
- `$search = $_GET['search'] ?? '';` → rename to `q` to match convention.
- Hand-rolled `<input type="search">` + `<button>Search</button>` with inline style → replace with `ruben_search_render($pg, [...])`.
- Hand-rolled `<a>Next</a>` / `<a>Prev</a>` pagination without page numbers or total → replace with `ruben_paginate_render($pg, $total, count($rows))`.
- `SELECT ... LIMIT $perPage OFFSET $offset` where `$perPage` is a local variable → refactor to use `$pg['per_page']` + `$pg['offset']` from the helper.
- Pagination that doesn't preserve the current search/filter state when clicking page 2 → helper fixes this automatically via `preserve_qs`.

## Testing checklist (for any migration PR)

- [ ] Page loads without error
- [ ] Default view shows first 25 rows
- [ ] `?per_page=100` shows 100 rows
- [ ] `?page=2` advances correctly
- [ ] Search submits to `?q=...` (not `?search=...`)
- [ ] Clear-search link removes `q` but preserves other filters
- [ ] Switching tabs/filters preserves `q` and `per_page`
- [ ] Total count in the pagination bar matches a manual `SELECT COUNT(*)` against the same WHERE
- [ ] When result set is empty, shows the empty state (not a blank pagination bar)
- [ ] Deep-linking to `?page=5&q=foo&status=active` restores exact state on reload

## MCP/dev-time savings (the point of this rule)

Before this helper:
- New list route = ~80 lines of boilerplate (search form, pagination bar, count query, window of page numbers, preserve-other-params logic)
- ~30-90 minutes per route to write + style + debug
- Every route drifted slightly (different `q` param name, different CSS, different page-size defaults)

After this helper:
- New list route = 3-5 lines (`require_once`, `ruben_paginate_state()`, `ruben_search_render()`, `ruben_paginate_render()`)
- ~5-10 minutes per route
- Zero drift. Every list page looks and behaves identically.

MCP-side corollary: when building an MCP tool that inserts a new admin route via `deploy_route`-style helpers, the generator template should START from the skeleton above, NOT from a blank file. That eliminates the "AI writes a new route without pagination" failure mode entirely.

## Enforcement

- PRs that add a new `/routes/*.php` list route without using `ruben_paginate` should be rejected in review.
- HANDOFF_NOTES entries documenting "silently hidden rows" bugs should cite this rule and migrate the offending route in the same session.
- Cline, when given a task that touches a list route, must first check `grep -l "ruben_paginate" <file>` and, if not present AND the route qualifies under "when this rule applies," migrate it as part of the same task rather than adding new logic on top of the legacy LIMIT pattern.
