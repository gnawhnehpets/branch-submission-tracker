FROM python:3.12-slim

RUN apt-get update && apt-get install -y git

WORKDIR /app

RUN git clone git@github.com:gnawhnehpets/branch-submission-tracker.git .

RUN pip install --no-cache-dir -r /app/requirements.txt

RUN chmod +x /app/create_job_branch.sh

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
