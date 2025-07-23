from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import subprocess

app = FastAPI()

SCRIPT_PATH = "./create_job_branch.sh"

class JobConfig(BaseModel):
    username: str = "stephen"
    base_branch: str = "dev"
    selection_prompt: str | None = None
    rerank_prompt: str | None = None
    selection_prompt_branch: str | None = None
    rerank_prompt_branch: str | None = None

@app.post("/create-job-branch")
def create_job_branch(config: JobConfig):
    cmd = [SCRIPT_PATH, "--username", config.username, "--base_branch", config.base_branch]

    if config.selection_prompt:
        cmd += ["--selection_prompt", config.selection_prompt]
    if config.rerank_prompt:
        cmd += ["--rerank_prompt", config.rerank_prompt]
    if config.selection_prompt_branch:
        cmd += ["--selection_prompt_branch", config.selection_prompt_branch]
    if config.rerank_prompt_branch:
        cmd += ["--rerank_prompt_branch", config.rerank_prompt_branch]

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return {"status": "success", "stdout": result.stdout, "stderr": result.stderr}
    except subprocess.CalledProcessError as e:
        raise HTTPException(status_code=500, detail={
            "error": "Script execution failed",
            "stdout": e.stdout,
            "stderr": e.stderr
        })
