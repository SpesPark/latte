# Latte Marketing Site

Static site for App Store landing + Privacy Policy. Hosted on GitHub Pages.

## Files

| File | Purpose |
|---|---|
| `index.html` | Marketing landing page. App Store "Marketing URL". |
| `privacy.html` | Privacy Policy. **App Store "Privacy Policy URL" — required**. |

## Hosting setup (do once, before App Store submission)

### Option A — same repo, `gh-pages` branch (simplest) — **PRE-STAGED IN S8c**

The `gh-pages` branch is already created in a sibling worktree at
`../latte-gh-pages-staging/` with one root commit (`e3738a9`). Owner only needs
to add the remote and push:

```bash
# Verify the staged worktree is intact
git worktree list
# Expected: latte-gh-pages-staging  e3738a9 [gh-pages]

cd ../latte-gh-pages-staging
git remote add origin <github-url>     # e.g. https://github.com/SpesPark/latte.git
git push -u origin gh-pages
```

Then in GitHub repo Settings → Pages → Source = `gh-pages` branch / root.

To update the site later (after edits in `docs/site/`):
```bash
# Preferred — automated (S26 / S8d)
scripts/deploy_pages.sh             # diffs docs/site/ vs staging, commits + pushes
scripts/validate_pages.sh           # curl 200 check on the live URL

# Manual equivalent (if scripts unavailable)
cd ../latte-gh-pages-staging
cp /path/to/Latte/docs/site/{index,privacy}.html .
git add . && git commit -m "site: update"
git push
```

`scripts/deploy_pages.sh --dry-run` shows the diff without writing.
`scripts/validate_pages.sh <url>` accepts an explicit URL (auto-derives
from the gh-pages worktree's `origin` remote when omitted).

If you ever need to rebuild from scratch (lost the worktree, etc.):
```bash
git worktree add --detach ../latte-gh-pages-staging
cd ../latte-gh-pages-staging
git checkout --orphan gh-pages
git rm -rf .
cp /path/to/Latte/docs/site/{index,privacy}.html .
git add . && git commit -m "site: rebuild"
```

GitHub Pages settings → Source = `gh-pages` branch → root.
URLs (LIVE since S29, 2026-05-15):
- Landing: `https://spespark.github.io/latte/`
- Privacy: `https://spespark.github.io/latte/privacy.html`

### Option B — separate `latte-site` repo (cleaner for App Store reviewer)

```bash
gh repo create latte-site --public
cd ../latte-site
cp -r ../<this-repo>/docs/site/* .
git init && git add . && git commit -m "init"
git push -u origin main
```

GitHub Pages settings → Source = `main` branch → root.
URLs:
- Landing: `https://spespark.github.io/latte-site/`
- Privacy: `https://spespark.github.io/latte-site/privacy.html`

### Option C — custom domain (post-launch, optional)

Buy `latte.app` (or similar). Add `CNAME` file with the domain, configure DNS A records to GitHub Pages IPs (`185.199.108.153` etc.). Apple is fine with both `*.github.io` and custom domains — pick whichever the owner prefers.

## Verification before App Store submission

```bash
curl -sI https://<your-pages-url>/privacy.html | head -5
# Must show: HTTP/2 200 + content-type: text/html
```

App Store reviewer will visit the Privacy URL. Must be reachable, must be HTTPS, must contain a Privacy Policy. The `privacy.html` here satisfies all 3.

## Updating

Edit the HTML files in `docs/site/` (this directory), then re-deploy via the same `cp` + commit flow. Treat `docs/site/` as source-of-truth, not the deployed copy.
