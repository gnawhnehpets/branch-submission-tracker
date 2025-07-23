# branch-job-tracker

A lightweight Git-based job tracking tool that uses branches to manage and version-control job runs and their associated configuration.

Each job is tracked via a dedicated Git branch, containing the specific files (e.g., prompts) and a `config.yml` describing the job’s inputs. A shell script (`create_job_branch.sh`) and FastAPI interface (`api_service.py`) are included to automate branch creation and job metadata management.

---

## Features

- Create a dedicated Git branch for each job run
- Pin specific versions of input prompt files (`selection.txt`, `rerank.txt`)
- Auto-generate `config.yml` capturing file commit hashes
- Run as a local script or via a containerized FastAPI API
- Enforces clean working directory before job creation

---

## Repository Structure
```
branch-job-tracker/
├── create_job_branch.sh    # Main job-branch creation script
├── api.py                  # FastAPI endpoint to trigger the script
├── prompt/                 # Directory containing prompt files   
│ ├── selection.txt         
│ └── rerank.txt
├── Dockerfile              # Containerizes the FastAPI service
└── README.md
```

---

## Running local test

To run the bash script locally, ensure the following: 
- base branch exists (e.g., `dev-test`) with relevant files with commit hash
- necessary permissions on bash script
- clean working directory (e.g., no uncommitted changes)

Then execute:

```bash
chmod +x create_job_branch.sh
./configure_task_branch.sh --username test --base_branch dev
```


## Running docker container
#### Build the image
```
docker build -t branch-job-tracker . --no-cache
```

#### Run the container (bind the host repo if you need git context)
```
docker run -it --rm -v $(pwd):/app -p 8000:8000 branch-job-tracker
```