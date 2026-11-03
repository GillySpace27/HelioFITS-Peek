"""Sphinx configuration for the HelioFITS Peek user manual (DOCS-3).

Build:  python3 -m sphinx -W -b html manual manual/_build/html
PDF:    python3 -m sphinx -b latex manual manual/_build/latex && make -C manual/_build/latex
Pages under generated/ come from scripts/build_manual_refs.py; never edit them by hand.
"""
import os
import re

_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
with open(os.path.join(_root, "Config", "Version.xcconfig"), encoding="utf-8") as _f:
    release = version = re.search(r"^MARKETING_VERSION\s*=\s*(\S+)", _f.read(), re.M).group(1)

project = "HelioFITS Peek"
author = "Gilly, NWRA"
copyright = "the HelioFITS Peek authors; BSD 2-Clause"
extensions = ["myst_parser", "sphinx_copybutton"]
myst_enable_extensions = ["colon_fence", "deflist", "substitution"]
myst_substitutions = {"release": release}
myst_heading_anchors = 3
source_suffix = {".md": "markdown"}
root_doc = "index"
exclude_patterns = ["_build", "README.md"]
html_theme = "furo"
html_title = f"HelioFITS Peek {release}"
html_logo = "../docs/social/peek_icon.png"
html_favicon = "../docs/social/peek_icon.png"
html_static_path = ["_static"]
html_css_files = ["manual.css"]
# The same look as the HelioFITS Studio manual: Furo, solar orange accents, light or dark as the reader likes.
html_theme_options = {
    "sidebar_hide_name": False,
    "navigation_with_keys": True,
    "source_repository": "https://github.com/GillySpace27/HelioFITS-Peek/",
    "source_branch": "main",
    "source_directory": "manual/",
    "light_css_variables": {
        "color-brand-primary": "#c2410c",
        "color-brand-content": "#b45309",
        "color-admonition-title--important": "#c2410c",
        "font-stack": "Inter, system-ui, -apple-system, Segoe UI, Roboto, sans-serif",
    },
    "dark_css_variables": {
        "color-brand-primary": "#fb923c",
        "color-brand-content": "#fbbf24",
        "color-background-primary": "#14161a",
        "color-background-secondary": "#1b1e24",
    },
}
copybutton_prompt_text = r"\$ "
copybutton_prompt_is_regexp = True
latex_engine = "xelatex"
latex_documents = [("index", "HelioFITS-Peek-Manual.tex", "HelioFITS Peek User Manual", author, "manual")]
# The bold serif face has no Command or Option key glyph, so those two always print in the regular face.
latex_elements = {"papersize": "letterpaper", "pointsize": "11pt", "extraclassoptions": "openany",
                  "preamble": "\\usepackage{newunicodechar}\\newunicodechar{\u2318}{{\\normalfont\u2318}}"
                              "\\newunicodechar{\u2325}{{\\normalfont\u2325}}"}

# Pages included from elsewhere in the repository (README.md) link to repository files by
# relative path, which mean nothing inside the manual. A link that resolves to no manual page is
# pointed at that file on GitHub instead, resolved against the file the link was written in.
from docutils import nodes  # noqa: E402
from sphinx import addnodes  # noqa: E402
from sphinx.transforms.post_transforms import SphinxPostTransform  # noqa: E402

_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_REPO_URL = "https://github.com/GillySpace27/HelioFITS-Peek/blob/main/"


class RepoLinks(SphinxPostTransform):
    """Runs before MyST resolves links (priority 9): a link to a repository file, not a manual page."""

    default_priority = 8

    def run(self, **kwargs):
        for node in list(self.document.findall(addnodes.pending_xref)):
            if node.get("reftype") != "myst":
                continue
            target = node.get("reftarget", "").split("#")[0]
            source = (node.source or "").split(":")[0]
            if not target or not source:
                continue
            path = os.path.normpath(os.path.join(os.path.dirname(source), target))
            manual = os.path.join(_ROOT, "manual") + os.sep
            if not path.startswith(_ROOT + os.sep) or path.startswith(manual) or not os.path.exists(path):
                continue
            ref = nodes.reference("", "", internal=False,
                                  refuri=_REPO_URL + os.path.relpath(path, _ROOT).replace(os.sep, "/"))
            ref += node.children
            node.replace_self(ref)


def setup(app):
    app.add_post_transform(RepoLinks)
