import os
import re
import subprocess
from pathlib import Path

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field


DATA_ROOT = Path(os.environ.get("DATA_ROOT", "/data/cca")).resolve()

PRESETS = {
    "mp3-128k": ["-vn", "-codec:a", "libmp3lame", "-b:a", "128k"],
    "mp3-128k-16k-mono": [
        "-vn",
        "-codec:a",
        "libmp3lame",
        "-b:a",
        "128k",
        "-ar",
        "16000",
        "-ac",
        "1",
    ],
    "segment-mp3-10min-copy": [
        "-f",
        "segment",
        "-segment_time",
        "600",
        "-c",
        "copy",
    ],
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
    files: list[str] = Field(default_factory=list)


app = FastAPI(title="AI Lab FFmpeg Worker")


def resolve_data_path(input_path: str) -> Path:
    path = Path(input_path)
    candidate = path.resolve() if path.is_absolute() else (DATA_ROOT / path).resolve()
    if DATA_ROOT != candidate and DATA_ROOT not in candidate.parents:
        raise HTTPException(status_code=400, detail="Path must stay inside DATA_ROOT")
    return candidate


def list_created_files(output_path: Path) -> list[str]:
    if "%" in output_path.name:
        glob_name = re.sub(r"%\d*d", "*", output_path.name)
        return [str(path) for path in sorted(output_path.parent.glob(glob_name)) if path.is_file()]

    return [str(output_path)] if output_path.is_file() else []


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

    return ConvertResponse(
        status="ok",
        output=request.output,
        files=list_created_files(output_path),
    )
