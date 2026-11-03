# The user manual (DOCS-3)

Sphinx with MyST Markdown and the Furo theme, the same setup as the HelioFITS Studio manual. Read the
Docs builds it from `.readthedocs.yaml` (HTML and PDF per version); the `docs` job in
`.github/workflows/tests.yml` builds the HTML with warnings as errors.

```sh
python3 -m pip install -r manual/requirements.txt
python3 scripts/build_manual_refs.py                         # regenerate manual/generated/
python3 -m sphinx -W -b html manual manual/_build/html       # HTML
python3 -m sphinx -b latex manual manual/_build/latex && make -C manual/_build/latex   # PDF (needs XeLaTeX)
```

- Chapters (`*.md` here) are written by hand from the app's own strings (menus, chips, tooltips,
  Settings) and the README. Name controls exactly as the app labels them.
- `reference/` pages and parts of `install.md`, `privacy-and-accessibility.md` and `credits.md`
  include sections of `README.md` whole, so there is one copy of each. Their links to repository
  files point at GitHub (the `RepoLinks` transform in `conf.py`).
- `generated/history.md` is written by `scripts/build_manual_refs.py` from `CHANGELOG.md`; never edit
  it by hand. `scripts/check.sh` fails while it is out of date.
- Figures come from `docs/`.
- A changelog bullet's `[docs: ...]` pointer (RELEASING.md) names the manual page it changed, for
  example `[docs: manual/quick-look.md]`.
