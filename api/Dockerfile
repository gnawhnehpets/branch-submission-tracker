# Use an official Python runtime as a parent image
FROM python:3.9-slim

# Install git
RUN apt-get update && apt-get install -y git

# Set the working directory in the container
WORKDIR /app

# Clone the repository
RUN git clone git@github.com:rti-international/DataFlexx.git .

# Install dependencies
RUN pip install --no-cache-dir -r /app/configure_task_branch/requirements.txt

# Make the script executable
RUN chmod +x /app/configure_task_branch/create_job_branch.sh

# Command to run the application
CMD ["uvicorn", "configure_task_branch.main:app", "--host", "0.0.0.0", "--port", "8000"]
