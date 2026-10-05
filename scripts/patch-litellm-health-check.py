"""Fix the Responses connection probe in the pinned LiteLLM image."""

from importlib.util import find_spec
from pathlib import Path


package = find_spec("litellm")
if package is None or package.submodule_search_locations is None:
    raise SystemExit("LiteLLM package not found")

helper = Path(next(iter(package.submodule_search_locations))) / "litellm_core_utils/health_check_helpers.py"
source = helper.read_text()
old = 'input=prompt or "test",\n            ),\n            "ocr":'
new = 'input=[{"role": "user", "content": prompt or "test"}],\n            ),\n            "ocr":'
if source.count(old) != 1:
    raise SystemExit("LiteLLM Responses probe changed; review patch before upgrading")

helper.write_text(source.replace(old, new))
