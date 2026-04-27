# Latte Marketing Site

Static site for App Store landing + Privacy Policy. Hosted on GitHub Pages.

## Files

| File | Purpose |
|---|---|
| `index.html` | Marketing landing page. App Store "Marketing URL". |
| `privacy.html` | Privacy Policy. **App Store "Privacy Policy URL" — required**. |

## Hosting setup (do once, before App Store submission)

### Option A — same repo, `gh-pages` branch (simplest)

```bash
# from repo root
git checkout --orphan gh-pages
git rm -rf .
cp -r docs/site/* .
git add index.html privacy.html
git commit -m "site: initial Latte marketing + privacy"
git push -u origin gh-pages
git checkout main
```

GitHub Pages settings → Source = `gh-pages` branch → root.
URLs:
- Landing: `https://bj-park.github.io/latte/`
- Privacy: `https://bj-park.github.io/latte/privacy.html`

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
- Landing: `https://bj-park.github.io/latte-site/`
- Privacy: `https://bj-park.github.io/latte-site/privacy.html`

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
