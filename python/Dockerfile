FROM python:3.10.10-slim

WORKDIR /python
COPY python/requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY python/ ./
