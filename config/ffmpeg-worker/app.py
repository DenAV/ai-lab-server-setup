import os
import subprocess
from pathlib import Path

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field


DATA_ROOT = Path(os.environ.get("DATA_ROOT", "/data/cca")).resolve()

PRESETS = {
    "mp3-128k": ["-vn", "-codec:a", "libmp3lame", "-b:a", "128k"],
    "wav-16k-mono": ["-ar", "16000", "-ac", "1", "-codec:a", "pcm_s16le"],
    "extract-audio": ["-vn", "-codec:a", "copy"],
}


class ConvertRequest(BaseModel):
    input: str = Field(..., min_length=1, examples=["incoming/source.wav"])
    output: str = Field(..., min_length=1, examples=["processed/source.mp3"])
    preset: str = Field(..., examples=["mp3-128k"])


class ConvertResponse(BaseModel):
    status: str
    output: str


app = FastAPI(title="AI Lab FFmpeg Worker")


def resolve_data_path(relative_path: str) -> Path:
    candidate = (DATA_ROOT / relative_path).resolve()
    if DATA_ROOT != candidate and DATA_ROOT not in candidate.parents:
        raise HTTPException(status_code=400, detail="Path must stay inside DATA_ROOT")
    return candidate


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/presets")
def presets() -> dict[str, list[str]]:
    return PRESETS


@app.post("/convert", response_model=ConvertResponse)
def convert(request: ConvertRequest) -> ConvertResponse:
    if request.preset not in PRESETS:
        raise HTTPException(status_code=400, detail="Unsupported preset")

    input_path = resolve_data_path(request.input)
    output_path = resolve_data_path(request.output)

    if not input_path.is_file():
        raise HTTPException(status_code=404, detail="Input file not found")

    output_path.parent.mkdir(parents=True, exist_ok=True)

    command = [
        "ffmpeg",
        "-hide_banner",
        "-y",
        "-i",
        str(input_path),
        *PRESETS[request.preset],
        str(output_path),
    ]

    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=900)
    except subprocess.TimeoutExpired as exc:
        raise HTTPException(status_code=408, detail="Conversion timed out") from exc

    if result.returncode != 0:
        raise HTTPException(status_code=422, detail=result.stderr[-2000:])

    return ConvertResponse(status="ok", output=request.output)
