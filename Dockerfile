FROM python:3.13-alpine

COPY requirements.txt .
RUN pip3 install -r requirements.txt

WORKDIR /opt/app
COPY server.py server.py

ENTRYPOINT ["python3", "-m", "uvicorn", "server:app", "--host", "0.0.0.0"]
CMD ["--port", "8000", "--workers", "2"]
