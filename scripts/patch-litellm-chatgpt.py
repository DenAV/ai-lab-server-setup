"""Fix ChatGPT Responses integration in the pinned LiteLLM image."""

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

bridge = (
    Path(next(iter(package.submodule_search_locations)))
    / "completion_extras/litellm_responses_transformation/handler.py"
)
source = bridge.read_text()
old_sync = """    def _collect_response_from_stream(self, stream_iter: Any) -> \"ResponsesAPIResponse\":
        for _ in stream_iter:
            pass

        completed: Final[object] = getattr(stream_iter, \"completed_response\", None)
"""
new_sync = """    def _collect_response_from_stream(self, stream_iter: Any) -> \"ResponsesAPIResponse\":
        recovered_output: dict[int, dict] = {}
        for event in stream_iter:
            event_type = getattr(getattr(event, \"type\", None), \"value\", getattr(event, \"type\", None))
            item = getattr(event, \"item\", None)
            if event_type == \"response.output_item.done\" and item is not None:
                if hasattr(item, \"model_dump\"):
                    item = item.model_dump()
                if isinstance(item, dict):
                    recovered_output[int(getattr(event, \"output_index\", 0))] = item

        completed: Final[object] = getattr(stream_iter, \"completed_response\", None)
"""
old_async = """    async def _collect_response_from_stream_async(self, stream_iter: Any) -> \"ResponsesAPIResponse\":
        async for _ in stream_iter:
            pass

        completed: Final[object] = getattr(stream_iter, \"completed_response\", None)
"""
new_async = """    async def _collect_response_from_stream_async(self, stream_iter: Any) -> \"ResponsesAPIResponse\":
        recovered_output: dict[int, dict] = {}
        async for event in stream_iter:
            event_type = getattr(getattr(event, \"type\", None), \"value\", getattr(event, \"type\", None))
            item = getattr(event, \"item\", None)
            if event_type == \"response.output_item.done\" and item is not None:
                if hasattr(item, \"model_dump\"):
                    item = item.model_dump()
                if isinstance(item, dict):
                    recovered_output[int(getattr(event, \"output_index\", 0))] = item

        completed: Final[object] = getattr(stream_iter, \"completed_response\", None)
"""
old_return = """        if not isinstance(response, ResponsesAPIResponse):
            raise ValueError(\"Stream completed response is invalid\")
        return response
"""
new_return = """        if not isinstance(response, ResponsesAPIResponse):
            raise ValueError(\"Stream completed response is invalid\")
        if not response.output and recovered_output:
            response.output = [recovered_output[index] for index in sorted(recovered_output)]
        return response
"""
if source.count(old_sync) != 1 or source.count(old_async) != 1 or source.count(old_return) != 2:
    raise SystemExit("LiteLLM Responses bridge changed; review patch before upgrading")

source = source.replace(old_sync, new_sync).replace(old_async, new_async)
bridge.write_text(source.replace(old_return, new_return))
